"use client";

import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import { formatRelativeTime } from "@/lib/format";
import type { FeedEvent } from "@/store/marketplace";

function toChartData(feed: FeedEvent[]) {
  const snapped = feed
    .filter((event) => event.kind === "auction-snapped")
    .sort((left, right) => left.timestamp - right.timestamp);

  let total = 0;
  return snapped.map((event) => {
    const match = event.description.match(/snapped at ([\d.]+) STT/i);
    const amount = match ? Number(match[1]) : 0;
    total += amount;
    return {
      time: new Date(event.timestamp).toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
      }),
      volume: Number(total.toFixed(4)),
      label: formatRelativeTime(event.timestamp),
    };
  });
}

export function VolumeChart({ feed }: { feed: FeedEvent[] }) {
  const data = toChartData(feed);

  return (
    <div className="rounded-[2rem] border border-border bg-surface p-5">
      <div className="mb-6">
        <p className="text-xs uppercase tracking-[0.24em] text-muted">
          STT Volume Over Time
        </p>
        <h3 className="mt-3 text-xl font-semibold tracking-tight">
          Settled auction volume
        </h3>
      </div>
      <div className="h-[320px] w-full">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={data}>
            <CartesianGrid stroke="rgba(255,255,255,0.08)" vertical={false} />
            <XAxis
              dataKey="time"
              tickLine={false}
              axisLine={false}
              tick={{ fill: "#666666", fontSize: 12 }}
            />
            <YAxis
              tickLine={false}
              axisLine={false}
              tick={{ fill: "#666666", fontSize: 12 }}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: "#0a0a0a",
                border: "1px solid #1a1a1a",
                borderRadius: "16px",
                color: "#ffffff",
              }}
              labelStyle={{ color: "#666666" }}
              formatter={(value) => [
                `${Number(value ?? 0).toFixed(4)} STT`,
                "Volume",
              ]}
            />
            <Area
              type="monotone"
              dataKey="volume"
              stroke="#ffffff"
              strokeWidth={2}
              fill="rgba(255,255,255,0.02)"
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
      {data.length === 0 ? (
        <p className="mt-4 text-sm text-muted">
          No snapped auctions yet. Volume appears after the first settlement.
        </p>
      ) : null}
    </div>
  );
}
