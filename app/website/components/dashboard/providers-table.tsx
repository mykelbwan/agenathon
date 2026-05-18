"use client";

import { Copy, ExternalLink } from "lucide-react";
import { useMemo } from "react";

import { explorerAddressLink, formatStt, shortenAddress } from "@/lib/format";
import type { Auction, FeedEvent } from "@/store/marketplace";

interface ProviderRow {
  provider: string;
  auctions: number;
  delivered: number;
  timeouts: number;
  reputation: string;
  avgPriceWei: bigint;
}

function buildRows(auctions: Auction[], feed: FeedEvent[]): ProviderRow[] {
  const deliveredByAuction = new Set(
    feed
      .filter((event) => event.kind === "data-delivered" && event.auctionId)
      .map((event) => event.auctionId as string),
  );

  const rows = new Map<string, ProviderRow>();

  for (const auction of auctions) {
    const provider = auction.provider.toLowerCase();
    const row =
      rows.get(provider) ??
      {
        provider: auction.provider,
        auctions: 0,
        delivered: 0,
        timeouts: 0,
        reputation: "—",
        avgPriceWei: 0n,
      };

    row.auctions += 1;
    row.avgPriceWei += BigInt(auction.currentPrice);
    if (deliveredByAuction.has(auction.id)) row.delivered += 1;
    if (auction.statusKey === "EXPIRED") row.timeouts += 1;
    rows.set(provider, row);
  }

  return [...rows.values()]
    .map((row) => {
      const average =
        row.auctions > 0 ? row.avgPriceWei / BigInt(row.auctions) : 0n;
      const score =
        row.auctions === 0
          ? "—"
          : (5 - (row.timeouts / row.auctions) * 1.5).toFixed(1);

      return {
        ...row,
        avgPriceWei: average,
        reputation: score,
      };
    })
    .sort((left, right) => right.auctions - left.auctions);
}

export function ProvidersTable({
  auctions,
  feed,
}: {
  auctions: Auction[];
  feed: FeedEvent[];
}) {
  const rows = useMemo(() => buildRows(auctions, feed), [auctions, feed]);

  return (
    <div className="rounded-[2rem] border border-border bg-surface p-5">
      <div className="mb-6">
        <p className="text-xs uppercase tracking-[0.24em] text-muted">
          Top Providers
        </p>
        <h3 className="mt-3 text-xl font-semibold tracking-tight">
          Delivery performance by wallet
        </h3>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full text-left text-sm">
          <thead className="text-xs uppercase tracking-[0.22em] text-muted">
            <tr>
              <th className="pb-4 font-medium">Provider</th>
              <th className="pb-4 font-medium">Auctions</th>
              <th className="pb-4 font-medium">Delivered</th>
              <th className="pb-4 font-medium">Timeouts</th>
              <th className="pb-4 font-medium">Reputation</th>
              <th className="pb-4 font-medium">Avg Price</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.provider} className="border-t border-border">
                <td className="py-4">
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-foreground">
                      {shortenAddress(row.provider)}
                    </span>
                    <button
                      type="button"
                      onClick={() => navigator.clipboard.writeText(row.provider)}
                      className="rounded-full border border-border p-1 text-muted transition hover:text-foreground"
                    >
                      <Copy className="size-3" />
                    </button>
                    <a
                      href={explorerAddressLink(row.provider)}
                      target="_blank"
                      rel="noreferrer"
                      className="rounded-full border border-border p-1 text-muted transition hover:text-foreground"
                    >
                      <ExternalLink className="size-3" />
                    </a>
                  </div>
                </td>
                <td className="py-4 font-mono text-foreground">{row.auctions}</td>
                <td className="py-4 font-mono text-foreground">{row.delivered}</td>
                <td className="py-4 font-mono text-foreground">{row.timeouts}</td>
                <td className="py-4 font-mono text-foreground">{row.reputation}</td>
                <td className="py-4 font-mono text-foreground">
                  {formatStt(row.avgPriceWei)} STT
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {rows.length === 0 ? (
        <p className="mt-4 text-sm text-muted">
          Provider rankings appear after the first auction is listed.
        </p>
      ) : null}
    </div>
  );
}
