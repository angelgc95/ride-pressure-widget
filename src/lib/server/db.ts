import Database from "better-sqlite3";
import fs from "node:fs";
import path from "node:path";

const dbPath =
  process.env.RIDE_PRESSURE_DB_PATH ??
  path.join(process.cwd(), "data", "ride-pressure.sqlite");

declare global {
  var __ridePressureDb: Database.Database | undefined;
}

function initDatabase() {
  fs.mkdirSync(path.dirname(dbPath), { recursive: true });

  const db = new Database(dbPath);
  db.pragma("journal_mode = WAL");
  db.exec(`
    CREATE TABLE IF NOT EXISTS city_snapshots (
      id TEXT PRIMARY KEY,
      city_id TEXT NOT NULL,
      city_name TEXT NOT NULL,
      country_code TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      observed_at TEXT NOT NULL,
      score REAL NOT NULL,
      tone TEXT NOT NULL,
      label TEXT NOT NULL,
      summary TEXT NOT NULL,
      source_blend TEXT NOT NULL,
      confidence REAL NOT NULL,
      route_observation_json TEXT,
      breakdown_json TEXT NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_city_snapshots_city_observed
    ON city_snapshots (city_id, observed_at DESC);

    CREATE TABLE IF NOT EXISTS provider_snapshots (
      id TEXT PRIMARY KEY,
      city_snapshot_id TEXT NOT NULL,
      city_id TEXT NOT NULL,
      provider TEXT NOT NULL,
      observed_at TEXT,
      support_level TEXT NOT NULL,
      availability_state TEXT NOT NULL,
      tone TEXT NOT NULL,
      status_label TEXT NOT NULL,
      source_blend TEXT NOT NULL,
      note TEXT NOT NULL,
      freshness_hours REAL,
      signals_json TEXT NOT NULL,
      FOREIGN KEY (city_snapshot_id) REFERENCES city_snapshots(id)
    );

    CREATE INDEX IF NOT EXISTS idx_provider_snapshots_city_provider
    ON provider_snapshots (city_id, provider, observed_at DESC);
  `);

  return db;
}

export function getDb() {
  if (!global.__ridePressureDb) {
    global.__ridePressureDb = initDatabase();
  }

  return global.__ridePressureDb;
}

export { dbPath };
