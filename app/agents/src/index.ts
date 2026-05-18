import { runConsumerAgent } from "./consumer";
import { loadAppConfig } from "./shared/config";
import { runProviderAgent } from "./provider";

async function main() {
  const config = loadAppConfig(process.argv);

  switch (config.mode) {
    case "provider":
      await runProviderAgent(config);
      break;
    case "consumer":
      await runConsumerAgent(config);
      break;
    default:
      throw new Error(`Unhandled mode: ${String(config.mode)}`);
  }
}

void main().catch((error: unknown) => {
  const message = error instanceof Error ? error.stack ?? error.message : String(error);
  console.error(message);
  process.exit(1);
});
