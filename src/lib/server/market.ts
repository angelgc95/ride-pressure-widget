import { addHours, differenceInHours, parseISO } from "date-fns";

import { reverseGeocodeCity } from "@/lib/server/cities";
import { logger } from "@/lib/server/logger";
import { providerAdapters } from "@/lib/server/providers";
import { fetchWeather, type WeatherSnapshot } from "@/lib/server/sources/open-meteo";
import {
  getLatestSnapshot,
  listRecentProviderPrices,
  listRecentRouteMedians,
  saveSnapshot,
} from "@/lib/server/snapshots";
import type {
  ChartPoint,
  CitySelection,
  DashboardResponse,
  ObservedSnapshot,
  PressureTone,
  ProviderSnapshot,
  RouteObservation,
  SourceBlend,
} from "@/lib/types";

const SNAPSHOT_TTL_HOURS = 6;

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

function average(values: number[]) {
  if (!values.length) {
    return 0;
  }

  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function median(values: number[]) {
  if (!values.length) {
    return null;
  }

  const sorted = [...values].sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) {
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  return sorted[middle];
}

function toneFromScore(score: number): Exclude<PressureTone, "neutral"> {
  if (score <= 34) {
    return "favorable";
  }

  if (score <= 66) {
    return "normal";
  }

  return "unfavorable";
}

function labelFromTone(tone: Exclude<PressureTone, "neutral">) {
  switch (tone) {
    case "favorable":
      return "Good idea now";
    case "normal":
      return "Normal conditions";
    case "unfavorable":
      return "Rough right now";
  }
}

function summaryFromTone(
  tone: Exclude<PressureTone, "neutral">,
  routeObservation: RouteObservation | null,
) {
  if (tone === "favorable") {
    return routeObservation
      ? "Observed route friction is below usual city stress, and weather load is relatively light."
      : "Weather conditions are light enough that rides look comparatively favorable despite limited provider pricing access.";
  }

  if (tone === "normal") {
    return routeObservation
      ? "Traffic and weather are close to their normal city baseline."
      : "Current signals are balanced, but the model is leaning on weather plus inferred demand because provider pricing access is limited.";
  }

  return routeObservation
    ? "Route timing and weather both point to elevated market pressure."
    : "Weather and demand proxies point to elevated pressure, but direct provider pricing is still limited.";
}

function currency(delta: number | null) {
  if (delta === null) {
    return "No real price delta yet";
  }

  const percent = Math.round(delta * 100);
  return `${percent > 0 ? "+" : ""}${percent}% vs recent baseline`;
}

function getZonedParts(date: Date, timeZone: string) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hour: "2-digit",
    weekday: "short",
    month: "short",
    day: "2-digit",
    hour12: false,
  }).formatToParts(date);

  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    hour: Number(values.hour),
    weekday: values.weekday,
    month: values.month,
    day: values.day,
  };
}

function demandPressure(date: Date, timeZone: string) {
  const { hour, weekday } = getZonedParts(date, timeZone);
  const weekend = weekday === "Sat" || weekday === "Sun";

  if (!weekend && hour >= 7 && hour <= 9) {
    return 74;
  }

  if (!weekend && hour >= 17 && hour <= 20) {
    return 78;
  }

  if ((weekday === "Fri" || weekday === "Sat") && (hour >= 22 || hour <= 2)) {
    return 84;
  }

  if (hour >= 1 && hour <= 5) {
    return 28;
  }

  if (weekend && hour >= 11 && hour <= 17) {
    return 48;
  }

  return 40;
}

function weatherPressureFromCurrent(weather: WeatherSnapshot["current"]) {
  const precipitationScore = clamp(weather.precipitation * 18, 0, 55);
  const windScore = clamp((weather.wind_speed_10m - 12) * 2.4, 0, 24);
  const heatScore = clamp(Math.abs(weather.apparent_temperature - 19) * 1.35, 0, 21);

  return clamp(precipitationScore + windScore + heatScore, 0, 100);
}

function weatherPressureFromHour(hour: WeatherSnapshot["hourly"][number]) {
  const precipitationScore =
    clamp(hour.precipitationProbability * 0.38, 0, 38) +
    clamp(hour.precipitation * 14, 0, 34);
  const windScore = clamp((hour.windSpeed - 12) * 2.1, 0, 18);
  const cloudScore = clamp((hour.cloudCover - 60) * 0.18, 0, 10);
  const comfortScore = clamp(Math.abs(hour.apparentTemperature - 19) * 1.2, 0, 16);

  return clamp(precipitationScore + windScore + cloudScore + comfortScore, 0, 100);
}

function weatherPressureFromDay(day: WeatherSnapshot["daily"][number]) {
  const rainScore = clamp(day.precipitationSum * 5.4, 0, 45);
  const durationScore = clamp(day.precipitationHours * 4.2, 0, 26);
  const windScore = clamp((day.windSpeedMax - 16) * 1.9, 0, 16);
  const comfortScore = clamp(
    Math.max(Math.abs(day.temperatureMax - 24), Math.abs(day.temperatureMin - 12)) * 1.7,
    0,
    13,
  );

  return clamp(rainScore + durationScore + windScore + comfortScore, 0, 100);
}

function trafficPressureScore(routeObservation: RouteObservation | null) {
  if (!routeObservation) {
    return null;
  }

  const absoluteScore = clamp(
    ((routeObservation.medianSecondsPerKm - 85) / (330 - 85)) * 100,
    0,
    100,
  );

  if (!routeObservation.baselineSecondsPerKm) {
    return absoluteScore;
  }

  const deltaRatio =
    routeObservation.medianSecondsPerKm / routeObservation.baselineSecondsPerKm - 1;
  const relativeScore = clamp(50 + deltaRatio * 150, 0, 100);
  return clamp(absoluteScore * 0.55 + relativeScore * 0.45, 0, 100);
}

function combineScore({
  trafficScore,
  weatherScore,
  demandScore,
}: {
  trafficScore: number | null;
  weatherScore: number;
  demandScore: number;
}) {
  if (trafficScore === null) {
    return clamp(weatherScore * 0.58 + demandScore * 0.42, 0, 100);
  }

  return clamp(trafficScore * 0.45 + weatherScore * 0.3 + demandScore * 0.25, 0, 100);
}

function scoreComponents({
  trafficScore,
  weatherScore,
  demandScore,
}: {
  trafficScore: number | null;
  weatherScore: number;
  demandScore: number;
}) {
  if (trafficScore === null) {
    return {
      trafficComponent: 0,
      weatherComponent: Number((weatherScore * 0.58).toFixed(1)),
      demandComponent: Number((demandScore * 0.42).toFixed(1)),
      neutralComponent: 0,
    };
  }

  return {
    trafficComponent: Number((trafficScore * 0.45).toFixed(1)),
    weatherComponent: Number((weatherScore * 0.3).toFixed(1)),
    demandComponent: Number((demandScore * 0.25).toFixed(1)),
    neutralComponent: 0,
  };
}

function confidenceForBlend(blend: SourceBlend, trafficScore: number | null) {
  if (blend === "direct") {
    return 0.88;
  }

  if (blend === "mixed") {
    return trafficScore === null ? 0.58 : 0.78;
  }

  return trafficScore === null ? 0.44 : 0.64;
}

function annotateProviders(cityId: string, snapshots: ProviderSnapshot[]) {
  return snapshots.map<ProviderSnapshot>((snapshot) => {
    const price = snapshot.signals.priceAmount;
    if (typeof price !== "number") {
      return snapshot;
    }

    const baseline = median(listRecentProviderPrices(cityId, snapshot.provider));
    if (!baseline || baseline <= 0) {
      const nextSnapshot: ProviderSnapshot = {
        ...snapshot,
        supportLevel: "limited",
        availabilityState: snapshot.availabilityState,
        tone: "neutral",
        statusLabel: "Observed",
        note: `${snapshot.note} First real price captured; waiting for a baseline window.`,
        signals: {
          ...snapshot.signals,
          baselinePrice: null,
          relativeDelta: null,
        },
      };

      return nextSnapshot;
    }

    const delta = price / baseline - 1;
    let tone: ProviderSnapshot["tone"] = "normal";
    let statusLabel = "Normal";

    if (delta <= -0.08) {
      tone = "favorable";
      statusLabel = "Cheaper";
    } else if (delta >= 0.12) {
      tone = "unfavorable";
      statusLabel = "Expensive";
    }

    const nextSnapshot: ProviderSnapshot = {
      ...snapshot,
      tone,
      statusLabel,
      supportLevel: "supported",
      availabilityState: "available",
      note: `${snapshot.note} ${currency(delta)}.`,
      signals: {
        ...snapshot.signals,
        baselinePrice: Number(baseline.toFixed(2)),
        relativeDelta: Number(delta.toFixed(4)),
      },
    };

    return nextSnapshot;
  });
}

function buildObservedSnapshot(
  city: CitySelection,
  weather: WeatherSnapshot,
  providerSnapshots: ProviderSnapshot[],
  routeObservation: RouteObservation | null,
  observedAt: string,
) {
  const trafficHistory = median(listRecentRouteMedians(city.id));
  const hydratedRouteObservation = routeObservation
    ? {
        ...routeObservation,
        baselineSecondsPerKm: trafficHistory,
      }
    : null;
  const trafficScore = trafficPressureScore(hydratedRouteObservation);
  const weatherScore = weatherPressureFromCurrent(weather.current);
  const demandScore = demandPressure(new Date(observedAt), city.timezone);
  const score = combineScore({ trafficScore, weatherScore, demandScore });
  const tone = toneFromScore(score);

  return {
    city,
    observedAt,
    score: Number(score.toFixed(1)),
    tone,
    label: labelFromTone(tone),
    summary: summaryFromTone(tone, hydratedRouteObservation),
    sourceBlend: routeObservation ? "mixed" : "mixed",
    confidence: confidenceForBlend("mixed", trafficScore),
    routeObservation: hydratedRouteObservation,
    breakdown: {
      trafficScore,
      weatherScore: Number(weatherScore.toFixed(1)),
      demandScore,
      trafficWeight: trafficScore === null ? 0 : 0.45,
      weatherWeight: trafficScore === null ? 0.58 : 0.3,
      demandWeight: trafficScore === null ? 0.42 : 0.25,
    },
    providerSnapshots: annotateProviders(city.id, providerSnapshots),
  } satisfies ObservedSnapshot;
}

async function refreshObservedSnapshot(city: CitySelection, weather: WeatherSnapshot) {
  const observedAt = new Date().toISOString();
  const providerSnapshots = await Promise.all(
    providerAdapters.map((adapter) => adapter.observe({ city, observedAt })),
  );
  const uberRouteObservation =
    providerSnapshots.find((snapshot) => snapshot.provider === "uber")?.signals
      .routeObservation ?? null;

  const snapshot = buildObservedSnapshot(
    city,
    weather,
    providerSnapshots,
    uberRouteObservation,
    observedAt,
  );
  saveSnapshot(snapshot);
  return snapshot;
}

function sourceBlendForForecast(trafficScore: number | null): SourceBlend {
  return trafficScore === null ? "inferred" : "inferred";
}

function buildHourlyChart(
  city: CitySelection,
  weather: WeatherSnapshot,
  routeObservation: RouteObservation | null,
) {
  const trafficScore = trafficPressureScore(routeObservation);
  const now = new Date();
  const points = weather.hourly
    .filter((hour) => parseISO(hour.time) >= now)
    .slice(0, 24)
    .map((hour, index) => {
      const timestamp = parseISO(hour.time);
      const weatherScore = weatherPressureFromHour(hour);
      const demandScore = demandPressure(timestamp, city.timezone);
      const score = combineScore({ trafficScore, weatherScore, demandScore });
      const tone = toneFromScore(score);
      const blend = sourceBlendForForecast(trafficScore);
      const components = scoreComponents({
        trafficScore,
        weatherScore,
        demandScore,
      });

      return {
        key: `hour-${index}`,
        label: new Intl.DateTimeFormat("en-US", {
          timeZone: city.timezone,
          hour: "numeric",
        }).format(timestamp),
        timestamp: hour.time,
        score: Number(score.toFixed(1)),
        tone,
        sourceBlend: blend,
        confidence: confidenceForBlend(blend, trafficScore),
        explanation:
          trafficScore === null
            ? "Forecast built from weather plus inferred local demand because direct route probes are unavailable."
            : "Forecast combines live weather forecast with the latest observed Uber route basket and an inferred local demand curve.",
        trafficScore,
        weatherScore: Number(weatherScore.toFixed(1)),
        demandScore,
        ...components,
      } satisfies ChartPoint;
    });

  return {
    title: "Hourly chart",
    subtitle: "Next 24 hours. Forecast points are inferred from real weather plus the latest observed route friction.",
    points,
  };
}

function buildDailyChart(
  city: CitySelection,
  weather: WeatherSnapshot,
  routeObservation: RouteObservation | null,
) {
  const trafficScore = trafficPressureScore(routeObservation);
  const points = weather.daily.slice(0, 7).map((day, index) => {
    const dayDate = parseISO(day.time);
    const weatherScore = weatherPressureFromDay(day);
    const demandScore = average(
      [8, 12, 18, 23].map((hour) =>
        demandPressure(addHours(dayDate, hour), city.timezone),
      ),
    );
    const score = combineScore({ trafficScore, weatherScore, demandScore });
    const tone = toneFromScore(score);
    const blend = sourceBlendForForecast(trafficScore);
    const components = scoreComponents({
      trafficScore,
      weatherScore,
      demandScore,
    });

    return {
      key: `day-${index}`,
      label: new Intl.DateTimeFormat("en-US", {
        timeZone: city.timezone,
        weekday: "short",
      }).format(dayDate),
      timestamp: day.time,
      score: Number(score.toFixed(1)),
      tone,
      sourceBlend: blend,
      confidence: confidenceForBlend(blend, trafficScore) - 0.06,
      explanation:
        "Daily outlook blends forecast weather load with the latest observed route baseline and a weekday demand curve.",
      trafficScore,
      weatherScore: Number(weatherScore.toFixed(1)),
      demandScore: Number(demandScore.toFixed(1)),
      ...components,
    } satisfies ChartPoint;
  });

  return {
    title: "Daily chart",
    subtitle: "Next 7 days. This becomes more trustworthy as real snapshots accumulate for the city.",
    points,
  };
}

function hydrateProviderFreshness(snapshot: ProviderSnapshot, observedAt: string) {
  const freshnessHours = differenceInHours(new Date(), parseISO(observedAt));
  if (snapshot.availabilityState === "unsupported") {
    return {
      ...snapshot,
      freshnessHours: null,
    };
  }

  if (freshnessHours > SNAPSHOT_TTL_HOURS) {
    return {
      ...snapshot,
      availabilityState: "stale" as const,
      freshnessHours,
      note: `${snapshot.note} Last successful observation is ${freshnessHours}h old.`,
    };
  }

  return {
    ...snapshot,
    freshnessHours,
  };
}

function mergeCityMetadata(snapshot: ObservedSnapshot, city: CitySelection): ObservedSnapshot {
  return {
    ...snapshot,
    city,
  };
}

export async function getDashboard(city: CitySelection): Promise<DashboardResponse> {
  const weather = await fetchWeather(city);
  let latestSnapshot = getLatestSnapshot(city.id);
  let staleReason: string | null = null;

  if (
    !latestSnapshot ||
    differenceInHours(new Date(), parseISO(latestSnapshot.observedAt)) >= SNAPSHOT_TTL_HOURS
  ) {
    try {
      latestSnapshot = await refreshObservedSnapshot(city, weather);
    } catch (error) {
      logger.error("Failed to refresh observed snapshot", {
        cityId: city.id,
        error: error instanceof Error ? error.message : String(error),
      });

      if (!latestSnapshot) {
        throw error;
      }

      staleReason = "Using the last stored snapshot because the upstream refresh failed.";
    }
  }

  const current = mergeCityMetadata(latestSnapshot, city);
  const staleHours = differenceInHours(new Date(), parseISO(current.observedAt));
  const stale = staleHours >= SNAPSHOT_TTL_HOURS;
  if (!staleReason && stale) {
    staleReason = `Observed market snapshot is ${staleHours}h old.`;
  }

  return {
    city,
    lastUpdatedAt: current.observedAt,
    stale,
    staleReason,
    current: {
      ...current,
      providerSnapshots: current.providerSnapshots.map((snapshot) =>
        hydrateProviderFreshness(snapshot, current.observedAt),
      ),
    },
    hourlyChart: buildHourlyChart(city, weather, current.routeObservation),
    dailyChart: buildDailyChart(city, weather, current.routeObservation),
    providerSnapshots: current.providerSnapshots.map((snapshot) =>
      hydrateProviderFreshness(snapshot, current.observedAt),
    ),
    notes: [
      "Green/orange/red provider states appear only when a real provider price is observed. Neutral cards mean access is limited or unsupported, not cheap.",
      "The city index is route-and-weather driven today: direct Uber route probes when available, plus real weather and an explicit inferred demand curve.",
    ],
  };
}

export async function reverseDetectCity(latitude: number, longitude: number) {
  return reverseGeocodeCity(latitude, longitude);
}
