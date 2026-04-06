import { NextResponse } from "next/server";
import { z } from "zod";

import { reverseDetectCity } from "@/lib/server/market";
import { fetchJson } from "@/lib/server/http";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const ipSchema = z.object({
  success: z.boolean(),
  city: z.string().optional(),
  country: z.string().optional(),
  latitude: z.number().optional(),
  longitude: z.number().optional(),
});

export async function GET() {
  const ipResult = ipSchema.parse(
    await fetchJson("https://ipwho.is/", {
      name: "ipwho.is geolocation",
      headers: {
        accept: "application/json",
      },
    }),
  );

  if (!ipResult.success || typeof ipResult.latitude !== "number" || typeof ipResult.longitude !== "number") {
    return NextResponse.json(
      { error: "Could not resolve a city from IP geolocation." },
      { status: 502 },
    );
  }

  const city = await reverseDetectCity(ipResult.latitude, ipResult.longitude);

  if (!city) {
    return NextResponse.json(
      { error: "Could not resolve a city from IP geolocation." },
      { status: 502 },
    );
  }

  return NextResponse.json({
    city,
    approximate: true,
  });
}
