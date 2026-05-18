## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## Deployment

The contract stack is deployed through `Makefile` targets in two modes:

- local Anvil deployment with mocked Somnia-only infrastructure
- Somnia testnet deployment with the real platform address and your researched JSON API agent id

### Required env

The `Makefile` reads `.env` via `-include .env`.

Minimum shared values:

```env
PRIVATE_KEY=...
RPC_URL=https://dream-rpc.somnia.network
```

Useful defaults already exist in `Makefile` for:

- `SOMNIA_AGENT_PLATFORM=0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776`
- `JSON_API_AGENT_ID=13174292974160097713`
- `AUCTION_CLOCK_GAS_LIMIT=5000000`
- `CONSUMER_HANDLER_GAS_LIMIT=2000000`

Consumer deployment values:

```env
CONSUMER_SNAP_THRESHOLD=3000000000000000000
CONSUMER_TARGET_DATA_TYPE=ETH/USD
CONSUMER_HANDLER_DEPLOY_VALUE=42000000000000000000
```

### Local Anvil

Start Anvil in one shell:

```shell
make anvil
```

Deploy the core stack in another shell:

```shell
make deploy-local-core
```

This target does three things:

1. Builds the contracts
2. Installs a mock reactivity precompile at `0x0100` on Anvil
3. Deploys:
   - `MockAgentPlatform`
   - `Escrow`
   - `AuctionClock`
   - `DutchAuction`
   - `DataProvider`

Then deploy a consumer handler using the printed core addresses:

```shell
make deploy-local-consumer \
  DUTCH_AUCTION_ADDRESS=0x... \
  DATA_PROVIDER_ADDRESS=0x...
```

### Somnia Testnet

Deploy the core stack:

```shell
make deploy-testnet-core
```

This deploys:

- `Escrow`
- `AuctionClock`
- `DutchAuction`
- `DataProvider`

Then deploy a consumer handler using the printed core addresses:

```shell
make deploy-testnet-consumer \
  DUTCH_AUCTION_ADDRESS=0x... \
  DATA_PROVIDER_ADDRESS=0x...
```

### Notes

- `AuctionClock` and `DutchAuction` are constructor-coupled, so deployment is handled by the unified deploy scripts rather than by manually running the per-contract scripts out of order.
- Local Anvil does not emulate Somnia reactivity, which is why the local deploy path patches a mock precompile into `0x0100`.
- `ConsumerHandler` is intentionally deployed separately because it is per-consumer state, not shared marketplace infrastructure.
