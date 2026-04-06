import { NextResponse } from "next/server";
import { z } from "zod";

import { searchCities } from "@/lib/server/sources/open-meteo";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const querySchema = z.object({
  q: z.string().trim().min(2),
});

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const parsed = querySchema.safeParse({
    q: searchParams.get("q") ?? "",
  });

  if (!parsed.success) {
    return NextResponse.json({ cities: [] });
  }

  const cities = await searchCities(parsed.data.q);
  return NextResponse.json({ cities });
}
