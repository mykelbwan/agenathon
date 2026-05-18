"use client";

import { useQuery } from "@tanstack/react-query";
import { useEffect } from "react";

import { api } from "@/lib/api";
import { useMarketplaceStore } from "@/store/marketplace";

export function useAuctions() {
  const setAuctions = useMarketplaceStore((state) => state.setAuctions);

  const query = useQuery({
    queryKey: ["auctions"],
    queryFn: async () => {
      const response = await api.auctions();
      return response.auctions;
    },
    refetchInterval: 20_000,
  });

  useEffect(() => {
    if (query.data) {
      setAuctions(query.data);
    }
  }, [query.data, setAuctions]);

  return query;
}
