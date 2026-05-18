import { defineChain } from "viem";

export const somniaTestnet = defineChain({
  id: Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? 50312),
  name: "Somnia Testnet",
  nativeCurrency: {
    name: "Somnia Token",
    symbol: "STT",
    decimals: 18,
  },
  rpcUrls: {
    default: {
      http: ["https://dream-rpc.somnia.network"],
      webSocket: ["wss://dream-rpc.somnia.network"],
    },
  },
  blockExplorers: {
    default: {
      name: "Somnia Explorer",
      url:
        process.env.NEXT_PUBLIC_EXPLORER_URL ??
        "https://shannon-explorer.somnia.network",
    },
  },
});
