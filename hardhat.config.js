require("dotenv").config();

require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-foundry");

require("./script/hardhat-tasks/tasks");

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.21",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: `${process.env.FORK_RPC_URL}`,
        ...(process.env.BLOCK_NUMBER ? { blockNumber: parseInt(process.env.BLOCK_NUMBER) } : {}),
      },
    },
    mainnet: {
      url: `${process.env.MAINNET_RPC_URL}`,
    },
    goerli: {
      url: `${process.env.PROVIDER_URL_TESTNET}`,
    },
    local: {
      url: "http://localhost:8545",
    },
  },
};
