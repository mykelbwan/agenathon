import {
    Contract,
    ContractFactory,
    JsonRpcProvider,
    type ContractTransactionResponse,
    Wallet,
} from "ethers";

import { loadEnv, type AppEnv } from "../config/env";
import { consumerHandlerArtifact, dutchAuctionArtifact } from "./artifacts";

export interface BlockchainContext {
    env: AppEnv;
    provider: JsonRpcProvider;
    wallet: Wallet;
    dutchAuction: Contract & {
        auctionCount(): Promise<bigint>;
        getAuction(auctionId: bigint): Promise<{
            id: bigint;
            provider: string;
            dataType: string;
            apiUrl: string;
            jsonSelector: string;
            decimals: bigint;
            startPrice: bigint;
            floorPrice: bigint;
            currentPrice: bigint;
            priceStep: bigint;
            startBlock: bigint;
            timeoutBlocks: bigint;
            status: bigint;
            winner: string;
            escrowRef: bigint;
        }>;
        startAuction(
            dataType: string,
            apiUrl: string,
            jsonSelector: string,
            decimals: number,
            startPrice: bigint,
            floorPrice: bigint,
            priceStep: bigint,
            timeoutBlocks: bigint,
        ): Promise<ContractTransactionResponse>;
    };
    consumerHandlerFactory: ContractFactory;
}

export function createBlockchainContext(): BlockchainContext {
    const env = loadEnv();
    const provider = new JsonRpcProvider(env.rpcUrl);
    const wallet = new Wallet(env.privateKey, provider);

    const dutchAuction = new Contract(
        env.dutchAuctionAddress,
        dutchAuctionArtifact.abi,
        wallet,
    ) as BlockchainContext["dutchAuction"];

    const bytecode = consumerHandlerArtifact.bytecode?.object;
    if (!bytecode) {
        throw new Error("ConsumerHandler artifact is missing bytecode");
    }

    const consumerHandlerFactory = new ContractFactory(
        consumerHandlerArtifact.abi,
        bytecode,
        wallet,
    );

    return {
        env,
        provider,
        wallet,
        dutchAuction,
        consumerHandlerFactory,
    };
}
