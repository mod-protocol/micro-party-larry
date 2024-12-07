```
forge script --chain base deploy/Redeploy.s.sol --rpc-url $BASE_RPC_URL --broadcast --with-gas-price 64909747
```

Verify contracts e.g.
```
forge verify-contract \
    --chain-id 8453 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" "0xcEDe25DF327bD1619Fe25CDa2292e14edAC30717") \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    0xf7d563611326532eB7170ddb99F021da76D321Be \
    src/Party.sol:PartyImpl \
```

Add `--via-ir --optimize --optimizer-runs 0 --evm-version paris` for Party implementation.
