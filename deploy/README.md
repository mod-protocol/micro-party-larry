```
forge script --chain base deploy/Redeploy.s.sol --rpc-url $BASE_RPC_URL --broadcast --with-gas-price 44909747
```

Verify contracts e.g.
```
forge verify-contract \
    --chain-id 8453 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,address)" "0xD9F65f0d2135BeE238db9c49558632Eb6030CAa7" "0xd3C43A38D1D3E47E9c420a733e439B03FAAdebA8") \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    0xA53F16162B0fAbbaafE622cED0e63E28Fa45227d \
    src/NeynarScoreGateKeeper.sol:NeynarScoreGateKeeper
```