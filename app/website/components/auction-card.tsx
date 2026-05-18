"use client";

import { motion } from "framer-motion";
import { Copy, ExternalLink } from "lucide-react";
import { useMemo, useState } from "react";
import {
  useAccount,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";

import { Button } from "@/components/ui/button";
import { addresses, dutchAuctionAbi } from "@/lib/contracts";
import { explorerAddressLink, explorerTxLink, formatStt, shortenAddress } from "@/lib/format";
import { cn } from "@/lib/utils";
import type { Auction } from "@/store/marketplace";

function statusClass(statusKey: Auction["statusKey"]) {
  if (statusKey === "LIVE") return "text-foreground";
  if (statusKey === "SNAPPED") return "text-muted";
  return "text-dim";
}

export function AuctionCard({ auction }: { auction: Auction }) {
  const { isConnected } = useAccount();
  const { writeContractAsync, isPending } = useWriteContract();
  const [hash, setHash] = useState<`0x${string}` | undefined>();
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({
    hash,
  });

  const progress = useMemo(() => {
    const start = BigInt(auction.startPrice);
    const floor = BigInt(auction.floorPrice);
    const current = BigInt(auction.currentPrice);
    const span = start - floor;
    if (span <= 0n) return 100;
    const traversed = start - current;
    return Math.max(0, Math.min(100, Number((traversed * 10000n) / span) / 100));
  }, [auction.currentPrice, auction.floorPrice, auction.startPrice]);

  const snapDisabled =
    auction.statusKey !== "LIVE" || !isConnected || isPending || isConfirming;

  const handleSnap = async () => {
    try {
      const txHash = await writeContractAsync({
        address: addresses.dutchAuction as `0x${string}`,
        abi: dutchAuctionAbi,
        functionName: "snap",
        args: [BigInt(auction.id)],
        value: BigInt(auction.currentPrice),
        chainId: Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? 50312),
      });
      setHash(txHash);
    } catch (error) {
      console.error(error);
    }
  };

  return (
    <motion.article
      layout
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      className={cn(
        "flex h-full flex-col gap-5 rounded-[2rem] border border-border bg-background p-5 sm:p-6",
        auction.statusKey === "SNAPPED" && "border-white/15",
        auction.statusKey === "EXPIRED" && "opacity-65",
      )}
    >
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="font-mono text-lg font-semibold tracking-tight sm:text-xl">
            {auction.dataType}
          </p>
          <div className="mt-2 flex items-center gap-2 text-xs text-muted">
            <span>Provider {shortenAddress(auction.provider)}</span>
            <button
              type="button"
              onClick={() => navigator.clipboard.writeText(auction.provider)}
              className="rounded-full border border-border p-1 text-muted transition hover:text-foreground"
            >
              <Copy className="size-3" />
            </button>
            <a
              href={explorerAddressLink(auction.provider)}
              target="_blank"
              rel="noreferrer"
              className="rounded-full border border-border p-1 text-muted transition hover:text-foreground"
            >
              <ExternalLink className="size-3" />
            </a>
          </div>
        </div>
        <span className={cn("text-xs uppercase tracking-[0.28em]", statusClass(auction.statusKey))}>
          {auction.statusKey}
        </span>
      </div>

      <div className="rounded-[1.5rem] border border-border bg-surface p-5">
        <motion.div
          key={auction.currentPrice}
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          className="font-mono text-4xl font-semibold tracking-tight sm:text-5xl"
        >
          {formatStt(auction.currentPrice)}
          <span className="ml-2 text-sm text-muted sm:text-base">STT</span>
        </motion.div>
        <p className="mt-2 text-xs uppercase tracking-[0.22em] text-muted">
          current price
        </p>
      </div>

      <div className="grid gap-3 text-sm text-muted">
        <div className="flex items-center justify-between gap-4">
          <span>Started</span>
          <span className="font-mono text-foreground">
            {formatStt(auction.startPrice)} STT
          </span>
        </div>
        <div className="flex items-center justify-between gap-4">
          <span>Floor</span>
          <span className="font-mono text-foreground">
            {formatStt(auction.floorPrice)} STT
          </span>
        </div>
      </div>

      <div className="space-y-2">
        <div className="h-2 rounded-full bg-surface">
          <motion.div
            animate={{ width: `${progress}%` }}
            transition={{ duration: 0.35, ease: "easeOut" }}
            className="h-full rounded-full bg-white"
          />
        </div>
        <div className="text-xs uppercase tracking-[0.22em] text-muted">
          {progress.toFixed(0)}% toward floor
        </div>
      </div>

      <div className="mt-auto space-y-3">
        {auction.statusKey === "SNAPPED" && auction.winner !== "0x0000000000000000000000000000000000000000" ? (
          <p className="text-xs text-muted">
            Winner {shortenAddress(auction.winner)}
          </p>
        ) : null}
        <Button
          className="w-full"
          variant={auction.statusKey === "LIVE" ? "default" : "outline"}
          onClick={handleSnap}
          disabled={snapDisabled}
        >
          {!isConnected
            ? "Connect wallet to snap"
            : isPending || isConfirming
              ? "Submitting..."
              : auction.statusKey === "LIVE"
                ? `Snap Now — ${formatStt(auction.currentPrice)} STT`
                : auction.statusKey}
        </Button>
        {hash ? (
          <a
            href={explorerTxLink(hash)}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-2 text-xs text-muted transition hover:text-foreground"
          >
            View transaction
            <ExternalLink className="size-3" />
          </a>
        ) : null}
      </div>
    </motion.article>
  );
}
