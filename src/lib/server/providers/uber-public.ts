import { fetchJson } from "@/lib/server/http";
import type { ProviderAdapter } from "@/lib/server/providers/base";
import type { ProviderSnapshot, RouteObservation } from "@/lib/types";

const UBER_ROUTE_URL = "https://m.uber.com/go/custom-api/navigation/route";

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
    return 0;
  }

  const sorted = [...values].sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) {
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  return sorted[middle];
}

function offsetCoordinate(
  latitude: number,
  longitude: number,
  bearingDegrees: number,
  distanceKm: number,
) {
  const radius = 6371;
  const bearing = (bearingDegrees * Math.PI) / 180;
  const lat1 = (latitude * Math.PI) / 180;
  const lon1 = (longitude * Math.PI) / 180;
  const angularDistance = distanceKm / radius;

  const lat2 = Math.asin(
    Math.sin(lat1) * Math.cos(angularDistance) +
      Math.cos(lat1) * Math.sin(angularDistance) * Math.cos(bearing),
  );
  const lon2 =
    lon1 +
    Math.atan2(
      Math.sin(bearing) * Math.sin(angularDistance) * Math.cos(lat1),
      Math.cos(angularDistance) - Math.sin(lat1) * Math.sin(lat2),
    );

  return {
    latitude: (lat2 * 180) / Math.PI,
    longitude: (lon2 * 180) / Math.PI,
  };
}

type UberRouteResponse = Array<{
  distance: number;
  eta: number;
}>;

function buildRouteObservation(
  routeResponse: UberRouteResponse,
  cityLatitude: number,
  cityLongitude: number,
  radiusKm: number,
): RouteObservation | null {
  const directDistanceMeters = radiusKm * 1000;
  const valid = routeResponse.filter((route) => {
    if (!Number.isFinite(route.distance) || !Number.isFinite(route.eta)) {
      return false;
    }

    if (route.distance <= 500 || route.eta <= 60) {
      return false;
    }

    const routeToDirectRatio = route.distance / directDistanceMeters;
    return routeToDirectRatio >= 0.75 && routeToDirectRatio <= 3.5;
  });

  if (valid.length < 2) {
    return null;
  }

  const secondsPerKm = valid.map((route) => route.eta / (route.distance / 1000));

  return {
    routeCount: routeResponse.length,
    validRouteCount: valid.length,
    averageEtaSeconds: average(valid.map((route) => route.eta)),
    averageDistanceMeters: average(valid.map((route) => route.distance)),
    medianSecondsPerKm: median(secondsPerKm),
    baselineSecondsPerKm: null,
    directness: "direct",
    note: `Observed from ${valid.length} canonical Uber web route probes around ${cityLatitude.toFixed(2)}, ${cityLongitude.toFixed(2)}.`,
  };
}

export class UberPublicAdapter implements ProviderAdapter {
  readonly provider = "uber" as const;

  async observe({
    city,
    observedAt,
  }: Parameters<ProviderAdapter["observe"]>[0]): Promise<ProviderSnapshot> {
    const radiusKm = clamp(
      city.population && city.population > 1500000 ? 2.8 : city.population && city.population > 500000 ? 2.2 : 1.8,
      1.6,
      3,
    );
    const bearings = [0, 45, 90, 135, 180, 225, 270, 315];
    const routes = bearings.map((bearing) => ({
      origin: {
        latitude: city.latitude,
        longitude: city.longitude,
      },
      destinations: [offsetCoordinate(city.latitude, city.longitude, bearing, radiusKm)],
    }));

    let routeObservation: RouteObservation | null = null;

    try {
      const routeResponse = await fetchJson<UberRouteResponse>(UBER_ROUTE_URL, {
        method: "POST",
        body: JSON.stringify({ routes }),
        name: "Uber public route probe",
        headers: {
          accept: "application/json",
          "content-type": "application/json",
          referer: "https://m.uber.com/go/",
          "x-csrf-token": "x",
          "x-uber-rv-session-type": "desktop_session",
          "x-uber-rv-initial-load-city-id": "0",
        },
      });

      routeObservation = buildRouteObservation(
        routeResponse,
        city.latitude,
        city.longitude,
        radiusKm,
      );
    } catch {
      routeObservation = null;
    }

    if (!routeObservation) {
      return {
        provider: this.provider,
        supportLevel: "limited",
        availabilityState: "limited",
        tone: "neutral",
        statusLabel: "Route only",
        observedAt,
        sourceBlend: "direct",
        freshnessHours: 0,
        note: "The public Uber web flow returned urban route timing, but no anonymous fare was available for this city.",
        signals: {},
      };
    }

    return {
      provider: this.provider,
      supportLevel: "limited",
      availabilityState: "limited",
      tone: "neutral",
      statusLabel: "Route only",
      observedAt,
      sourceBlend: "direct",
      freshnessHours: 0,
      note: "Public Uber web probes are contributing direct route friction, but this build does not expose a verified anonymous Uber price for classification.",
      signals: {
        routeObservation,
        etaSeconds: Math.round(routeObservation.averageEtaSeconds),
        distanceMeters: Math.round(routeObservation.averageDistanceMeters),
      },
    };
  }
}
