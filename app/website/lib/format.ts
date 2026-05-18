import { formatEther, formatUnits } from "viem";

export function shortenAddress(address: string) {
  if (address.length < 10) return address;
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function formatStt(value: bigint | string) {
  const normalized = typeof value === "string" ? BigInt(value) : value;
  return Number(formatEther(normalized)).toFixed(4);
}

export function formatScalarValue(
  value: bigint | string,
  decimals: number,
  precision = 4,
) {
  const normalized = typeof value === "string" ? BigInt(value) : value;
  return Number(formatUnits(normalized, decimals)).toFixed(precision);
}

export function formatRelativeTime(timestamp: number) {
  const diffSeconds = Math.max(
    0,
    Math.floor((Date.now() - timestamp) / 1000),
  );

  if (diffSeconds < 60) return `${diffSeconds}s ago`;
  const diffMinutes = Math.floor(diffSeconds / 60);
  if (diffMinutes < 60) return `${diffMinutes}m ago`;
  const diffHours = Math.floor(diffMinutes / 60);
  if (diffHours < 24) return `${diffHours}h ago`;
  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays}d ago`;
}

export function explorerTxLink(hash: string) {
  const base =
    process.env.NEXT_PUBLIC_EXPLORER_URL ??
    "https://shannon-explorer.somnia.network";
  return `${base}/tx/${hash}`;
}

export function explorerAddressLink(address: string) {
  const base =
    process.env.NEXT_PUBLIC_EXPLORER_URL ??
    "https://shannon-explorer.somnia.network";
  return `${base}/address/${address}`;
}
