import { createApp } from "./app";
import { createBlockchainContext } from "./lib/blockchain";

async function main(): Promise<void> {
    const blockchain = createBlockchainContext();
    const app = createApp(blockchain);
    const PORT = 8000;

    app.listen(PORT, () => {
        console.log(`http://localhost:${PORT}`);
    });
}

void main();
