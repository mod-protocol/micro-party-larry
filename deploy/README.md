```
forge script --chain base deploy/Redeploy.s.sol --rpc-url $BASE_RPC_URL --broadcast --with-gas-price 5909747
```

Verify contracts e.g.
```
forge verify-contract \
    --chain-id 8453 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" "0xD9F65f0d2135BeE238db9c49558632Eb6030CAa7") \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    0xdb069Efa491c198893cAac1e744EC279067eb4C6 \
    src/OffchainAuthorityGateKeeper.sol:OffchainAuthorityGateKeeper \
```

Add `--via-ir --optimize --optimizer-runs 0 --evm-version paris` for Party implementation.

