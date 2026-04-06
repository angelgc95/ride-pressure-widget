import { z } from "zod";

import { fetchJson } from "@/lib/server/http";
import type { CitySelection } from "@/lib/types";

const geocodingSchema = z.object({
  results: z
    .array(
      z.object({
        id: z.number().optional(),
        name: z.string(),
        latitude: z.number(),
        longitude: z.number(),
        country: z.string(),
        country_code: z.string(),
        timezone: z.string(),
        admin1: z.string().nullable().optional(),
        population: z.number().nullable().optional(),
      }),
    )
    .optional(),
});

const weatherSchema = z.object({
  current: z.object({
    time: z.string(),
    temperature_2m: z.number(),
    apparent_temperature: z.number(),
    precipitation: z.number(),
    rain: z.number().nullable().optional(),
    showers: z.number().nullable().optional(),
    snowfall: z.number().nullable().optional(),
    wind_speed_10m: z.number(),
  }),
  hourly: z.object({
    time: z.array(z.string()),
    temperature_2m: z.array(z.number()),
    apparent_temperature: z.array(z.number()),
    precipitation_probability: z.array(z.number()),
    precipitation: z.array(z.number()),
    rain: z.array(z.number()),
    showers: z.array(z.number()),
    snowfall: z.array(z.number()),
    wind_speed_10m: z.array(z.number()),
    cloud_cover: z.array(z.number()),
  }),
  daily: z.object({
    time: z.array(z.string()),
    temperature_2m_max: z.array(z.number()),
    temperature_2m_min: z.array(z.number()),
    precipitation_sum: z.array(z.number()),
    precipitation_hours: z.array(z.number()),
    wind_speed_10m_max: z.array(z.number()),
  }),
});

type GeocodingResult = NonNullable<z.infer<typeof geocodingSchema>["results"]>[number];

export interface WeatherSnapshot {
  current: z.infer<typeof weatherSchema>["current"];
  hourly: Array<{
    time: string;
    temperature: number;
    apparentTemperature: number;
    precipitationProbability: number;
    precipitation: number;
    rain: number;
    showers: number;
    snowfall: number;
    windSpeed: number;
    cloudCover: number;
  }>;
  daily: Array<{
    time: string;
    temperatureMax: number;
    temperatureMin: number;
    precipitationSum: number;
    precipitationHours: number;
    windSpeedMax: number;
  }>;
}

function toCitySelection(input: GeocodingResult): CitySelection {
  const sourceId = input.id ?? `${input.name}-${input.country_code}-${input.latitude}-${input.longitude}`;

  return {
    id: String(sourceId),
    name: input.name,
    country: input.country,
    countryCode: input.country_code,
    latitude: input.latitude,
    longitude: input.longitude,
    timezone: input.timezone,
    admin1: input.admin1 ?? null,
    population: input.population ?? null,
  };
}

export async function searchCities(query: string) {
  const url = new URL("https://geocoding-api.open-meteo.com/v1/search");
  url.searchParams.set("name", query);
  url.searchParams.set("count", "8");
  url.searchParams.set("language", "en");
  url.searchParams.set("format", "json");

  const payload = geocodingSchema.parse(
    await fetchJson(url.toString(), {
      name: "Open-Meteo geocoding",
      headers: {
        accept: "application/json",
      },
    }),
  );

  return (payload.results ?? []).map(toCitySelection);
}

export async function fetchWeather(city: CitySelection): Promise<WeatherSnapshot> {
  const url = new URL("https://api.open-meteo.com/v1/forecast");
  url.searchParams.set("latitude", String(city.latitude));
  url.searchParams.set("longitude", String(city.longitude));
  url.searchParams.set(
    "current",
    [
      "temperature_2m",
      "apparent_temperature",
      "precipitation",
      "rain",
      "showers",
      "snowfall",
      "wind_speed_10m",
    ].join(","),
  );
  url.searchParams.set(
    "hourly",
    [
      "temperature_2m",
      "apparent_temperature",
      "precipitation_probability",
      "precipitation",
      "rain",
      "showers",
      "snowfall",
      "wind_speed_10m",
      "cloud_cover",
    ].join(","),
  );
  url.searchParams.set(
    "daily",
    [
      "temperature_2m_max",
      "temperature_2m_min",
      "precipitation_sum",
      "precipitation_hours",
      "wind_speed_10m_max",
    ].join(","),
  );
  url.searchParams.set("timezone", city.timezone);
  url.searchParams.set("forecast_days", "7");

  const payload = weatherSchema.parse(
    await fetchJson(url.toString(), {
      name: "Open-Meteo forecast",
      headers: {
        accept: "application/json",
      },
    }),
  );

  return {
    current: payload.current,
    hourly: payload.hourly.time.map((time, index) => ({
      time,
      temperature: payload.hourly.temperature_2m[index],
      apparentTemperature: payload.hourly.apparent_temperature[index],
      precipitationProbability: payload.hourly.precipitation_probability[index],
      precipitation: payload.hourly.precipitation[index],
      rain: payload.hourly.rain[index],
      showers: payload.hourly.showers[index],
      snowfall: payload.hourly.snowfall[index],
      windSpeed: payload.hourly.wind_speed_10m[index],
      cloudCover: payload.hourly.cloud_cover[index],
    })),
    daily: payload.daily.time.map((time, index) => ({
      time,
      temperatureMax: payload.daily.temperature_2m_max[index],
      temperatureMin: payload.daily.temperature_2m_min[index],
      precipitationSum: payload.daily.precipitation_sum[index],
      precipitationHours: payload.daily.precipitation_hours[index],
      windSpeedMax: payload.daily.wind_speed_10m_max[index],
    })),
  };
}
