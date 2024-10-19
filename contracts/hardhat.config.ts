import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";

// Load environment variables from a .env file
dotenv.config();

const PRIVATE_KEY = process.env.PRIVATE_KEY; // Fixed typo in variable name

const config: HardhatUserConfig = {
  solidity: "0.8.27",

  networks: {
    bttcTestnet: {
      url: "https://pre-rpc.bittorrentchain.io/",   // BTTC Testnet RPC URL
      chainId: 1029,                                 // BTTC Testnet chain ID
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],    // Your private key from the .env file
    },
  },
};

export default config;

// USDT Contract: 0x48db5c1155836dE945fB82b6A9CF82D91AC21f16
// PikaPay Contract: <Add contract address here>
