import { z } from "zod";

import { fetchJson } from "@/lib/server/http";
import { searchCities } from "@/lib/server/sources/open-meteo";
import type { CitySelection } from "@/lib/types";

const reverseSchema = z.object({
  address: z
    .object({
      city: z.string().optional(),
      town: z.string().optional(),
      village: z.string().optional(),
      municipality: z.string().optional(),
      county: z.string().optional(),
      state: z.string().optional(),
      country: z.string(),
      country_code: z.string(),
    })
    .optional(),
});

function makeCityId(name: string, countryCode: string, latitude: number, longitude: number) {
  return `${name.toLowerCase().replaceAll(/[^a-z0-9]+/g, "-")}-${countryCode.toLowerCase()}-${latitude.toFixed(2)}-${longitude.toFixed(2)}`;
}

export async function reverseGeocodeCity(latitude: number, longitude: number) {
  const url = new URL("https://nominatim.openstreetmap.org/reverse");
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("lat", String(latitude));
  url.searchParams.set("lon", String(longitude));
  url.searchParams.set("zoom", "10");
  url.searchParams.set("addressdetails", "1");
  url.searchParams.set("accept-language", "en");

  const payload = reverseSchema.parse(
    await fetchJson(url.toString(), {
      name: "Nominatim reverse geocoding",
      headers: {
        accept: "application/json",
        "content-type": "application/json",
        "user-agent": "ride-pressure-widget/0.1 (local development)",
      },
    }),
  );

  const name =
    payload.address?.city ??
    payload.address?.town ??
    payload.address?.village ??
    payload.address?.municipality ??
    payload.address?.county;

  if (!name || !payload.address) {
    return null;
  }

  const candidates = await searchCities(name);
  const best =
    candidates.find((candidate) => candidate.countryCode.toLowerCase() === payload.address?.country_code.toLowerCase()) ??
    candidates[0];

  if (best) {
    return best;
  }

  return {
    id: makeCityId(name, payload.address.country_code, latitude, longitude),
    name,
    country: payload.address.country,
    countryCode: payload.address.country_code.toUpperCase(),
    latitude,
    longitude,
    timezone: "auto",
    admin1: payload.address.state ?? null,
    population: null,
  } satisfies CitySelection;
}
