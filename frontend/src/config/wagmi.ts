import { http, createConfig } from "wagmi";
import { hardhat } from "wagmi/chains";
import { getDefaultConfig } from "@rainbow-me/rainbowkit";

export const config = getDefaultConfig({
  appName: "40 Acres Protection Dashboard",
  projectId: process.env.NEXT_PUBLIC_WC_PROJECT_ID || "demo",
  chains: [hardhat],
  transports: {
    [hardhat.id]: http("http://127.0.0.1:8545"),
  },
  ssr: true,
});

export const CONTRACTS = {
  lending: process.env.NEXT_PUBLIC_LENDING_ADDRESS as `0x${string}`,
  cornToken: process.env.NEXT_PUBLIC_CORN_TOKEN_ADDRESS as `0x${string}`,
  cornDex: process.env.NEXT_PUBLIC_CORN_DEX_ADDRESS as `0x${string}`,
  movePrice: process.env.NEXT_PUBLIC_MOVE_PRICE_ADDRESS as `0x${string}`,
} as const;
