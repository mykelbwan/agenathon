import { motion } from "framer-motion";

import { AuctionCard } from "@/components/auction-card";
import type { Auction } from "@/store/marketplace";

export function AuctionGrid({
  auctions,
  isLoading,
  emptyMessage,
}: {
  auctions: Auction[];
  isLoading: boolean;
  emptyMessage: string;
}) {
  if (isLoading && auctions.length === 0) {
    return (
      <div className="grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
        {Array.from({ length: 3 }).map((_, index) => (
          <div
            key={index}
            className="h-[420px] animate-pulse rounded-[2rem] border border-border bg-background"
          />
        ))}
      </div>
    );
  }

  if (auctions.length === 0) {
    return (
      <div className="rounded-[2rem] border border-dashed border-border bg-background px-4 py-16 text-center text-sm text-muted">
        {emptyMessage}
      </div>
    );
  }

  return (
    <motion.div layout className="grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
      {auctions.map((auction) => (
        <AuctionCard key={auction.id} auction={auction} />
      ))}
    </motion.div>
  );
}
