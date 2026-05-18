"use client";

import { RefreshCcw } from "lucide-react";
import { useMemo, useState } from "react";

import { AuctionGrid } from "@/components/auction-grid";
import { StartAuctionModal } from "@/components/start-auction-modal";
import { Button } from "@/components/ui/button";
import { useAuctions } from "@/hooks/use-auctions";
import { useMarketplaceStore } from "@/store/marketplace";

type FilterKey = "ALL" | "LIVE" | "SNAPPED" | "EXPIRED";

const filters: FilterKey[] = ["ALL", "LIVE", "SNAPPED", "EXPIRED"];

export default function Home() {
  const { isLoading, isRefetching, refetch, error } = useAuctions();
  const auctions = useMarketplaceStore((state) => state.auctions);
  const [activeFilter, setActiveFilter] = useState<FilterKey>("ALL");

  const filteredAuctions = useMemo(() => {
    if (activeFilter === "ALL") return auctions;
    return auctions.filter((auction) => auction.statusKey === activeFilter);
  }, [activeFilter, auctions]);

  return (
    <section className="flex flex-1 flex-col gap-6">
      <div className="rounded-[2rem] border border-border bg-surface p-5 sm:p-6">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div className="space-y-3">
            <p className="text-xs uppercase tracking-[0.32em] text-muted">
              AgentMarket
            </p>
            <h1 className="max-w-4xl text-3xl font-semibold tracking-tight sm:text-4xl lg:text-5xl">
              Autonomous Dutch auctions for live on-chain data delivery.
            </h1>
            <p className="max-w-2xl text-sm leading-6 text-muted sm:text-base">
              Providers list live feeds. Consumer agents watch price ticks,
              snap autonomously, and receive verified results on-chain through
              Somnia agents.
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <Button
              variant="outline"
              onClick={() => refetch()}
              disabled={isRefetching}
            >
              <RefreshCcw
                className={isRefetching ? "size-4 animate-spin" : "size-4"}
              />
              Refresh
            </Button>
            <StartAuctionModal />
          </div>
        </div>
      </div>

      <div className="flex flex-col gap-4 rounded-[2rem] border border-border bg-surface p-4 sm:p-5">
        <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div className="flex flex-wrap gap-2">
            {filters.map((filter) => {
              const active = activeFilter === filter;
              return (
                <button
                  key={filter}
                  type="button"
                  onClick={() => setActiveFilter(filter)}
                  className={
                    active
                      ? "rounded-full border border-white/15 bg-white px-4 py-2 text-sm font-medium text-black"
                      : "rounded-full border border-border bg-background px-4 py-2 text-sm text-muted transition hover:text-foreground"
                  }
                >
                  {filter}
                </button>
              );
            })}
          </div>
          <div className="text-xs uppercase tracking-[0.22em] text-muted">
            {isLoading ? "Loading auctions" : `${filteredAuctions.length} visible`}
          </div>
        </div>

        {error ? (
          <div className="rounded-3xl border border-border bg-background px-4 py-6 text-sm text-muted">
            Failed to load auctions: {error.message}
          </div>
        ) : null}

        <AuctionGrid
          auctions={filteredAuctions}
          isLoading={isLoading}
          emptyMessage="No active auctions. Providers can start one below."
        />
      </div>
    </section>
  );
}
