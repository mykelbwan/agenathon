export interface ApiAuction {
  id: string;
  provider: string;
  dataType: string;
  apiUrl: string;
  jsonSelector: string;
  decimals: number;
  startPrice: string;
  floorPrice: string;
  currentPrice: string;
  priceStep: string;
  startBlock: string;
  timeoutBlocks: string;
  status: number;
  statusLabel: "Active" | "Snapped" | "Expired";
  winner: string;
  escrowRef: string;
}

export interface HealthResponse {
  ok: boolean;
  blockNumber: number;
  walletAddress: string;
  dutchAuctionAddress: string;
  dataProviderAddress: string;
}

const apiUrl =
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3000";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${apiUrl}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
    cache: "no-store",
  });

  if (!response.ok) {
    let message = `Request failed: ${response.status}`;
    try {
      const payload = (await response.json()) as { error?: string };
      if (payload.error) message = payload.error;
    } catch {}
    throw new Error(message);
  }

  return response.json() as Promise<T>;
}

export const api = {
  health: () => request<HealthResponse>("/health"),
  auctions: () => request<{ auctions: ApiAuction[] }>("/auctions"),
  auction: (id: string | number) =>
    request<{ auction: ApiAuction }>(`/auctions/${id}`),
  createAuction: <TPayload extends object>(payload: TPayload) =>
    request<{
      auctionId: string;
      transactionHash: string;
      blockNumber: number;
    }>("/provider/auction", {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  spawnConsumer: <TPayload extends object>(payload: TPayload) =>
    request<{
      consumerHandlerAddress: string;
      snapThresholdWei: string;
      budgetWei: string;
      rationale: string;
      transactionHash: string;
      blockNumber: number;
    }>("/consumer/spawn", {
      method: "POST",
      body: JSON.stringify(payload),
    }),
};
