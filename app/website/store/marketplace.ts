"use client";

import { create } from "zustand";

import type { ApiAuction } from "@/lib/api";

export type AuctionStatus = "LIVE" | "SNAPPED" | "EXPIRED";

export interface Auction extends ApiAuction {
  statusKey: AuctionStatus;
  lastUpdatedAt?: number;
}

export interface FeedEvent {
  id: string;
  kind:
    | "auction-started"
    | "price-tick"
    | "auction-snapped"
    | "auction-expired"
    | "data-delivered"
    | "payment-refunded";
  title: string;
  description: string;
  timestamp: number;
  txHash?: string;
  auctionId?: string;
  actorAddress?: string;
  actorLabel?: string;
}

export interface MarketplaceStats {
  totalAuctions: number;
  totalVolumeWei: bigint;
  activeAgents: number;
  avgDeliverySeconds: number;
}

interface MarketplaceStore {
  auctions: Auction[];
  feed: FeedEvent[];
  stats: MarketplaceStats;
  setAuctions: (auctions: ApiAuction[]) => void;
  updateAuctionPrice: (auctionId: number, newPrice: bigint) => void;
  markAuctionSnapped: (
    auctionId: number,
    winner: string,
    price: bigint,
  ) => void;
  markAuctionExpired: (auctionId: number) => void;
  addAuction: (auction: ApiAuction) => void;
  addFeedEvent: (event: FeedEvent) => void;
  setStats: (stats: MarketplaceStats) => void;
}

function toStatusKey(statusLabel: ApiAuction["statusLabel"]): AuctionStatus {
  if (statusLabel === "Snapped") return "SNAPPED";
  if (statusLabel === "Expired") return "EXPIRED";
  return "LIVE";
}

function withDerivedStatus(auction: ApiAuction): Auction {
  return {
    ...auction,
    statusKey: toStatusKey(auction.statusLabel),
  };
}

export const useMarketplaceStore = create<MarketplaceStore>((set) => ({
  auctions: [],
  feed: [],
  stats: {
    totalAuctions: 0,
    totalVolumeWei: BigInt(0),
    activeAgents: 0,
    avgDeliverySeconds: 0,
  },
  setAuctions: (auctions) =>
    set(() => ({
      auctions: auctions.map(withDerivedStatus),
    })),
  updateAuctionPrice: (auctionId, newPrice) =>
    set((state) => ({
      auctions: state.auctions.map((auction) =>
        Number(auction.id) === auctionId
          ? {
              ...auction,
              currentPrice: newPrice.toString(),
              lastUpdatedAt: Date.now(),
            }
          : auction,
      ),
    })),
  markAuctionSnapped: (auctionId, winner, price) =>
    set((state) => ({
      auctions: state.auctions.map((auction) =>
        Number(auction.id) === auctionId
          ? {
              ...auction,
              winner,
              currentPrice: price.toString(),
              statusLabel: "Snapped",
              statusKey: "SNAPPED",
              lastUpdatedAt: Date.now(),
            }
          : auction,
      ),
    })),
  markAuctionExpired: (auctionId) =>
    set((state) => ({
      auctions: state.auctions.map((auction) =>
        Number(auction.id) === auctionId
          ? {
              ...auction,
              statusLabel: "Expired",
              statusKey: "EXPIRED",
              lastUpdatedAt: Date.now(),
            }
          : auction,
      ),
    })),
  addAuction: (auction) =>
    set((state) => ({
      auctions: [withDerivedStatus(auction), ...state.auctions],
    })),
  addFeedEvent: (event) =>
    set((state) => ({
      feed: [event, ...state.feed].slice(0, 200),
    })),
  setStats: (stats) => set(() => ({ stats })),
}));
