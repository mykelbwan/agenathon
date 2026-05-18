interface Message {
  role: "system" | "user" | "assistant";
  content: string;
}

interface GenerateOptions {
  model?: string;
  temperature?: number;
  maxTokens?: number;
  topP?: number;
  stop?: string[];
}

interface LLMResponse {
  content: string;
  model?: string;
  usage?: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
  };
  finishReason?: "stop" | "length" | "error";
  metadata?: Record<string, unknown>;
}

interface HuggingFaceAdapterConfig {
  apiKey: string;
  defaultModel?: string;
  baseURL?: string;
}

interface HuggingFaceChatResponse {
  choices?: Array<{
    message?: {
      content?: string;
    };
    finish_reason?: string;
  }>;
  model?: string;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
    total_tokens?: number;
  };
  error?: {
    message?: string;
  };
}

function stripThinkBlocks(content: string): string {
  return content.replace(/<think>[\s\S]*?<\/think>\s*/gi, "").trim();
}

export class HuggingFaceAdapter {
  readonly name = "huggingface";
  private readonly apiKey: string;
  private readonly defaultModel: string;
  private readonly baseURL: string;

  constructor(config: HuggingFaceAdapterConfig) {
    this.apiKey = config.apiKey;
    this.defaultModel = config.defaultModel ?? "Qwen/Qwen3-32B";
    this.baseURL = config.baseURL ?? "https://router.huggingface.co/v1";
  }

  async generate(
    input: string,
    options?: GenerateOptions,
  ): Promise<LLMResponse> {
    return this.chat([{ role: "user", content: input }], options);
  }

  async chat(
    messages: Message[],
    options?: GenerateOptions,
  ): Promise<LLMResponse> {
    const response = await fetch(`${this.baseURL}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: options?.model ?? this.defaultModel,
        messages,
        temperature: options?.temperature ?? 0.2,
        max_tokens: options?.maxTokens ?? 300,
        top_p: options?.topP,
        stop: options?.stop,
      }),
    });

    const data = (await response.json()) as HuggingFaceChatResponse;
    if (!response.ok) {
      throw new Error(
        `Hugging Face API error: ${response.status} ${response.statusText}${
          data.error?.message ? ` - ${data.error.message}` : ""
        }`,
      );
    }

    const content = stripThinkBlocks(
      data.choices?.[0]?.message?.content?.trim() ?? "",
    );

    const llmResponse: LLMResponse = {
      content,
      model: data.model ?? (options?.model ?? this.defaultModel),
      finishReason:
        data.choices?.[0]?.finish_reason === "length" ? "length" : "stop",
      metadata: {
        provider: "huggingface",
      },
    };

    if (data.usage) {
      llmResponse.usage = {
        promptTokens: data.usage.prompt_tokens ?? 0,
        completionTokens: data.usage.completion_tokens ?? 0,
        totalTokens: data.usage.total_tokens ?? 0,
      };
    }

    return llmResponse;
  }
}
