-include .env

LOCAL_RPC_URL ?= http://127.0.0.1:8545
LOCAL_PRIVATE_KEY ?= 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
AUCTION_CLOCK_GAS_LIMIT ?= 5000000

SOMNIA_AGENT_PLATFORM ?= 0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776
JSON_API_AGENT_ID ?= 13174292974160097713

CONSUMER_SNAP_THRESHOLD ?= 3000000000000000000
CONSUMER_TARGET_DATA_TYPE ?= ETH/USD
CONSUMER_HANDLER_GAS_LIMIT ?= 2000000
CONSUMER_HANDLER_DEPLOY_VALUE ?= 42000000000000000000

REACTIVITY_PRECOMPILE := 0x0000000000000000000000000000000000000100
REACTIVITY_PRECOMPILE_RUNTIME := $(shell forge inspect src/mocks/MockReactivityPrecompile.sol:MockReactivityPrecompile deployedBytecode 2>/dev/null)
STORAGE_SLOT_ZERO := 0x0000000000000000000000000000000000000000000000000000000000000000
STORAGE_VALUE_ONE := 0x0000000000000000000000000000000000000000000000000000000000000001

.PHONY: build coverage test compile fmt anvil bootstrap-local-reactivity \
	deploy-local-core deploy-local-consumer deploy-testnet-core deploy-testnet-consumer

build:
	forge build

coverage:
	forge coverage

test:
	forge test

compile:
	forge compile

fmt:
	forge fmt

anvil:
	anvil

bootstrap-local-reactivity: build
	cast rpc --rpc-url $(LOCAL_RPC_URL) anvil_setCode $(REACTIVITY_PRECOMPILE) $(REACTIVITY_PRECOMPILE_RUNTIME)
	cast rpc --rpc-url $(LOCAL_RPC_URL) anvil_setStorageAt $(REACTIVITY_PRECOMPILE) $(STORAGE_SLOT_ZERO) $(STORAGE_VALUE_ONE)

deploy-local-core: bootstrap-local-reactivity
	LOCAL_PRIVATE_KEY=$(LOCAL_PRIVATE_KEY) \
	AUCTION_CLOCK_GAS_LIMIT=$(AUCTION_CLOCK_GAS_LIMIT) \
	forge script script/DeployLocal.s.sol:DeployLocalScript \
		--rpc-url $(LOCAL_RPC_URL) \
		--private-key $(LOCAL_PRIVATE_KEY) \
		--broadcast

deploy-local-consumer: bootstrap-local-reactivity
	DUTCH_AUCTION_ADDRESS=$(DUTCH_AUCTION_ADDRESS) \
	DATA_PROVIDER_ADDRESS=$(DATA_PROVIDER_ADDRESS) \
	CONSUMER_SNAP_THRESHOLD=$(CONSUMER_SNAP_THRESHOLD) \
	CONSUMER_TARGET_DATA_TYPE="$(CONSUMER_TARGET_DATA_TYPE)" \
	CONSUMER_HANDLER_GAS_LIMIT=$(CONSUMER_HANDLER_GAS_LIMIT) \
	CONSUMER_HANDLER_DEPLOY_VALUE=$(CONSUMER_HANDLER_DEPLOY_VALUE) \
	forge script script/ConsumerHandler.s.sol:ConsumerHandlerScript \
		--rpc-url $(LOCAL_RPC_URL) \
		--private-key $(LOCAL_PRIVATE_KEY) \
		--broadcast

deploy-testnet-core: build
	PRIVATE_KEY=$(PRIVATE_KEY) \
	SOMNIA_AGENT_PLATFORM=$(SOMNIA_AGENT_PLATFORM) \
	JSON_API_AGENT_ID=$(JSON_API_AGENT_ID) \
	AUCTION_CLOCK_GAS_LIMIT=$(AUCTION_CLOCK_GAS_LIMIT) \
	forge script script/DeployCore.s.sol:DeployCoreScript \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast

deploy-testnet-consumer: build
	DUTCH_AUCTION_ADDRESS=$(DUTCH_AUCTION_ADDRESS) \
	DATA_PROVIDER_ADDRESS=$(DATA_PROVIDER_ADDRESS) \
	CONSUMER_SNAP_THRESHOLD=$(CONSUMER_SNAP_THRESHOLD) \
	CONSUMER_TARGET_DATA_TYPE="$(CONSUMER_TARGET_DATA_TYPE)" \
	CONSUMER_HANDLER_GAS_LIMIT=$(CONSUMER_HANDLER_GAS_LIMIT) \
	CONSUMER_HANDLER_DEPLOY_VALUE=$(CONSUMER_HANDLER_DEPLOY_VALUE) \
	forge script script/ConsumerHandler.s.sol:ConsumerHandlerScript \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast
