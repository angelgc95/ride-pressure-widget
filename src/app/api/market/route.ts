import { NextResponse } from "next/server";
import { z } from "zod";

import { getDashboard } from "@/lib/server/market";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const citySchema = z.object({
  id: z.string(),
  name: z.string(),
  country: z.string(),
  countryCode: z.string().length(2),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  timezone: z.string().min(1),
  admin1: z.string().nullable().optional(),
  population: z.number().nullable().optional(),
});

const requestSchema = z.object({
  city: citySchema,
});

export async function POST(request: Request) {
  const body = await request.json();
  const parsed = requestSchema.safeParse(body);

  if (!parsed.success) {
    return NextResponse.json(
      { error: "Invalid city payload." },
      { status: 400 },
    );
  }

  try {
    const dashboard = await getDashboard(parsed.data.city);
    return NextResponse.json(dashboard);
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "Failed to build the market snapshot.",
      },
      { status: 502 },
    );
  }
}
