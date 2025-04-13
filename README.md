
# CLAMM-DEX-Engine
It is a smart contract project written in [Solidity](https://docs.soliditylang.org/en/latest/) using [Foundry](https://book.getfoundry.sh/).
- It a smart contract I developed leveraging Foundry.
- It is a CLAMM - Concentrated Liquidity Automated Market Maker Decentralized Engine similar to [Uniswap v3](https://blog.uniswap.org/uniswap-v3), but with some less additional functionalities.
- Following properties are ommited when compared to the Uniswap v3 engine.
  -   Factory
  -   Price oracle
  -   Protocol fee
  -   Flash swap
  -   NFT
  -   Solidity advanced math libraries
  -   Callbacks
  



## Getting Started

 - [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git): You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
 - [foundry](https://getfoundry.sh/): You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`
 - [make](https://www.gnu.org/software/make/manual/make.html) (optional - either you can install `make` or you can simply substitute the make commands with forge commands by referring to the Makefile after including your .env file): You'll know you did it right if you can run `make --version` and you will see a response like `GNU Make 3.81...`

 
## Installation

- Install CLAMM-DEX-Engine
```bash
    git clone https://github.com/yug49/CLAMM-DEX-Engine
    cd CLAMM-DEX-Engine
```

- Make a .env file
```bash
    touch .env
```

- Open the .env file and fill in the details similar to:
```env
    SEPOLIA_RPC_URL=<YOUR SEPOLIA RPC URL>
    ETHERSCAN_API_KEY=<YOUR ETHERSCAN API KEY>
    SEPOLIA_PRIVATE_KEY=<YOUR PRIVATE KEY>

    # Arguments for Pool Deployment
    TOKEN_A=<ADDRESS OF TOKEN A>
    TOKEN_B=<ADDRESS OF TOKEN B>
    FEE=<FEES IN BASIS POINTS(either 500, 3000 or 10000)>
    INITIAL_SQRT_PRICE_X96=<INTIAL SQUARE ROOT PRICE X96>

    # Arguments for Position Management
    LOWER_TICK=-<LOWER TICK>
    UPPER_TICK=<UPPER TICK> 
    AMOUNT_TO_ADD=<AMOUNT OF LIQUIDITY TO ADD>
    AMOUNT_TO_REMOVE=<AMOUNT OF LIQUIDITY TO REMOVE>

    # Arguments for Collection of Fees or Removed/Burned Liquidity
    AMOUNT0_TO_COLLECT=<AMOUNT OF TOKEN A TO COLLECT>
    AMOUNT1_TO_COLLECT=<AMOUNT OF TOKEN B TO COLLECT>

    # Arguments for Swap Management
    SWAP_AMOUNT=<AMOUNT OF TOKENS TO SWAP>
    SQRT_PRICE_LIMIT_X96=<SQRT PRICE LIMIT X96 WHILE SWAPPING>
```
- Remove pre installed cache, unecessary or partially cloned modules modules etc.
```bash
    forge clean
    rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

```

- Build Project
```bash
    forge build
```
## Formatting
- to format all the solidity files:
```bash
    forge fmt
```


    
## 🔗 Links
Loved it? lets connect on:

[![twitter](https://img.shields.io/badge/twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://x.com/yugAgarwal29)
[![linkedin](https://img.shields.io/badge/linkedin-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/yug-agarwal-8b761b255/)

