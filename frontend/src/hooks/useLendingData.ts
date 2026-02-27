"use client";

import { useReadContract, useWatchContractEvent } from "wagmi";
import { useQueryClient } from "@tanstack/react-query";
import { LendingABI, CornDexABI } from "@/config/abis";
import { CONTRACTS } from "@/config/wagmi";

export function useLendingData(userAddress: `0x${string}` | undefined) {
  const queryClient = useQueryClient();

  const healthFactor = useReadContract({
    address: CONTRACTS.lending,
    abi: LendingABI,
    functionName: "getHealthFactor",
    args: userAddress ? [userAddress] : undefined,
    query: { enabled: !!userAddress, refetchInterval: 5000 },
  });

  const riskStatus = useReadContract({
    address: CONTRACTS.lending,
    abi: LendingABI,
    functionName: "getRiskStatus",
    args: userAddress ? [userAddress] : undefined,
    query: { enabled: !!userAddress, refetchInterval: 5000 },
  });

  const account = useReadContract({
    address: CONTRACTS.lending,
    abi: LendingABI,
    functionName: "accounts",
    args: userAddress ? [userAddress] : undefined,
    query: { enabled: !!userAddress, refetchInterval: 5000 },
  });

  const collateralValue = useReadContract({
    address: CONTRACTS.lending,
    abi: LendingABI,
    functionName: "getCollateralValueInCorn",
    args: userAddress ? [userAddress] : undefined,
    query: { enabled: !!userAddress, refetchInterval: 5000 },
  });

  const ethPrice = useReadContract({
    address: CONTRACTS.cornDex,
    abi: CornDexABI,
    functionName: "ethPriceInCorn",
    query: { refetchInterval: 5000 },
  });

  // Re-fetch all data when a price update event fires
  useWatchContractEvent({
    address: CONTRACTS.cornDex,
    abi: CornDexABI,
    eventName: "PriceUpdated",
    onLogs: () => {
      queryClient.invalidateQueries();
    },
  });

  // Re-fetch when risk status changes
  useWatchContractEvent({
    address: CONTRACTS.lending,
    abi: LendingABI,
    eventName: "AtRiskStatusChanged",
    onLogs: () => {
      queryClient.invalidateQueries();
    },
  });

  return {
    healthFactor: healthFactor.data,
    riskStatus: riskStatus.data,
    account: account.data,
    collateralValue: collateralValue.data,
    ethPrice: ethPrice.data,
    isLoading:
      healthFactor.isLoading ||
      riskStatus.isLoading ||
      account.isLoading,
  };
}
