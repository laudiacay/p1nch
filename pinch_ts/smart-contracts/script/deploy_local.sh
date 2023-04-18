LOCAL_RPC=http://127.0.0.1:8545
source script/.env.local
forge script script/DeployDummies.sol:DummyDeployScript --broadcast --verify --rpc-url $LOCAL_RPC --via-ir && \
	forge script script/Deploy.sol:P1nchDeployScript --broadcast --verify --rpc-url $LOCAL_RPC --via-ir && \
	ts-node script/get_addresses.ts localnet --resolveJsonModule=true
