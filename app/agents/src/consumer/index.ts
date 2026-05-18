import { ethers } from "ethers";
import { Agent } from "somnia-agent-kit";

import { consumerHandlerArtifact } from "../shared/abis";
import type { AppConfig } from "../shared/config";
import { createRuntimeContracts } from "../shared/contracts";
import type { AuctionRecord } from "../shared/contracts";
import { HuggingFaceConsumerPlanner } from "./planner";

interface AgentIdentity {
    runtimeAgent: Agent;
    agentId: bigint;
}

function now(): number {
    return Date.now();
}

function ensureDefined<T>(value: T | undefined, label: string): T {
    if (value === undefined) {
        throw new Error(`Missing required consumer config: ${label}`);
    }
    return value;
}

function ensureConsumerIdentityConfig(config: AppConfig) {
    return {
        name: ensureDefined(config.consumerAgentName, "CONSUMER_AGENT_NAME"),
        description: ensureDefined(
            config.consumerAgentDescription,
            "CONSUMER_AGENT_DESCRIPTION",
        ),
        metadata: ensureDefined(
            config.consumerAgentMetadata,
            "CONSUMER_AGENT_METADATA",
        ),
        capabilities: ensureDefined(
            config.consumerAgentCapabilities,
            "CONSUMER_AGENT_CAPABILITIES",
        ),
    };
}

async function ensureAgentIdentity(
    config: AppConfig,
    signer: ethers.Wallet | ethers.Signer,
    kit: NonNullable<Awaited<ReturnType<typeof createRuntimeContracts>>["kit"]>,
): Promise<AgentIdentity> {
    const owner = await signer.getAddress();
    const identityConfig = ensureConsumerIdentityConfig(config);
    const runtimeAgent = new Agent({
        name: identityConfig.name,
        description: identityConfig.description,
        owner,
        capabilities: identityConfig.capabilities,
    });

    await runtimeAgent.initialize(
        kit.contracts.registry,
        kit.contracts.executor,
    );

    const registry = kit.contracts.registry;
    const targetAgentId = config.consumerAgentId;

    if (targetAgentId !== undefined) {
        const tx = await registry.updateAgent(
            targetAgentId,
            identityConfig.name,
            identityConfig.description,
            identityConfig.metadata,
            identityConfig.capabilities,
        );
        await tx.wait();
        return { runtimeAgent, agentId: targetAgentId };
    }

    const ownerAgentIds = (await registry.getOwnerAgents(owner)) as bigint[];
    for (const agentId of ownerAgentIds) {
        const existing = await registry.getAgent(agentId);
        if (existing.name === identityConfig.name) {
            const tx = await registry.updateAgent(
                agentId,
                identityConfig.name,
                identityConfig.description,
                identityConfig.metadata,
                identityConfig.capabilities,
            );
            await tx.wait();
            return { runtimeAgent, agentId };
        }
    }

    const beforeIds = new Set(
        ownerAgentIds.map((agentId) => agentId.toString()),
    );
    const tx = await registry.registerAgent(
        identityConfig.name,
        identityConfig.description,
        identityConfig.metadata,
        identityConfig.capabilities,
    );
    await tx.wait();
    const afterIds = (await registry.getOwnerAgents(owner)) as bigint[];
    const createdAgentId = afterIds.find(
        (agentId) => !beforeIds.has(agentId.toString()),
    );
    if (createdAgentId === undefined) {
        throw new Error("Registration succeeded. No new agent id found");
    }

    return { runtimeAgent, agentId: createdAgentId };
}

function validateAuction(auction: AuctionRecord) {
    if (auction.status !== 0n) {
        throw new Error(`Auction ${auction.id.toString()} is not active`);
    }
}

export async function runConsumerAgent(config: AppConfig): Promise<void> {
    const runtime = await createRuntimeContracts(config);
    const planner = new HuggingFaceConsumerPlanner(config);
    const auctionId = ensureDefined(
        config.consumerAuctionId,
        "CONSUMER_AUCTION_ID",
    );
    const urgency = ensureDefined(config.consumerUrgency, "CONSUMER_URGENCY");
    const subscriptionReserveWei = ensureDefined(
        config.consumerSubscriptionReserveWei,
        "CONSUMER_SUBSCRIPTION_RESERVE_WEI",
    );
    const gasLimit = ensureDefined(
        config.consumerHandlerGasLimit,
        "CONSUMER_HANDLER_GAS_LIMIT",
    );

    let identity: AgentIdentity | undefined;
    const startedAt = now();
    if (runtime.kit) {
        identity = await ensureAgentIdentity(
            config,
            runtime.provider,
            runtime.kit,
        );
        console.log(
            `[consumer] AgentKit identity ready: agentId=${identity.agentId.toString()}`,
        );
    } else {
        console.log(
            "[consumer] AgentKit identity disabled. Running Hugging Face planner only.",
        );
    }

    const auction = await runtime.dutchAuction.getAuction(auctionId);
    validateAuction(auction);

    const budgetWei = config.consumerBudgetWei ?? auction.currentPrice;
    const targetDataType = config.consumerTargetDataType ?? auction.dataType;
    const plan = await planner.plan({
        auction: {
            auctionId,
            provider: auction.provider,
            dataType: auction.dataType,
            currentPrice: auction.currentPrice,
            floorPrice: auction.floorPrice,
            startPrice: auction.startPrice,
            status: auction.status,
        },
        budgetWei,
        urgency,
    });

    const deployValue = budgetWei + subscriptionReserveWei;
    const factory = new ethers.ContractFactory(
        consumerHandlerArtifact.abi,
        consumerHandlerArtifact.bytecode?.object ?? "",
        runtime.provider,
    );

    const deployment = await factory.deploy(
        config.dutchAuctionAddress,
        config.dataProviderAddress,
        plan.snapThresholdWei,
        targetDataType,
        gasLimit,
        { value: deployValue },
    );
    await deployment.waitForDeployment();
    const consumerHandlerAddress = await deployment.getAddress();

    console.log(
        `[consumer] deployed ConsumerHandler=${consumerHandlerAddress} auctionId=${auctionId.toString()} thresholdWei=${plan.snapThresholdWei.toString()} budgetWei=${budgetWei.toString()} model=${config.huggingFaceModel ?? "Qwen/Qwen3-32B"}`,
    );
    console.log(`[consumer] rationale ${plan.rationale}`);

    if (runtime.kit && identity) {
        const executionTimeMs = BigInt(Math.max(1, now() - startedAt));
        const metricsTx = await runtime.kit.contracts.registry.recordExecution(
            identity.agentId,
            true,
            executionTimeMs,
        );
        await metricsTx.wait();
        await identity.runtimeAgent.stop().catch(() => undefined);
    }
}
