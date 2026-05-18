"use client";

import { useMutation } from "@tanstack/react-query";

import { api } from "@/lib/api";

interface SpawnPayload {
  auctionId: string;
  budgetWei: string;
  urgency: "low" | "medium" | "high";
  targetDataType: string;
}

export function useSpawnAgent() {
  return useMutation({
    mutationFn: async (payload: SpawnPayload) => {
      return api.spawnConsumer(payload);
    },
  });
}
