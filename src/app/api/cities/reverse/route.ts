import { NextResponse } from "next/server";
import { z } from "zod";

import { reverseDetectCity } from "@/lib/server/market";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const querySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lon: z.coerce.number().min(-180).max(180),
});

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const parsed = querySchema.safeParse({
    lat: searchParams.get("lat"),
    lon: searchParams.get("lon"),
  });

  if (!parsed.success) {
    return NextResponse.json(
      { error: "Invalid coordinates." },
      { status: 400 },
    );
  }

  const city = await reverseDetectCity(parsed.data.lat, parsed.data.lon);

  if (!city) {
    return NextResponse.json(
      { error: "Could not resolve a city from the provided coordinates." },
      { status: 404 },
    );
  }

  return NextResponse.json({ city });
}
