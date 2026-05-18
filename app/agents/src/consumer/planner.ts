import type { AppConfig, ConsumerUrgency } from "../shared/config";
import { HuggingFaceAdapter } from "../shared/huggingface-adapter";

export interface AuctionSnapshot {
  auctionId: bigint;
  provider: string;
  dataType: string;
  currentPrice: bigint;
  floorPrice: bigint;
  startPrice: bigint;
  status: bigint;
}

export interface ConsumerPlanningInput {
  auction: AuctionSnapshot;
  budgetWei: bigint;
  urgency: ConsumerUrgency;
}

export interface ConsumerPlan {
  snapThresholdWei: bigint;
  rationale: string;
}

export interface ConsumerPlanner {
  plan(input: ConsumerPlanningInput): Promise<ConsumerPlan>;
}

function max(a: bigint, b: bigint): bigint {
  return a > b ? a : b;
}

function min(a: bigint, b: bigint): bigint {
  return a < b ? a : b;
}

function buildPrompt(input: ConsumerPlanningInput): string {
  const { auction, budgetWei, urgency } = input;

  return [
    "Choose a single snap threshold in wei for a Dutch auction consumer.",
    "Return valid JSON only.",
    "Your first character must be { and your last character must be }.",
    'Schema: {"snapThresholdWei":"<unsigned integer wei>","rationale":"<short explanation>"}',
    `auctionId=${auction.auctionId.toString()}`,
    `provider=${auction.provider}`,
    `dataType=${auction.dataType}`,
    `startPriceWei=${auction.startPrice.toString()}`,
    `currentPriceWei=${auction.currentPrice.toString()}`,
    `floorPriceWei=${auction.floorPrice.toString()}`,
    `budgetWei=${budgetWei.toString()}`,
    `urgency=${urgency}`,
    "Decision objective: choose the latest reasonable price for low urgency, a balanced price for medium urgency, and the earliest safe price for high urgency.",
    "Hard constraints: snapThresholdWei must be between floorPriceWei and min(currentPriceWei, budgetWei), inclusive.",
  ].join("\n");
}

function extractPlan(raw: string): ConsumerPlan {
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (start === -1 || end === -1 || end < start) {
    throw new Error(`LLM returned non-JSON planner output: ${raw}`);
  }

  const parsed = JSON.parse(raw.slice(start, end + 1)) as {
    snapThresholdWei?: string;
    rationale?: string;
  };

  if (!parsed.snapThresholdWei || !/^\d+$/.test(parsed.snapThresholdWei)) {
    throw new Error(`LLM returned invalid snapThresholdWei: ${raw}`);
  }

  return {
    snapThresholdWei: BigInt(parsed.snapThresholdWei),
    rationale: parsed.rationale?.trim() || "No rationale provided",
  };
}

export class HuggingFaceConsumerPlanner implements ConsumerPlanner {
  private readonly llm: HuggingFaceAdapter;

  constructor(config: AppConfig) {
    if (!config.huggingFaceApiKey) {
      throw new Error("Missing required environment variable: HUGGINGFACE_API_KEY");
    }

    this.llm = new HuggingFaceAdapter({
      apiKey: config.huggingFaceApiKey,
      defaultModel: config.huggingFaceModel ?? "Qwen/Qwen3-32B",
    });
  }

  async plan(input: ConsumerPlanningInput): Promise<ConsumerPlan> {
    const { auction, budgetWei } = input;

    if (budgetWei < auction.floorPrice) {
      throw new Error("Budget is below the auction floor price");
    }

    const response = await this.llm.chat(
      [
        {
          role: "system",
          content:
            "You are an auction decision agent. Do not reveal reasoning. Do not emit <think> tags. Output only a single JSON object and nothing else.",
        },
        {
          role: "user",
          content: buildPrompt(input),
        },
      ],
      {
        temperature: 0,
        maxTokens: 120,
      },
    );

    const proposedPlan = extractPlan(response.content);
    const upperBound = min(auction.currentPrice, budgetWei);
    const snapThresholdWei = min(
      upperBound,
      max(auction.floorPrice, proposedPlan.snapThresholdWei),
    );

    return {
      snapThresholdWei,
      rationale: proposedPlan.rationale,
    };
  }
}
