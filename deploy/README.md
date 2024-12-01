```
forge script --chain base deploy/Redeploy.s.sol --rpc-url $BASE_RPC_URL --broadcast --with-gas-price 44909747
```

Verify contracts e.g.
```
forge verify-contract \
    --chain-id 8453 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,uint40)" "0xcEDe25DF327bD1619Fe25CDa2292e14edAC30717" "1743003499") \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    <CONTRACT_ADDRESS> \
    src/TokenDistributor.sol:TokenDistributorImpl
```