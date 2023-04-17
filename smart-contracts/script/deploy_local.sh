LOCAL_RPC=http://127.0.0.1:8545
source script/.env.local
forge script script/Deploy.sol:P1nchDeployScript --broadcast --verify --rpc-url $LOCAL_RPC --via-ir
