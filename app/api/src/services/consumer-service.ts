import type { ContractTransactionReceipt, Log } from "ethers";
import { Interface } from "ethers";

import type { BlockchainContext } from "../lib/blockchain";
import { HttpError } from "../lib/http";
import { consumerHandlerArtifact } from "../lib/artifacts";
import { AuctionService, type AuctionView } from "./auction-service";

export type ConsumerUrgency = "low" | "medium" | "high";

export interface SpawnConsumerInput {
  auctionId: bigint;
  budgetWei: bigint;
  urgency: ConsumerUrgency;
  targetDataType?: string;
}

function min(a: bigint, b: bigint): bigint {
  return a < b ? a : b;
}

function urgencyToBps(urgency: ConsumerUrgency): bigint {
  switch (urgency) {
    case "low":
      return 0n;
    case "medium":
      return 5000n;
    case "high":
      return 10000n;
  }
}

export class ConsumerService {
  private readonly consumerInterface: Interface;

  constructor(
    private readonly blockchain: BlockchainContext,
    private readonly auctionService: AuctionService,
  ) {
    this.consumerInterface = new Interface(consumerHandlerArtifact.abi);
  }

  async spawnConsumer(input: SpawnConsumerInput): Promise<{
    consumerHandlerAddress: string;
    auction: AuctionView;
    snapThresholdWei: string;
    budgetWei: string;
    rationale: string;
    transactionHash: string;
    blockNumber: number;
  }> {
    const auction = await this.auctionService.getAuctionById(input.auctionId);
    if (auction.statusLabel !== "Active") {
      throw new HttpError(409, `Auction ${auction.id} is not active`);
    }

    const snapThresholdWei = this.planThreshold(auction, input.budgetWei, input.urgency);
    const deployValue =
      input.budgetWei + this.blockchain.env.consumerSubscriptionReserveWei;
    const targetDataType = input.targetDataType ?? auction.dataType;

    const deployment = await this.blockchain.consumerHandlerFactory.deploy(
      this.blockchain.env.dutchAuctionAddress,
      this.blockchain.env.dataProviderAddress,
      snapThresholdWei,
      targetDataType,
      this.blockchain.env.consumerHandlerGasLimit,
      {
        value: deployValue,
      },
    );

    const receipt = await deployment.deploymentTransaction()?.wait();
    if (!receipt) {
      throw new Error("Missing transaction receipt for ConsumerHandler deployment");
    }

    const consumerHandlerAddress = this.extractCreatedAddress(receipt);

    return {
      consumerHandlerAddress,
      auction,
      snapThresholdWei: snapThresholdWei.toString(),
      budgetWei: input.budgetWei.toString(),
      rationale: [
        `urgency=${input.urgency}`,
        `budgetWei=${input.budgetWei.toString()}`,
        `floorWei=${auction.floorPrice}`,
        `currentWei=${auction.currentPrice}`,
      ].join(" "),
      transactionHash: receipt.hash,
      blockNumber: receipt.blockNumber,
    };
  }

  private planThreshold(
    auction: AuctionView,
    budgetWei: bigint,
    urgency: ConsumerUrgency,
  ): bigint {
    const floorPrice = BigInt(auction.floorPrice);
    const currentPrice = BigInt(auction.currentPrice);

    if (budgetWei < floorPrice) {
      throw new HttpError(400, "budgetWei is below the auction floor price");
    }

    const affordableCap = min(currentPrice, budgetWei);
    const span = affordableCap - floorPrice;
    return floorPrice + (span * urgencyToBps(urgency)) / 10000n;
  }

  private extractCreatedAddress(receipt: ContractTransactionReceipt): string {
    if (receipt.contractAddress) {
      return receipt.contractAddress;
    }

    for (const log of receipt.logs as Log[]) {
      try {
        const parsed = this.consumerInterface.parseLog(log);
        if (parsed) {
          break;
        }
      } catch {
        continue;
      }
    }

    throw new Error("ConsumerHandler deployment did not return a contract address");
  }
}
