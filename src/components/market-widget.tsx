"use client";

import Link from "next/link";
import { LocateFixed, LoaderCircle, MapPin, RefreshCcw, Search } from "lucide-react";
import {
  startTransition,
  useCallback,
  useDeferredValue,
  useEffect,
  useState,
} from "react";

import { PressureChart } from "@/components/pressure-chart";
import { cn } from "@/lib/utils";
import type { CitySelection, DashboardResponse } from "@/lib/types";

const storageKey = "ride-pressure:selected-city:v1";

function useLocalCity() {
  const [ready, setReady] = useState(false);
  const [storedCity, setStoredCity] = useState<CitySelection | null>(null);

  useEffect(() => {
    const raw = window.localStorage.getItem(storageKey);
    if (!raw) {
      setReady(true);
      return;
    }

    try {
      setStoredCity(JSON.parse(raw) as CitySelection);
    } catch {
      window.localStorage.removeItem(storageKey);
    } finally {
      setReady(true);
    }
  }, []);

  const persistCity = useCallback((city: CitySelection) => {
    window.localStorage.setItem(storageKey, JSON.stringify(city));
    setStoredCity(city);
  }, []);

  return { ready, storedCity, persistCity };
}

function ProviderCard({
  provider,
}: {
  provider: DashboardResponse["providerSnapshots"][number];
}) {
  const toneClasses = {
    favorable: "border-emerald-400/25 bg-emerald-400/10 text-emerald-200",
    normal: "border-amber-400/25 bg-amber-400/10 text-amber-200",
    unfavorable: "border-rose-400/25 bg-rose-400/10 text-rose-200",
    neutral: "border-white/10 bg-white/5 text-slate-200",
  } as const;

  return (
    <article className="rounded-[24px] border border-white/10 bg-slate-950/60 p-4">
      <div className="flex items-center justify-between gap-4">
        <div>
          <p className="text-sm font-semibold uppercase tracking-[0.28em] text-slate-100">
            {provider.provider}
          </p>
          <p className="mt-1 text-xs text-slate-400">{provider.supportLevel}</p>
        </div>
        <span
          className={cn(
            "rounded-full border px-3 py-1 text-[11px] uppercase tracking-[0.24em]",
            toneClasses[provider.tone],
          )}
        >
          {provider.statusLabel}
        </span>
      </div>
      <p className="mt-4 text-sm leading-6 text-slate-300">{provider.note}</p>
      <div className="mt-4 flex items-center justify-between text-xs text-slate-500">
        <span>{provider.observedAt ? "Observed" : "No live reading"}</span>
        <span>
          {provider.freshnessHours === null ? "n/a" : `${provider.freshnessHours}h old`}
        </span>
      </div>
    </article>
  );
}

function ProviderChip({
  provider,
}: {
  provider: DashboardResponse["providerSnapshots"][number];
}) {
  const chipClasses = {
    favorable: "border-emerald-400/30 bg-emerald-400/10 text-emerald-200",
    normal: "border-amber-400/30 bg-amber-400/10 text-amber-200",
    unfavorable: "border-rose-400/30 bg-rose-400/10 text-rose-200",
    neutral: "border-white/10 bg-white/5 text-slate-200",
  } as const;

  return (
    <div
      className={cn(
        "flex items-center justify-between rounded-2xl border px-3 py-2",
        chipClasses[provider.tone],
      )}
    >
      <div>
        <p className="text-[11px] font-semibold uppercase tracking-[0.24em]">
          {provider.provider}
        </p>
        <p className="mt-1 text-[10px] uppercase tracking-[0.18em] opacity-70">
          {provider.supportLevel}
        </p>
      </div>
      <span className="text-[10px] uppercase tracking-[0.2em]">{provider.statusLabel}</span>
    </div>
  );
}

function CurrentSummary({
  data,
  variant,
}: {
  data: DashboardResponse;
  variant: "dashboard" | "widget";
}) {
  const scoreTone = {
    favorable: "text-emerald-300",
    normal: "text-amber-300",
    unfavorable: "text-rose-300",
  } as const;
  const compact = variant === "widget";

  return (
    <section
      className={cn(
        "grid gap-4 rounded-[32px] border border-white/10 bg-[radial-gradient(circle_at_top,#1b1b1f_0%,#0d1117_68%)] shadow-[0_40px_120px_rgba(15,23,42,0.6)]",
        compact ? "p-4" : "p-6 lg:grid-cols-[1.15fr_0.85fr]",
      )}
    >
      <div>
        <p className="text-xs uppercase tracking-[0.4em] text-slate-400">
          city market pressure
        </p>
        <div className={cn("flex flex-wrap items-end gap-4", compact ? "mt-4" : "mt-5")}>
          <div className="flex items-end gap-3">
            <span
              className={cn(
                compact ? "text-5xl font-semibold tracking-tight" : "text-6xl font-semibold tracking-tight sm:text-7xl",
                scoreTone[data.current.tone],
              )}
            >
              {data.current.score.toFixed(1)}
            </span>
            <span className="mb-3 text-sm uppercase tracking-[0.24em] text-slate-500">
              / 100
            </span>
          </div>
          <div className="mb-3 rounded-full border border-white/10 bg-white/5 px-3 py-2 text-xs uppercase tracking-[0.26em] text-slate-200">
            {data.current.label}
          </div>
        </div>
        <p className={cn("max-w-2xl text-sm text-slate-300", compact ? "mt-4 leading-6" : "mt-5 leading-7")}>
          {data.current.summary}
        </p>
        <div className={cn("flex flex-wrap gap-3 text-[11px] uppercase tracking-[0.24em] text-slate-400", compact ? "mt-4" : "mt-5")}>
          <span className="rounded-full border border-white/10 px-3 py-2">
            source {data.current.sourceBlend}
          </span>
          <span className="rounded-full border border-white/10 px-3 py-2">
            confidence {Math.round(data.current.confidence * 100)}%
          </span>
          {data.current.routeObservation ? (
            <span className="rounded-full border border-white/10 px-3 py-2">
              {data.current.routeObservation.validRouteCount} route probes
            </span>
          ) : (
            <span className="rounded-full border border-white/10 px-3 py-2">
              no direct route probe
            </span>
          )}
        </div>
      </div>
      <div className="grid gap-3 rounded-[28px] border border-white/10 bg-black/20 p-4">
        <div className="grid grid-cols-3 gap-3">
          <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
            <p className="text-xs uppercase tracking-[0.26em] text-slate-500">Traffic</p>
            <p className="mt-3 text-2xl font-semibold text-slate-100">
              {data.current.breakdown.trafficScore === null
                ? "n/a"
                : data.current.breakdown.trafficScore.toFixed(1)}
            </p>
          </div>
          <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
            <p className="text-xs uppercase tracking-[0.26em] text-slate-500">Weather</p>
            <p className="mt-3 text-2xl font-semibold text-slate-100">
              {data.current.breakdown.weatherScore.toFixed(1)}
            </p>
          </div>
          <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
            <p className="text-xs uppercase tracking-[0.26em] text-slate-500">Demand</p>
            <p className="mt-3 text-2xl font-semibold text-slate-100">
              {data.current.breakdown.demandScore.toFixed(1)}
            </p>
          </div>
        </div>
        <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
          <p className="text-xs uppercase tracking-[0.26em] text-slate-500">
            Last updated
          </p>
          <p className="mt-3 text-base text-slate-100">
            {data.lastUpdatedAt
              ? new Intl.DateTimeFormat("en-US", {
                  dateStyle: "medium",
                  timeStyle: "short",
                  timeZone: data.city.timezone,
                }).format(new Date(data.lastUpdatedAt))
              : "No snapshot yet"}
          </p>
          {data.stale && data.staleReason ? (
            <p className="mt-2 text-sm text-amber-200">{data.staleReason}</p>
          ) : null}
        </div>
      </div>
    </section>
  );
}

export function MarketWidget({
  variant = "dashboard",
}: {
  variant?: "dashboard" | "widget";
}) {
  const isWidget = variant === "widget";
  const { ready, storedCity, persistCity } = useLocalCity();
  const [selectedCity, setSelectedCity] = useState<CitySelection | null>(null);
  const [dashboard, setDashboard] = useState<DashboardResponse | null>(null);
  const [search, setSearch] = useState("");
  const deferredSearch = useDeferredValue(search);
  const [suggestions, setSuggestions] = useState<CitySelection[]>([]);
  const [loading, setLoading] = useState(false);
  const [detecting, setDetecting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [usedIpFallback, setUsedIpFallback] = useState(false);

  const fetchDashboard = useCallback(async (city: CitySelection) => {
    setLoading(true);
    setError(null);

    try {
      const response = await fetch("/api/market", {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({ city }),
      });

      if (!response.ok) {
        const payload = (await response.json()) as { error?: string };
        throw new Error(payload.error ?? "Could not load the market dashboard.");
      }

      const payload = (await response.json()) as DashboardResponse;
      setDashboard(payload);
    } catch (fetchError) {
      setError(
        fetchError instanceof Error
          ? fetchError.message
          : "Could not load the market dashboard.",
      );
    } finally {
      setLoading(false);
    }
  }, []);

  const detectByIp = useCallback(async () => {
    const response = await fetch("/api/cities/ip");
    if (!response.ok) {
      throw new Error("Could not estimate your city from IP geolocation.");
    }

    const payload = (await response.json()) as {
      city: CitySelection;
      approximate: boolean;
    };

    persistCity(payload.city);
    setUsedIpFallback(payload.approximate);
    startTransition(() => {
      setSelectedCity(payload.city);
    });
  }, [persistCity]);

  const detectLocation = useCallback(async () => {
    if (!navigator.geolocation) {
      await detectByIp();
      return;
    }

    setDetecting(true);
    setError(null);

    try {
      const position = await new Promise<GeolocationPosition>((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject, {
          enableHighAccuracy: false,
          maximumAge: 1000 * 60 * 30,
          timeout: 12000,
        });
      });

      const url = new URL("/api/cities/reverse", window.location.origin);
      url.searchParams.set("lat", String(position.coords.latitude));
      url.searchParams.set("lon", String(position.coords.longitude));
      const response = await fetch(url.toString());

      if (!response.ok) {
        throw new Error("Could not resolve your current city.");
      }

      const payload = (await response.json()) as { city: CitySelection };
      persistCity(payload.city);
      setUsedIpFallback(false);
      startTransition(() => {
        setSelectedCity(payload.city);
      });
    } catch (detectionError) {
      try {
        await detectByIp();
      } catch {
        setError(
          detectionError instanceof Error
            ? detectionError.message
            : "Could not detect your current city.",
        );
      }
    } finally {
      setDetecting(false);
    }
  }, [detectByIp, persistCity]);

  useEffect(() => {
    if (!ready) {
      return;
    }

    if (storedCity) {
      setSelectedCity(storedCity);
      return;
    }

    void detectLocation();
  }, [detectLocation, ready, storedCity]);

  useEffect(() => {
    if (!selectedCity) {
      return;
    }

    persistCity(selectedCity);
    void fetchDashboard(selectedCity);
  }, [fetchDashboard, persistCity, selectedCity]);

  useEffect(() => {
    if (deferredSearch.trim().length < 2) {
      setSuggestions([]);
      return;
    }

    let cancelled = false;
    const url = new URL("/api/cities/search", window.location.origin);
    url.searchParams.set("q", deferredSearch.trim());

    void fetch(url.toString())
      .then((response) => response.json() as Promise<{ cities: CitySelection[] }>)
      .then((payload) => {
        if (!cancelled) {
          setSuggestions(payload.cities);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setSuggestions([]);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [deferredSearch]);

  return (
    <div
      className={cn(
        "min-h-screen text-slate-100",
        isWidget
          ? "bg-[#0d1117]"
          : "bg-[radial-gradient(circle_at_top,#1e293b_0%,#020617_58%)]",
      )}
    >
      <div
        className={cn(
          "mx-auto flex w-full flex-col gap-5",
          isWidget
            ? "max-w-[460px] px-3 py-3 sm:px-4"
            : "max-w-7xl px-4 py-8 sm:px-6 lg:px-10",
        )}
      >
        <header
          className={cn(
            "flex flex-col gap-5 rounded-[32px] border border-white/10 bg-black/20 backdrop-blur",
            isWidget ? "p-4" : "p-5 lg:flex-row lg:items-end lg:justify-between",
          )}
        >
          <div>
            <p className="text-xs uppercase tracking-[0.42em] text-cyan-200/80">
              {isWidget ? "desktop widget" : "real-time city widget"}
            </p>
            <h1
              className={cn(
                "mt-3 font-semibold tracking-tight text-white",
                isWidget ? "max-w-md text-2xl leading-8" : "max-w-3xl text-3xl sm:text-4xl",
              )}
            >
              {isWidget
                ? "Compact ride-pressure widget for your phone home screen."
                : "Know if getting a ride now is smart, normal, or expensive for the city you are in."}
            </h1>
            <p
              className={cn(
                "mt-3 text-sm text-slate-300",
                isWidget ? "max-w-md leading-6" : "max-w-2xl leading-7",
              )}
            >
              {isWidget
                ? "Styled like a mobile widget and installable as a standalone web app on Android or iPhone home screens."
                : "This widget tracks city-level pressure, not a door-to-door quote. It uses real route and weather observations where available, and marks inferred or unsupported areas openly."}
            </p>
          </div>
          <div className={cn("grid gap-3", isWidget ? "" : "lg:min-w-[22rem]")}>
            <div className="relative">
              <Search className="pointer-events-none absolute left-4 top-1/2 size-4 -translate-y-1/2 text-slate-500" />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search any city"
                className="h-12 w-full rounded-2xl border border-white/10 bg-white/5 pl-11 pr-4 text-sm text-white outline-none transition focus:border-cyan-300/40 focus:bg-white/8"
              />
              {suggestions.length ? (
                <div className="absolute inset-x-0 top-[calc(100%+0.5rem)] z-20 rounded-2xl border border-white/10 bg-slate-950/95 p-2 shadow-2xl backdrop-blur">
                  {suggestions.map((city) => (
                    <button
                      key={`${city.id}-${city.latitude}`}
                      type="button"
                      className="flex w-full items-start justify-between rounded-xl px-3 py-3 text-left transition hover:bg-white/5"
                      onClick={() => {
                        setSearch(`${city.name}, ${city.country}`);
                        setSuggestions([]);
                        startTransition(() => {
                          setSelectedCity(city);
                        });
                      }}
                    >
                      <div>
                        <p className="text-sm font-medium text-white">{city.name}</p>
                        <p className="mt-1 text-xs text-slate-400">
                          {[city.admin1, city.country].filter(Boolean).join(", ")}
                        </p>
                      </div>
                      <MapPin className="mt-0.5 size-4 text-slate-500" />
                    </button>
                  ))}
                </div>
              ) : null}
            </div>
            <div className="flex flex-wrap items-center gap-3">
              <button
                type="button"
                onClick={() => void detectLocation()}
                className="inline-flex h-11 items-center gap-2 rounded-2xl border border-cyan-300/20 bg-cyan-300/10 px-4 text-sm text-cyan-100 transition hover:bg-cyan-300/15"
              >
                {detecting ? (
                  <LoaderCircle className="size-4 animate-spin" />
                ) : (
                  <LocateFixed className="size-4" />
                )}
                detect my city
              </button>
              {selectedCity ? (
                <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-slate-200">
                  {selectedCity.name}, {selectedCity.country}
                  {usedIpFallback ? (
                    <span className="ml-2 text-xs uppercase tracking-[0.22em] text-slate-500">
                      approx
                    </span>
                  ) : null}
                </div>
              ) : (
                <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-slate-400">
                  Waiting for location or manual city selection
                </div>
              )}
            </div>
            {!isWidget ? (
              <div className="flex items-center gap-3 text-xs uppercase tracking-[0.22em] text-slate-500">
                <Link
                  href="/widget"
                  className="rounded-full border border-white/10 px-3 py-2 text-slate-300 transition hover:bg-white/5"
                >
                  widget mode
                </Link>
                <span>installable on Android and iPhone home screens</span>
              </div>
            ) : null}
          </div>
        </header>

        {error ? (
          <div className="rounded-[28px] border border-rose-400/20 bg-rose-500/10 p-4 text-sm text-rose-100">
            {error}
          </div>
        ) : null}

        {loading && !dashboard ? (
          <div className="rounded-[32px] border border-white/10 bg-black/20 p-8 text-sm text-slate-300">
            <div className="flex items-center gap-3">
              <LoaderCircle className="size-4 animate-spin" />
              Building the first real market snapshot for the selected city.
            </div>
          </div>
        ) : null}

        {dashboard ? (
          <>
            <CurrentSummary data={dashboard} variant={variant} />

            <div className="grid gap-5">
              <PressureChart
                title={dashboard.dailyChart.title}
                subtitle={dashboard.dailyChart.subtitle}
                points={dashboard.dailyChart.points}
                kind="daily"
              />
              <PressureChart
                title={dashboard.hourlyChart.title}
                subtitle={dashboard.hourlyChart.subtitle}
                points={dashboard.hourlyChart.points}
                kind="hourly"
              />
            </div>

            {isWidget ? (
              <section className="rounded-[30px] border border-white/10 bg-[#232326] p-4">
                <div className="mb-4 flex items-center justify-between gap-3">
                  <div>
                    <p className="text-[10px] uppercase tracking-[0.32em] text-slate-500">
                      provider state
                    </p>
                    <p className="mt-2 text-sm leading-6 text-slate-300">
                      Honest provider visibility. No fabricated fare colors.
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => selectedCity && void fetchDashboard(selectedCity)}
                    className="inline-flex h-10 items-center gap-2 rounded-2xl border border-white/10 bg-white/5 px-3 text-xs uppercase tracking-[0.22em] text-slate-200 transition hover:bg-white/10"
                  >
                    <RefreshCcw className="size-3.5" />
                    refresh
                  </button>
                </div>
                <div className="grid gap-2">
                  {dashboard.providerSnapshots.map((provider) => (
                    <ProviderChip key={provider.provider} provider={provider} />
                  ))}
                </div>
                <div className="mt-4 space-y-2">
                  {dashboard.notes.map((note) => (
                    <p key={note} className="text-xs leading-6 text-slate-400">
                      {note}
                    </p>
                  ))}
                </div>
              </section>
            ) : (
              <section className="grid gap-4 rounded-[28px] border border-white/10 bg-black/20 p-5 lg:grid-cols-[1.15fr_0.85fr]">
                <div>
                  <div className="flex items-center justify-between gap-4">
                    <div>
                      <p className="text-xs uppercase tracking-[0.34em] text-slate-400">
                        provider state
                      </p>
                      <p className="mt-2 text-sm leading-6 text-slate-300">
                        Provider cards stay neutral until a real provider price can be observed
                        and compared against that provider&apos;s own recent city baseline.
                      </p>
                    </div>
                    <button
                      type="button"
                      onClick={() => selectedCity && void fetchDashboard(selectedCity)}
                      className="inline-flex h-11 items-center gap-2 rounded-2xl border border-white/10 bg-white/5 px-4 text-sm text-slate-200 transition hover:bg-white/10"
                    >
                      <RefreshCcw className="size-4" />
                      refresh
                    </button>
                  </div>
                  <div className="mt-4 grid gap-3 sm:grid-cols-2">
                    {dashboard.providerSnapshots.map((provider) => (
                      <ProviderCard key={provider.provider} provider={provider} />
                    ))}
                  </div>
                </div>
                <div className="rounded-[24px] border border-white/10 bg-slate-950/60 p-4">
                  <p className="text-xs uppercase tracking-[0.34em] text-slate-400">
                    honesty layer
                  </p>
                  <div className="mt-4 space-y-3">
                    {dashboard.notes.map((note) => (
                      <p key={note} className="text-sm leading-7 text-slate-300">
                        {note}
                      </p>
                    ))}
                  </div>
                </div>
              </section>
            )}
          </>
        ) : null}
      </div>
    </div>
  );
}
