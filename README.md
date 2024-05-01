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
