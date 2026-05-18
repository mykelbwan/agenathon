"use client";

import { useAuctions } from "@/hooks/use-auctions";
import { useMarketplaceEvents } from "@/hooks/use-marketplace-events";
import { useMarketplaceStats } from "@/hooks/use-marketplace-stats";

export function MarketplaceRuntime() {
  useAuctions();
  useMarketplaceEvents();
  useMarketplaceStats();

  return null;
}
