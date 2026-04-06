"use client";

import { useSyncExternalStore } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import { cn } from "@/lib/utils";
import type { ChartPoint } from "@/lib/types";

type PressureChartProps = {
  title: string;
  subtitle: string;
  points: ChartPoint[];
  kind: "daily" | "hourly";
};

const colors = {
  base: "rgba(255,255,255,0.12)",
  grid: "rgba(255,255,255,0.08)",
  axis: "#777783",
  label: "#9d9da6",
  line: "rgba(255,255,255,0.38)",
};

function fillForTone(tone: ChartPoint["tone"], muted = false) {
  if (tone === "favorable") {
    return muted ? "rgba(34,197,94,0.42)" : "#22c55e";
  }

  if (tone === "unfavorable") {
    return muted ? "rgba(244,63,94,0.42)" : "#f43f5e";
  }

  return muted ? "rgba(245,158,11,0.42)" : "#f59e0b";
}

function toneClass(score: number) {
  if (score <= 34) {
    return "text-emerald-300";
  }

  if (score <= 66) {
    return "text-amber-300";
  }

  return "text-rose-300";
}

function PressureTooltip({
  active,
  payload,
}: {
  active?: boolean;
  payload?: Array<{ payload: ChartPoint }>;
}) {
  if (!active || !payload?.length) {
    return null;
  }

  const point = payload[0].payload;

  return (
    <div className="w-64 rounded-2xl border border-white/10 bg-[#1d1d20]/95 p-4 shadow-2xl backdrop-blur">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.24em] text-slate-400">
            {point.label}
          </p>
          <p className={cn("mt-2 text-2xl font-semibold", toneClass(point.score))}>
            {point.score.toFixed(1)}
          </p>
        </div>
        <span className="rounded-full border border-white/10 px-2 py-1 text-[10px] uppercase tracking-[0.22em] text-slate-300">
          {point.sourceBlend}
        </span>
      </div>
      <div className="mt-4 grid grid-cols-3 gap-3 text-[11px] text-slate-400">
        <div>
          <p className="uppercase tracking-[0.18em]">traffic</p>
          <p className="mt-1 text-sm text-slate-100">
            {point.trafficScore === null ? "n/a" : point.trafficScore.toFixed(1)}
          </p>
        </div>
        <div>
          <p className="uppercase tracking-[0.18em]">weather</p>
          <p className="mt-1 text-sm text-slate-100">{point.weatherScore.toFixed(1)}</p>
        </div>
        <div>
          <p className="uppercase tracking-[0.18em]">demand</p>
          <p className="mt-1 text-sm text-slate-100">{point.demandScore.toFixed(1)}</p>
        </div>
      </div>
    </div>
  );
}

function avg(points: ChartPoint[]) {
  if (!points.length) {
    return 0;
  }

  return points.reduce((sum, point) => sum + point.score, 0) / points.length;
}

export function PressureChart({
  title,
  subtitle,
  points,
  kind,
}: PressureChartProps) {
  const mounted = useSyncExternalStore(
    () => () => {},
    () => true,
    () => false,
  );
  const averageScore = avg(points);
  const chartPoints = points.map((point) => ({
    ...point,
    track: 100,
    activeScore: point.score,
  }));

  return (
    <section className="rounded-[30px] bg-[#232326] px-4 py-4 text-slate-100 shadow-[0_28px_90px_rgba(0,0,0,0.45)] sm:px-5">
      <div className="mb-3 flex items-end justify-between gap-4">
        <div>
          <p className="text-[10px] uppercase tracking-[0.32em] text-slate-500">{title}</p>
          <p className="mt-2 max-w-xl text-sm leading-6 text-slate-400">{subtitle}</p>
        </div>
        <div className="flex flex-wrap items-center justify-end gap-2 text-[10px] uppercase tracking-[0.22em] text-slate-500">
          <span className="inline-flex items-center gap-2 rounded-full border border-white/8 bg-white/[0.03] px-2.5 py-1.5">
            <span className="h-2 w-2 rounded-full bg-emerald-400" />
            Cheaper
          </span>
          <span className="inline-flex items-center gap-2 rounded-full border border-white/8 bg-white/[0.03] px-2.5 py-1.5">
            <span className="h-2 w-2 rounded-full bg-amber-400" />
            Normal
          </span>
          <span className="inline-flex items-center gap-2 rounded-full border border-white/8 bg-white/[0.03] px-2.5 py-1.5">
            <span className="h-2 w-2 rounded-full bg-rose-400" />
            Expensive
          </span>
        </div>
      </div>

      <div className={cn("rounded-[24px] bg-[#1f1f22] px-3 py-4", kind === "hourly" ? "mt-1" : "")}>
        <div className="h-[220px] sm:h-[240px]">
          {mounted ? (
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartPoints} margin={{ top: 4, right: 8, left: -12, bottom: 0 }} barGap={kind === "daily" ? 18 : 4}>
                <CartesianGrid stroke={colors.grid} vertical={true} strokeDasharray="3 5" />
                <XAxis
                  dataKey="label"
                  tickLine={false}
                  axisLine={false}
                  tick={{ fill: colors.axis, fontSize: kind === "daily" ? 14 : 12 }}
                  dy={10}
                  interval={kind === "daily" ? 0 : "preserveStartEnd"}
                  minTickGap={kind === "daily" ? 12 : 28}
                />
                <YAxis
                  orientation="right"
                  domain={[0, 100]}
                  ticks={kind === "daily" ? [0, 50, 100] : [0, 50, 100]}
                  tickFormatter={(value) => {
                    if (value === 100) {
                      return "100";
                    }
                    if (value === 0) {
                      return "0";
                    }
                    return "";
                  }}
                  tickLine={false}
                  axisLine={false}
                  tick={{ fill: colors.label, fontSize: 12 }}
                  width={42}
                />
                <ReferenceLine
                  y={averageScore}
                  stroke={colors.line}
                  strokeDasharray="4 6"
                  ifOverflow="extendDomain"
                  label={{
                    value: "avg",
                    position: "right",
                    fill: colors.label,
                    fontSize: 12,
                  }}
                />
                <Tooltip content={<PressureTooltip />} cursor={{ fill: "rgba(255,255,255,0.04)" }} />

                <Bar
                  dataKey="track"
                  radius={[6, 6, 0, 0]}
                  barSize={kind === "daily" ? 40 : 16}
                  isAnimationActive={false}
                >
                  {chartPoints.map((point) => (
                    <Cell key={`bg-${point.key}`} fill={colors.base} />
                  ))}
                </Bar>

                <Bar
                  dataKey="activeScore"
                  radius={[6, 6, 0, 0]}
                  barSize={kind === "daily" ? 40 : 16}
                  isAnimationActive={false}
                >
                  {chartPoints.map((point) => (
                    <Cell
                      key={`score-${point.key}`}
                      fill={fillForTone(point.tone)}
                    />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div className="h-full rounded-[18px] bg-white/[0.03]" />
          )}
        </div>
      </div>
    </section>
  );
}
