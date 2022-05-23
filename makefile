# source the correct .env file first with `source .env.something`

test:
	forge test

gas: 
	forge test --gas-report --match-path src/gas/\\*/\\*.g.sol

deploy: 
	forge create --rpc-url ${RPC_URL} ./src/contracts/sweep/TreasureSmolSweepSwapper.sol:TreasureSmolSweepSwapper --constructor-args 0x09986B4e255B3c548041a30A2Ee312Fe176731c2 0x539bde0d7dbd336b79148aa742883198bbf60342 [] --private-key ${PRIVATE_KEY}

verify:
	# VARI=$(cast abi-encode 'constructor(address,address,address[])' ${TREASURE_MARKETPLACE_ADDRESS} ${TREASURE_TOKEN_ADDRESS} []);
	echo cast abi-encode 'constructor(address,address,address[])' ${TREASURE_MARKETPLACE_ADDRESS} ${TREASURE_TOKEN_ADDRESS} [];
	forge verify-contract --compiler-version ${COMPILER_VERSION} --chain ${CHAIN_ID} --constructor-args $(cast abi-encode "constructor(address,address,address[])" ${TREASURE_MARKETPLACE_ADDRESS} ${TREASURE_TOKEN_ADDRESS} []) 0x417ea37d1d3d951ed894a2025e9a608ae2b875be ./src/contracts/sweep/TreasureSmolSweepSwapper.sol:TreasureSmolSweepSwapper ${ETHERSCAN_KEY}