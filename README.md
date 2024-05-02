## ERC20 Token Dispenser

### Overview

A vesting contract that will unlock ERC20 tokens over time on a monthly basis

The contract provides a mechanism to distribute the tokens monthly. This could be in one or many payments.

The amount distributed each month follows this distribution:

<img width="824" alt="image" src="https://github.com/0xhalv/vesting/assets/168580736/6af3546c-ca06-4d84-911a-1091ae95294b">

Maximum tokens to distribute any month: 10.000
- Year 1: 10% of the max
- Year 2: 25% of the max
- Year 3: 50% of the max
- Year 4: 100% of the max
- Year 8: 50% of the max
- Year 12: 25% of the max
- Year ...: half of the previous period until percentage drops to 1

Vesting ends when the monthly distribution reaches 100 tokens or less, in which case the owner withdraws all the remaining tokens

The total amount of tokens to distribute is 700.000

### Technical details

The contract is made upgradable just in case of change of plans or if we find a bug in the contract. The contract can be made non-upgradable after deployment by renouncing the ownership of the proxy contract.

Initializer of the vesting contract allows settings any arbitrary `_maxTokensInEpoch` value. The reason why these values are not constant in the vesting contract is due to different ERC20 tokens having different decimal points (e.g. USDT has 6 decimals, WETH has 18)

### Flow

1 month is called `epoch`.\
To get the epoch id for a given timestamp, the owner should call `timestampToEpoch(timestamp)` function.\
When new `epoch` starts, the owner can check how many tokens are unlocked by calling `claimableInEpoch(epoch)`\
Then the owner can distribute unlocked tokens by calling `distribute(addresses, values)` - this function will distribute given amount of tokens to respective addresses\
The owner can also distribute unclaimed tokens from past epochs by calling `distributeForEpoch(epoch, addresses, values)`\
When the vesting period finishes, any call `distribute` functions will revert and the owner must call `withdrawAll` which will send the rest of tokens from the vesting contract to the owner's balance


### Testing

Run `yarn test`

### Deployment

Rename `.env.example` to `.env` and put your secrets inside\
Run `yarn deploy`\
After deploying the contract the owner must send 700.000 tokens to the vesting contract\

Deployed on BSC Testnet:

Proxy contract: [0xf6b0cd14e7951360dc32a876f7852cca8fd12bc1](https://testnet.bscscan.com/address/0xf6b0cd14e7951360dc32a876f7852cca8fd12bc1)\
Implementation contract: [0xd3015780a7eba1d17215435b676818ef87094ad8](https://testnet.bscscan.com/address/0xd3015780a7eba1d17215435b676818ef87094ad8)\
Mock ERC20: [0xf2e097c90cc1b260e614d2250fbdbfb2b3059a74](https://testnet.bscscan.com/address/0xf2e097c90cc1b260e614d2250fbdbfb2b3059a74)
