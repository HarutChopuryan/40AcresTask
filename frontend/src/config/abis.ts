export const LendingABI = [
  {
    type: "function",
    name: "getHealthFactor",
    inputs: [{ name: "user", type: "address" }],
    outputs: [{ name: "healthFactor", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getRiskStatus",
    inputs: [{ name: "user", type: "address" }],
    outputs: [
      { name: "atRisk", type: "bool" },
      { name: "atRiskSince", type: "uint256" },
      { name: "graceRemaining", type: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "accounts",
    inputs: [{ name: "", type: "address" }],
    outputs: [
      { name: "ethCollateral", type: "uint256" },
      { name: "cornDebt", type: "uint256" },
      { name: "atRiskSince", type: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getCollateralValueInCorn",
    inputs: [{ name: "user", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "depositCollateral",
    inputs: [],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "withdrawCollateral",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "borrowCorn",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "repayCorn",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "flagAtRisk",
    inputs: [{ name: "user", type: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "GRACE_PERIOD",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "event",
    name: "AtRiskStatusChanged",
    inputs: [
      { name: "user", type: "address", indexed: true },
      { name: "atRisk", type: "bool", indexed: false },
      { name: "timestamp", type: "uint256", indexed: false },
    ],
  },
] as const;

export const CornDexABI = [
  {
    type: "function",
    name: "ethPriceInCorn",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "event",
    name: "PriceUpdated",
    inputs: [
      { name: "oldPrice", type: "uint256", indexed: false },
      { name: "newPrice", type: "uint256", indexed: false },
    ],
  },
] as const;

export const MovePriceABI = [
  {
    type: "function",
    name: "crashPrice",
    inputs: [{ name: "dropPercent", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "pumpPrice",
    inputs: [{ name: "risePercent", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setExactPrice",
    inputs: [{ name: "newPrice", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
] as const;
