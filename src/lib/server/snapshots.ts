import crypto from "node:crypto";

import { getDb } from "@/lib/server/db";
import type { ObservedSnapshot, ProviderId, ProviderSnapshot, RouteObservation } from "@/lib/types";

type StoredCitySnapshotRow = {
  id: string;
  city_id: string;
  city_name: string;
  country_code: string;
  latitude: number;
  longitude: number;
  observed_at: string;
  score: number;
  tone: ObservedSnapshot["tone"];
  label: string;
  summary: string;
  source_blend: ObservedSnapshot["sourceBlend"];
  confidence: number;
  route_observation_json: string | null;
  breakdown_json: string;
};

type StoredProviderSnapshotRow = {
  provider: ProviderId;
  observed_at: string | null;
  support_level: ProviderSnapshot["supportLevel"];
  availability_state: ProviderSnapshot["availabilityState"];
  tone: ProviderSnapshot["tone"];
  status_label: string;
  source_blend: ProviderSnapshot["sourceBlend"];
  note: string;
  freshness_hours: number | null;
  signals_json: string;
};

function mapProviderSnapshot(row: StoredProviderSnapshotRow): ProviderSnapshot {
  return {
    provider: row.provider,
    observedAt: row.observed_at,
    supportLevel: row.support_level,
    availabilityState: row.availability_state,
    tone: row.tone,
    statusLabel: row.status_label,
    sourceBlend: row.source_blend,
    note: row.note,
    freshnessHours: row.freshness_hours,
    signals: JSON.parse(row.signals_json) as ProviderSnapshot["signals"],
  };
}

export function getLatestSnapshot(cityId: string): ObservedSnapshot | null {
  const db = getDb();
  const cityRow = db
    .prepare(
      `
        SELECT *
        FROM city_snapshots
        WHERE city_id = ?
        ORDER BY observed_at DESC
        LIMIT 1
      `,
    )
    .get(cityId) as StoredCitySnapshotRow | undefined;

  if (!cityRow) {
    return null;
  }

  const providerRows = db
    .prepare(
      `
        SELECT provider, observed_at, support_level, availability_state, tone,
               status_label, source_blend, note, freshness_hours, signals_json
        FROM provider_snapshots
        WHERE city_snapshot_id = ?
        ORDER BY provider
      `,
    )
    .all(cityRow.id) as StoredProviderSnapshotRow[];

  return {
    city: {
      id: cityRow.city_id,
      name: cityRow.city_name,
      country: "",
      countryCode: cityRow.country_code,
      latitude: cityRow.latitude,
      longitude: cityRow.longitude,
      timezone: "",
    },
    observedAt: cityRow.observed_at,
    score: cityRow.score,
    tone: cityRow.tone,
    label: cityRow.label,
    summary: cityRow.summary,
    sourceBlend: cityRow.source_blend,
    confidence: cityRow.confidence,
    routeObservation: cityRow.route_observation_json
      ? (JSON.parse(cityRow.route_observation_json) as RouteObservation)
      : null,
    breakdown: JSON.parse(cityRow.breakdown_json) as ObservedSnapshot["breakdown"],
    providerSnapshots: providerRows.map(mapProviderSnapshot),
  };
}

export function listRecentRouteMedians(cityId: string, limit = 24) {
  const db = getDb();
  const rows = db
    .prepare(
      `
        SELECT route_observation_json
        FROM city_snapshots
        WHERE city_id = ?
          AND route_observation_json IS NOT NULL
        ORDER BY observed_at DESC
        LIMIT ?
      `,
    )
    .all(cityId, limit) as Array<{ route_observation_json: string }>;

  return rows
    .map((row) => JSON.parse(row.route_observation_json) as RouteObservation)
    .filter((route) => Number.isFinite(route.medianSecondsPerKm))
    .map((route) => route.medianSecondsPerKm);
}

export function listRecentProviderPrices(cityId: string, provider: ProviderId, limit = 24) {
  const db = getDb();
  const rows = db
    .prepare(
      `
        SELECT signals_json
        FROM provider_snapshots
        WHERE city_id = ?
          AND provider = ?
        ORDER BY observed_at DESC
        LIMIT ?
      `,
    )
    .all(cityId, provider, limit) as Array<{ signals_json: string }>;

  return rows
    .map((row) => JSON.parse(row.signals_json) as ProviderSnapshot["signals"])
    .map((signals) => signals.priceAmount)
    .filter((value): value is number => typeof value === "number" && Number.isFinite(value));
}

export function saveSnapshot(snapshot: ObservedSnapshot) {
  const db = getDb();
  const snapshotId = crypto.randomUUID();
  const insertSnapshot = db.prepare(`
    INSERT INTO city_snapshots (
      id,
      city_id,
      city_name,
      country_code,
      latitude,
      longitude,
      observed_at,
      score,
      tone,
      label,
      summary,
      source_blend,
      confidence,
      route_observation_json,
      breakdown_json
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  const insertProvider = db.prepare(`
    INSERT INTO provider_snapshots (
      id,
      city_snapshot_id,
      city_id,
      provider,
      observed_at,
      support_level,
      availability_state,
      tone,
      status_label,
      source_blend,
      note,
      freshness_hours,
      signals_json
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);

  const transaction = db.transaction(() => {
    insertSnapshot.run(
      snapshotId,
      snapshot.city.id,
      snapshot.city.name,
      snapshot.city.countryCode,
      snapshot.city.latitude,
      snapshot.city.longitude,
      snapshot.observedAt,
      snapshot.score,
      snapshot.tone,
      snapshot.label,
      snapshot.summary,
      snapshot.sourceBlend,
      snapshot.confidence,
      snapshot.routeObservation ? JSON.stringify(snapshot.routeObservation) : null,
      JSON.stringify(snapshot.breakdown),
    );

    for (const providerSnapshot of snapshot.providerSnapshots) {
      insertProvider.run(
        crypto.randomUUID(),
        snapshotId,
        snapshot.city.id,
        providerSnapshot.provider,
        providerSnapshot.observedAt,
        providerSnapshot.supportLevel,
        providerSnapshot.availabilityState,
        providerSnapshot.tone,
        providerSnapshot.statusLabel,
        providerSnapshot.sourceBlend,
        providerSnapshot.note,
        providerSnapshot.freshnessHours,
        JSON.stringify(providerSnapshot.signals),
      );
    }
  });

  transaction();
}
