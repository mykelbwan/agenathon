"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";

import { Button } from "@/components/ui/button";
import { api } from "@/lib/api";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

const defaults = {
  "ETH/USD": {
    apiUrl:
      "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd",
    jsonSelector: "ethereum.usd",
  },
  "BTC/USD": {
    apiUrl:
      "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd",
    jsonSelector: "bitcoin.usd",
  },
  "SOL/USD": {
    apiUrl:
      "https://api.coingecko.com/api/v3/simple/price?ids=solana&vs_currencies=usd",
    jsonSelector: "solana.usd",
  },
} as const;

type DataType = keyof typeof defaults;
interface CreateAuctionPayload {
  dataType: DataType;
  apiUrl: string;
  jsonSelector: string;
  decimals: number;
  startPrice: string;
  floorPrice: string;
  priceStep: string;
  timeoutBlocks: string;
}

export function StartAuctionModal() {
  const [open, setOpen] = useState(false);
  const [dataType, setDataType] = useState<DataType>("ETH/USD");
  const [apiUrl, setApiUrl] = useState<string>(defaults["ETH/USD"].apiUrl);
  const [jsonSelector, setJsonSelector] = useState<string>(
    defaults["ETH/USD"].jsonSelector,
  );
  const [startPrice, setStartPrice] = useState("10");
  const [floorPrice, setFloorPrice] = useState("1");
  const [priceStep, setPriceStep] = useState("0.5");
  const [duration, setDuration] = useState("120");
  const queryClient = useQueryClient();
  const createAuction = useMutation({
    mutationFn: (payload: CreateAuctionPayload) => api.createAuction(payload),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["auctions"] });
      await queryClient.invalidateQueries({ queryKey: ["health"] });
      setOpen(false);
    },
  });

  const pending = createAuction.isPending;
  const helperText = pending
    ? "Submitting through the marketplace API wallet."
    : "This calls the Express API, which creates the auction on-chain from the configured marketplace wallet.";

  const handleDataType = (nextType: DataType) => {
    setDataType(nextType);
    setApiUrl(defaults[nextType].apiUrl);
    setJsonSelector(defaults[nextType].jsonSelector);
  };

  const handleSubmit = async () => {
    const { parseEther } = await import("viem");
    try {
      await createAuction.mutateAsync({
        dataType,
        apiUrl,
        jsonSelector,
        decimals: 8,
        startPrice: parseEther(startPrice).toString(),
        floorPrice: parseEther(floorPrice).toString(),
        priceStep: parseEther(priceStep).toString(),
        timeoutBlocks: duration,
      });
    } catch (error) {
      console.error(error);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button>Start Auction</Button>
      </DialogTrigger>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Start Auction</DialogTitle>
          <DialogDescription>{helperText}</DialogDescription>
        </DialogHeader>
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="grid gap-2 sm:col-span-2">
            <span className="text-sm text-muted">Data Type</span>
            <div className="grid grid-cols-3 gap-2">
              {(Object.keys(defaults) as DataType[]).map((option) => (
                <button
                  key={option}
                  type="button"
                  onClick={() => handleDataType(option)}
                  className={
                    dataType === option
                      ? "rounded-2xl border border-white/15 bg-white px-4 py-3 text-sm font-medium text-black"
                      : "rounded-2xl border border-border bg-background px-4 py-3 text-sm text-foreground"
                  }
                >
                  {option}
                </button>
              ))}
            </div>
          </label>

          <label className="grid gap-2 sm:col-span-2">
            <span className="text-sm text-muted">API URL</span>
            <input
              value={apiUrl}
              onChange={(event) => setApiUrl(event.target.value)}
              className="h-12 rounded-2xl border border-border bg-background px-4 text-sm outline-none"
            />
          </label>

          <label className="grid gap-2 sm:col-span-2">
            <span className="text-sm text-muted">JSON Selector</span>
            <input
              value={jsonSelector}
              onChange={(event) => setJsonSelector(event.target.value)}
              className="h-12 rounded-2xl border border-border bg-background px-4 text-sm outline-none"
            />
          </label>

          <label className="grid gap-2">
            <span className="text-sm text-muted">Start Price (STT)</span>
            <input
              value={startPrice}
              onChange={(event) => setStartPrice(event.target.value)}
              className="h-12 rounded-2xl border border-border bg-background px-4 text-sm outline-none"
            />
          </label>

          <label className="grid gap-2">
            <span className="text-sm text-muted">Floor Price (STT)</span>
            <input
              value={floorPrice}
              onChange={(event) => setFloorPrice(event.target.value)}
              className="h-12 rounded-2xl border border-border bg-background px-4 text-sm outline-none"
            />
          </label>

          <label className="grid gap-2">
            <span className="text-sm text-muted">Price Step (STT per tick)</span>
            <input
              value={priceStep}
              onChange={(event) => setPriceStep(event.target.value)}
              className="h-12 rounded-2xl border border-border bg-background px-4 text-sm outline-none"
            />
          </label>

          <label className="grid gap-2">
            <span className="text-sm text-muted">Duration (blocks)</span>
            <input
              value={duration}
              onChange={(event) => setDuration(event.target.value)}
              className="h-12 rounded-2xl border border-border bg-background px-4 text-sm outline-none"
            />
          </label>
        </div>

        <div className="flex flex-col gap-3 sm:flex-row sm:justify-end">
          <Button variant="outline" onClick={() => setOpen(false)}>
            Cancel
          </Button>
          <Button onClick={handleSubmit} disabled={pending}>
            {pending ? "Starting..." : "Start Auction"}
          </Button>
        </div>
        {createAuction.error ? (
          <div className="rounded-2xl border border-border bg-background px-4 py-3 text-sm text-muted">
            {createAuction.error.message}
          </div>
        ) : null}
      </DialogContent>
    </Dialog>
  );
}
