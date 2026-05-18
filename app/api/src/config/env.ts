import "dotenv/config";

export interface AppEnv {
    port: number;
    rpcUrl: string;
    privateKey: string;
    dutchAuctionAddress: string;
    dataProviderAddress: string;
    auctionClockGasLimit: bigint;
    consumerHandlerGasLimit: bigint;
    consumerSubscriptionReserveWei: bigint;
    webUrl: string;
}

function requireEnv(name: string): string {
    const value = process.env[name];
    if (!value) {
        throw new Error(`Missing required environment variable: ${name}`);
    }
    return value;
}

export function loadEnv(): AppEnv {
    return {
        port: Number(process.env.PORT ?? "3000"),
        rpcUrl: requireEnv("RPC_URL"),
        privateKey: requireEnv("PRIVATE_KEY"),
        dutchAuctionAddress: requireEnv("DUTCH_AUCTION_ADDRESS"),
        dataProviderAddress: requireEnv("DATA_PROVIDER_ADDRESS"),
        auctionClockGasLimit: BigInt("5000000"),
        consumerHandlerGasLimit: BigInt("5000000"),
        consumerSubscriptionReserveWei: BigInt("32000000000000000000"),
        webUrl: requireEnv("WEB_URL"),
    };
}
