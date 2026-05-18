"use client";

import { useEffect, useMemo } from "react";
import { createPublicClient, fallback, http, webSocket } from "viem";

import { addresses, dataProviderAbi, dutchAuctionAbi, escrowAbi } from "@/lib/contracts";
import { formatScalarValue, formatStt } from "@/lib/format";
import { somniaTestnet } from "@/lib/chain";
import { useMarketplaceStore } from "@/store/marketplace";

export function useMarketplaceEvents() {
  const updateAuctionPrice = useMarketplaceStore(
    (state) => state.updateAuctionPrice,
  );
  const markAuctionSnapped = useMarketplaceStore(
    (state) => state.markAuctionSnapped,
  );
  const markAuctionExpired = useMarketplaceStore(
    (state) => state.markAuctionExpired,
  );
  const addFeedEvent = useMarketplaceStore((state) => state.addFeedEvent);

  const client = useMemo(
    () =>
      createPublicClient({
        chain: somniaTestnet,
        transport: fallback([
          webSocket(
            process.env.NEXT_PUBLIC_WS_URL ?? "wss://dream-rpc.somnia.network",
          ),
          http(somniaTestnet.rpcUrls.default.http[0]),
        ]),
      }),
    [],
  );

  useEffect(() => {
    const unwatchStarted = client.watchContractEvent({
      address: addresses.dutchAuction as `0x${string}`,
      abi: dutchAuctionAbi,
      eventName: "AuctionStarted",
      pollingInterval: 2_000,
      onLogs: (logs) => {
        for (const log of logs) {
          if (!log.args.auctionId || !log.args.provider) continue;
          addFeedEvent({
            id: `${log.transactionHash}-started-${log.logIndex}`,
            kind: "auction-started",
            title: "AuctionStarted",
            description: `${log.args.dataType} auction #${log.args.auctionId.toString()} started at ${formatStt(log.args.startPrice ?? 0n)} STT`,
            timestamp: Date.now(),
            txHash: log.transactionHash,
            auctionId: log.args.auctionId.toString(),
            actorAddress: log.args.provider,
            actorLabel: "Provider",
          });
        }
      },
    });

    const unwatchTick = client.watchContractEvent({
      address: addresses.dutchAuction as `0x${string}`,
      abi: dutchAuctionAbi,
      eventName: "PriceTick",
      pollingInterval: 2_000,
      onLogs: (logs) => {
        for (const log of logs) {
          if (!log.args.auctionId || !log.args.newPrice) continue;
          const auctionId = Number(log.args.auctionId);
          updateAuctionPrice(auctionId, log.args.newPrice);
          addFeedEvent({
            id: `${log.transactionHash}-tick-${log.logIndex}`,
            kind: "price-tick",
            title: "PriceTick",
            description: `Auction #${auctionId} dropped to ${formatStt(log.args.newPrice)} STT`,
            timestamp: Date.now(),
            txHash: log.transactionHash,
            auctionId: log.args.auctionId.toString(),
          });
        }
      },
    });

    const unwatchSnapped = client.watchContractEvent({
      address: addresses.dutchAuction as `0x${string}`,
      abi: dutchAuctionAbi,
      eventName: "AuctionSnapped",
      pollingInterval: 2_000,
      onLogs: (logs) => {
        for (const log of logs) {
          if (!log.args.auctionId || !log.args.winner || !log.args.finalPrice)
            continue;
          markAuctionSnapped(
            Number(log.args.auctionId),
            log.args.winner,
            log.args.finalPrice,
          );
          addFeedEvent({
            id: `${log.transactionHash}-snapped-${log.logIndex}`,
            kind: "auction-snapped",
            title: "AuctionSnapped",
            description: `Auction #${log.args.auctionId.toString()} snapped at ${formatStt(log.args.finalPrice)} STT`,
            timestamp: Date.now(),
            txHash: log.transactionHash,
            auctionId: log.args.auctionId.toString(),
            actorAddress: log.args.winner,
            actorLabel: "Buyer",
          });
        }
      },
    });

    const unwatchExpired = client.watchContractEvent({
      address: addresses.dutchAuction as `0x${string}`,
      abi: dutchAuctionAbi,
      eventName: "AuctionExpired",
      pollingInterval: 2_000,
      onLogs: (logs) => {
        for (const log of logs) {
          if (!log.args.auctionId) continue;
          markAuctionExpired(Number(log.args.auctionId));
          addFeedEvent({
            id: `${log.transactionHash}-expired-${log.logIndex}`,
            kind: "auction-expired",
            title: "AuctionExpired",
            description: `Auction #${log.args.auctionId.toString()} expired without a buyer`,
            timestamp: Date.now(),
            txHash: log.transactionHash,
            auctionId: log.args.auctionId.toString(),
          });
        }
      },
    });

    const unwatchDelivered = client.watchContractEvent({
      address: addresses.dataProvider as `0x${string}`,
      abi: dataProviderAbi,
      eventName: "DataDelivered",
      pollingInterval: 2_000,
      onLogs: (logs) => {
        for (const log of logs) {
          if (!log.args.auctionId || !log.args.consumer || !log.args.price)
            continue;
          const knownAuction = useMarketplaceStore
            .getState()
            .auctions.find(
              (auction) => auction.id === log.args.auctionId?.toString(),
            );
          const formattedValue = knownAuction
            ? formatScalarValue(log.args.price, knownAuction.decimals)
            : log.args.price.toString();
          addFeedEvent({
            id: `${log.transactionHash}-delivered-${log.logIndex}`,
            kind: "data-delivered",
            title: "DataDelivered",
            description: `Auction #${log.args.auctionId.toString()} delivered verified ${knownAuction?.dataType ?? "market"} value ${formattedValue}`,
            timestamp: Date.now(),
            txHash: log.transactionHash,
            auctionId: log.args.auctionId.toString(),
            actorAddress: log.args.consumer,
            actorLabel: "Consumer",
          });
        }
      },
    });

    const unwatchRefunded = client.watchContractEvent({
      address: addresses.escrow as `0x${string}`,
      abi: escrowAbi,
      eventName: "PaymentRefunded",
      pollingInterval: 2_000,
      onLogs: (logs) => {
        for (const log of logs) {
          if (!log.args.auctionId || !log.args.buyer || !log.args.amount)
            continue;
          addFeedEvent({
            id: `${log.transactionHash}-refunded-${log.logIndex}`,
            kind: "payment-refunded",
            title: "PaymentRefunded",
            description: `Auction #${log.args.auctionId.toString()} refunded ${formatStt(log.args.amount)} STT`,
            timestamp: Date.now(),
            txHash: log.transactionHash,
            auctionId: log.args.auctionId.toString(),
            actorAddress: log.args.buyer,
            actorLabel: "Buyer",
          });
        }
      },
    });

    return () => {
      unwatchStarted();
      unwatchTick();
      unwatchSnapped();
      unwatchExpired();
      unwatchDelivered();
      unwatchRefunded();
    };
  }, [
    addFeedEvent,
    client,
    markAuctionExpired,
    markAuctionSnapped,
    updateAuctionPrice,
  ]);
}
