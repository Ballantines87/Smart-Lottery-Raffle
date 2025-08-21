-include .env

.PHONY: all build deploy install test

build:
	forge build

# @ obfuscates the command in the terminal
deploy-sepolia: 
	@forge script scripts/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account myaccount --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

install: 
	forge install cyfrin/foundry-devops@0.2.2 --no-git && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-git && forge install foundry-rs/forge-std@v1.8.2 --no-git && forge install transmissions11/solmate@v6 --no-git

test:
	forge test


