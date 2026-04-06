export const providerIds = ["uber", "bolt", "cabify", "freenow"] as const;

export type ProviderId = (typeof providerIds)[number];
export type SourceBlend = "direct" | "mixed" | "inferred" | "unavailable";
export type SupportLevel = "supported" | "limited" | "unsupported";
export type AvailabilityState = "available" | "limited" | "unsupported" | "stale";
export type PressureTone = "favorable" | "normal" | "unfavorable" | "neutral";

export interface CitySelection {
  id: string;
  name: string;
  country: string;
  countryCode: string;
  latitude: number;
  longitude: number;
  timezone: string;
  admin1?: string | null;
  population?: number | null;
}

export interface RouteObservation {
  routeCount: number;
  validRouteCount: number;
  averageEtaSeconds: number;
  averageDistanceMeters: number;
  medianSecondsPerKm: number;
  baselineSecondsPerKm: number | null;
  directness: SourceBlend;
  note: string;
}

export interface ProviderSignalDetails {
  priceAmount?: number | null;
  currencyCode?: string | null;
  baselinePrice?: number | null;
  relativeDelta?: number | null;
  etaSeconds?: number | null;
  distanceMeters?: number | null;
  surgeIndicator?: string | null;
  routeObservation?: RouteObservation | null;
}

export interface ProviderSnapshot {
  provider: ProviderId;
  supportLevel: SupportLevel;
  availabilityState: AvailabilityState;
  tone: PressureTone;
  statusLabel: string;
  observedAt: string | null;
  sourceBlend: SourceBlend;
  note: string;
  freshnessHours: number | null;
  signals: ProviderSignalDetails;
}

export interface SnapshotScoreBreakdown {
  trafficScore: number | null;
  weatherScore: number;
  demandScore: number;
  trafficWeight: number;
  weatherWeight: number;
  demandWeight: number;
}

export interface ObservedSnapshot {
  city: CitySelection;
  observedAt: string;
  score: number;
  tone: Exclude<PressureTone, "neutral">;
  label: string;
  summary: string;
  sourceBlend: SourceBlend;
  confidence: number;
  routeObservation: RouteObservation | null;
  breakdown: SnapshotScoreBreakdown;
  providerSnapshots: ProviderSnapshot[];
}

export interface ChartPoint {
  key: string;
  label: string;
  timestamp: string;
  score: number;
  tone: Exclude<PressureTone, "neutral">;
  sourceBlend: SourceBlend;
  confidence: number;
  explanation: string;
  trafficScore: number | null;
  weatherScore: number;
  demandScore: number;
  trafficComponent: number;
  weatherComponent: number;
  demandComponent: number;
  neutralComponent: number;
}

export interface DashboardResponse {
  city: CitySelection;
  lastUpdatedAt: string | null;
  stale: boolean;
  staleReason: string | null;
  current: ObservedSnapshot;
  hourlyChart: {
    title: string;
    subtitle: string;
    points: ChartPoint[];
  };
  dailyChart: {
    title: string;
    subtitle: string;
    points: ChartPoint[];
  };
  providerSnapshots: ProviderSnapshot[];
  notes: string[];
}

export interface SearchCitiesResponse {
  cities: CitySelection[];
}
