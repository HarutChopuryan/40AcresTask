"use client";

import { useState, useEffect, useCallback } from "react";
import { useAccount } from "wagmi";
import { formatEther } from "viem";
import { useLendingData } from "@/hooks/useLendingData";

type ProtectionStatus = "secure" | "safety-net" | "expired";

function getProtectionStatus(
  healthFactor: bigint | undefined,
  riskStatus: readonly [boolean, bigint, bigint] | undefined
): ProtectionStatus {
  if (!healthFactor || !riskStatus) return "secure";

  const [atRisk, , graceRemaining] = riskStatus;

  if (!atRisk) return "secure";
  if (graceRemaining > 0n) return "safety-net";
  return "expired";
}

function formatHealthFactor(hf: bigint | undefined): string {
  if (!hf) return "—";
  if (hf === BigInt("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")) {
    return "∞ (No Debt)";
  }
  const whole = hf / 10n ** 16n;
  const decimal = (hf % 10n ** 16n) / 10n ** 14n;
  return `${whole.toString().slice(0, -2)}.${whole.toString().slice(-2)}${decimal.toString().padStart(2, "0")}`;
}

function formatCountdown(seconds: number): string {
  if (seconds <= 0) return "0h 0m 0s";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return `${h}h ${m}m ${s}s`;
}

function StatusBadge({ status }: { status: ProtectionStatus }) {
  const config = {
    secure: {
      bg: "bg-emerald-500/15",
      border: "border-emerald-500/30",
      text: "text-emerald-400",
      dot: "bg-emerald-400",
      label: "Equity Secure",
    },
    "safety-net": {
      bg: "bg-amber-500/15",
      border: "border-amber-500/30",
      text: "text-amber-400",
      dot: "bg-amber-400 animate-pulse",
      label: "Safety Net Active",
    },
    expired: {
      bg: "bg-red-500/15",
      border: "border-red-500/30",
      text: "text-red-400",
      dot: "bg-red-400",
      label: "Protection Expired",
    },
  }[status];

  return (
    <div
      className={`inline-flex items-center gap-2 px-4 py-2 rounded-full border ${config.bg} ${config.border}`}
    >
      <span className={`w-2.5 h-2.5 rounded-full ${config.dot}`} />
      <span className={`font-semibold text-sm ${config.text}`}>
        {config.label}
      </span>
    </div>
  );
}

export default function ProtectionDashboard() {
  const { address, isConnected } = useAccount();
  const { healthFactor, riskStatus, account, collateralValue, ethPrice, isLoading } =
    useLendingData(address);
  const [countdown, setCountdown] = useState(0);

  const status = getProtectionStatus(healthFactor, riskStatus);

  const updateCountdown = useCallback(() => {
    if (!riskStatus) return;
    const [atRisk, atRiskSince, graceRemaining] = riskStatus;
    if (!atRisk || graceRemaining === 0n) {
      setCountdown(0);
      return;
    }
    // graceRemaining is in seconds from the contract, but may be stale;
    // we derive a live countdown from atRiskSince + 24h vs now
    if (atRiskSince > 0n) {
      const deadline = Number(atRiskSince) + 86400;
      const now = Math.floor(Date.now() / 1000);
      setCountdown(Math.max(0, deadline - now));
    } else {
      setCountdown(Number(graceRemaining));
    }
  }, [riskStatus]);

  useEffect(() => {
    updateCountdown();
    const interval = setInterval(updateCountdown, 1000);
    return () => clearInterval(interval);
  }, [updateCountdown]);

  if (!isConnected) {
    return (
      <div className="max-w-lg mx-auto mt-12 p-8 rounded-2xl bg-gray-900 border border-gray-800 text-center">
        <h2 className="text-2xl font-bold text-white mb-4">
          40 Acres Protection Dashboard
        </h2>
        <p className="text-gray-400">Connect your wallet to view your equity protection status.</p>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="max-w-lg mx-auto mt-12 p-8 rounded-2xl bg-gray-900 border border-gray-800 text-center">
        <div className="animate-spin w-8 h-8 border-2 border-white border-t-transparent rounded-full mx-auto" />
        <p className="text-gray-400 mt-4">Loading your position...</p>
      </div>
    );
  }

  const ethCollateral = account ? account[0] : 0n;
  const cornDebt = account ? account[1] : 0n;

  return (
    <div className="max-w-lg mx-auto mt-12">
      <div className="p-8 rounded-2xl bg-gray-900 border border-gray-800 space-y-6">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-bold text-white">Equity Protection</h2>
          <StatusBadge status={status} />
        </div>

        {/* Health Factor */}
        <div className="p-4 rounded-xl bg-gray-800/50 space-y-2">
          <p className="text-sm text-gray-400">Health Factor</p>
          <p
            className={`text-3xl font-mono font-bold ${
              status === "secure"
                ? "text-emerald-400"
                : status === "safety-net"
                ? "text-amber-400"
                : "text-red-400"
            }`}
          >
            {formatHealthFactor(healthFactor)}
          </p>
          <p className="text-xs text-gray-500">
            Must stay above 1.00 to remain secure
          </p>
        </div>

        {/* Countdown Timer (only visible during safety net) */}
        {status === "safety-net" && (
          <div className="p-4 rounded-xl bg-amber-500/10 border border-amber-500/20 space-y-2">
            <p className="text-sm text-amber-400 font-medium">
              Safety Net Time Remaining
            </p>
            <p className="text-2xl font-mono font-bold text-amber-300">
              {formatCountdown(countdown)}
            </p>
            <p className="text-xs text-amber-400/70">
              Add collateral or repay debt before this timer expires to protect your assets.
            </p>
          </div>
        )}

        {status === "expired" && (
          <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 space-y-2">
            <p className="text-sm text-red-400 font-medium">
              Your protection has expired
            </p>
            <p className="text-xs text-red-400/70">
              Your position is eligible for liquidation. Add collateral or repay debt immediately.
            </p>
          </div>
        )}

        {/* Position Details */}
        <div className="grid grid-cols-2 gap-4">
          <div className="p-4 rounded-xl bg-gray-800/50">
            <p className="text-xs text-gray-400 mb-1">ETH Collateral</p>
            <p className="text-lg font-mono text-white">
              {formatEther(ethCollateral)} ETH
            </p>
          </div>
          <div className="p-4 rounded-xl bg-gray-800/50">
            <p className="text-xs text-gray-400 mb-1">CORN Debt</p>
            <p className="text-lg font-mono text-white">
              {formatEther(cornDebt)} CORN
            </p>
          </div>
          <div className="p-4 rounded-xl bg-gray-800/50">
            <p className="text-xs text-gray-400 mb-1">Collateral Value</p>
            <p className="text-lg font-mono text-white">
              {collateralValue ? formatEther(collateralValue) : "0"} CORN
            </p>
          </div>
          <div className="p-4 rounded-xl bg-gray-800/50">
            <p className="text-xs text-gray-400 mb-1">ETH Price</p>
            <p className="text-lg font-mono text-white">
              {ethPrice ? formatEther(ethPrice) : "—"} CORN
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
