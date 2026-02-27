"use client";

import { useState, useEffect } from "react";
import { useAccount, useWriteContract } from "wagmi";
import { useQueryClient } from "@tanstack/react-query";
import { parseEther } from "viem";
import { LendingABI, MovePriceABI } from "@/config/abis";
import { CONTRACTS } from "@/config/wagmi";

function TxFeedback({
  isPending,
  isSuccess,
  isError,
  error,
}: {
  isPending: boolean;
  isSuccess: boolean;
  isError: boolean;
  error: Error | null;
}) {
  if (isPending) {
    return (
      <p className="text-xs text-blue-400 animate-pulse mt-2">
        Waiting for confirmation...
      </p>
    );
  }
  if (isSuccess) {
    return <p className="text-xs text-emerald-400 mt-2">Transaction confirmed</p>;
  }
  if (isError && error) {
    const msg = error.message;
    const short = msg.includes("User rejected")
      ? "Transaction rejected"
      : msg.slice(0, 140);
    return <p className="text-xs text-red-400 mt-2 break-all">{short}</p>;
  }
  return null;
}

function ActionInput({
  value,
  onChange,
  placeholder,
  unit,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder: string;
  unit: string;
}) {
  return (
    <div className="relative">
      <input
        type="text"
        inputMode="decimal"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full px-3 py-2 pr-14 rounded-lg bg-gray-700 border border-gray-600 text-white text-sm
                   placeholder:text-gray-500 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
      />
      <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-400 pointer-events-none">
        {unit}
      </span>
    </div>
  );
}

function ActionButton({
  onClick,
  disabled,
  variant = "primary",
  children,
}: {
  onClick: () => void;
  disabled: boolean;
  variant?: "primary" | "danger" | "warning" | "neutral";
  children: React.ReactNode;
}) {
  const base =
    "w-full px-4 py-2.5 rounded-lg text-sm font-semibold transition-colors disabled:opacity-40 disabled:cursor-not-allowed";
  const variants = {
    primary: "bg-emerald-600 hover:bg-emerald-500 text-white",
    danger: "bg-red-600 hover:bg-red-500 text-white",
    warning: "bg-amber-600 hover:bg-amber-500 text-white",
    neutral: "bg-gray-600 hover:bg-gray-500 text-white",
  };
  return (
    <button onClick={onClick} disabled={disabled} className={`${base} ${variants[variant]}`}>
      {children}
    </button>
  );
}

function DepositCollateral() {
  const [amount, setAmount] = useState("");
  const queryClient = useQueryClient();
  const { writeContract, isPending, isSuccess, isError, error, reset } =
    useWriteContract();

  useEffect(() => {
    if (isSuccess) {
      queryClient.invalidateQueries();
      setAmount("");
    }
  }, [isSuccess, queryClient]);

  const handleDeposit = () => {
    if (!amount || parseFloat(amount) <= 0) return;
    reset();
    writeContract({
      address: CONTRACTS.lending,
      abi: LendingABI,
      functionName: "depositCollateral",
      value: parseEther(amount),
    });
  };

  return (
    <div className="space-y-2">
      <ActionInput value={amount} onChange={setAmount} placeholder="10" unit="ETH" />
      <ActionButton onClick={handleDeposit} disabled={isPending || !amount}>
        {isPending ? "Depositing..." : "Deposit Collateral"}
      </ActionButton>
      <TxFeedback isPending={isPending} isSuccess={isSuccess} isError={isError} error={error} />
    </div>
  );
}

function WithdrawCollateral() {
  const [amount, setAmount] = useState("");
  const queryClient = useQueryClient();
  const { writeContract, isPending, isSuccess, isError, error, reset } =
    useWriteContract();

  useEffect(() => {
    if (isSuccess) {
      queryClient.invalidateQueries();
      setAmount("");
    }
  }, [isSuccess, queryClient]);

  const handleWithdraw = () => {
    if (!amount || parseFloat(amount) <= 0) return;
    reset();
    writeContract({
      address: CONTRACTS.lending,
      abi: LendingABI,
      functionName: "withdrawCollateral",
      args: [parseEther(amount)],
    });
  };

  return (
    <div className="space-y-2">
      <ActionInput value={amount} onChange={setAmount} placeholder="5" unit="ETH" />
      <ActionButton onClick={handleWithdraw} disabled={isPending || !amount} variant="neutral">
        {isPending ? "Withdrawing..." : "Withdraw Collateral"}
      </ActionButton>
      <TxFeedback isPending={isPending} isSuccess={isSuccess} isError={isError} error={error} />
    </div>
  );
}

function BorrowCorn() {
  const [amount, setAmount] = useState("");
  const queryClient = useQueryClient();
  const { writeContract, isPending, isSuccess, isError, error, reset } =
    useWriteContract();

  useEffect(() => {
    if (isSuccess) {
      queryClient.invalidateQueries();
      setAmount("");
    }
  }, [isSuccess, queryClient]);

  const handleBorrow = () => {
    if (!amount || parseFloat(amount) <= 0) return;
    reset();
    writeContract({
      address: CONTRACTS.lending,
      abi: LendingABI,
      functionName: "borrowCorn",
      args: [parseEther(amount)],
    });
  };

  return (
    <div className="space-y-2">
      <ActionInput value={amount} onChange={setAmount} placeholder="15000" unit="CORN" />
      <ActionButton onClick={handleBorrow} disabled={isPending || !amount}>
        {isPending ? "Borrowing..." : "Borrow CORN"}
      </ActionButton>
      <TxFeedback isPending={isPending} isSuccess={isSuccess} isError={isError} error={error} />
    </div>
  );
}

function RepayCorn() {
  const [amount, setAmount] = useState("");
  const queryClient = useQueryClient();
  const { writeContract, isPending, isSuccess, isError, error, reset } =
    useWriteContract();

  useEffect(() => {
    if (isSuccess) {
      queryClient.invalidateQueries();
      setAmount("");
    }
  }, [isSuccess, queryClient]);

  const handleRepay = () => {
    if (!amount || parseFloat(amount) <= 0) return;
    reset();
    writeContract({
      address: CONTRACTS.lending,
      abi: LendingABI,
      functionName: "repayCorn",
      args: [parseEther(amount)],
    });
  };

  return (
    <div className="space-y-2">
      <ActionInput value={amount} onChange={setAmount} placeholder="5000" unit="CORN" />
      <ActionButton onClick={handleRepay} disabled={isPending || !amount} variant="neutral">
        {isPending ? "Repaying..." : "Repay CORN"}
      </ActionButton>
      <TxFeedback isPending={isPending} isSuccess={isSuccess} isError={isError} error={error} />
    </div>
  );
}

function CrashPrice() {
  const [percent, setPercent] = useState("");
  const queryClient = useQueryClient();
  const { writeContract, isPending, isSuccess, isError, error, reset } =
    useWriteContract();

  useEffect(() => {
    if (isSuccess) {
      queryClient.invalidateQueries();
      setPercent("");
    }
  }, [isSuccess, queryClient]);

  const handleCrash = () => {
    const p = parseInt(percent, 10);
    if (!p || p <= 0 || p >= 100) return;
    reset();
    writeContract({
      address: CONTRACTS.movePrice,
      abi: MovePriceABI,
      functionName: "crashPrice",
      args: [BigInt(p)],
    });
  };

  return (
    <div className="space-y-2">
      <ActionInput value={percent} onChange={setPercent} placeholder="60" unit="%" />
      <ActionButton onClick={handleCrash} disabled={isPending || !percent} variant="danger">
        {isPending ? "Crashing..." : "Crash Price"}
      </ActionButton>
      <TxFeedback isPending={isPending} isSuccess={isSuccess} isError={isError} error={error} />
    </div>
  );
}

function PumpPrice() {
  const [percent, setPercent] = useState("");
  const queryClient = useQueryClient();
  const { writeContract, isPending, isSuccess, isError, error, reset } =
    useWriteContract();

  useEffect(() => {
    if (isSuccess) {
      queryClient.invalidateQueries();
      setPercent("");
    }
  }, [isSuccess, queryClient]);

  const handlePump = () => {
    const p = parseInt(percent, 10);
    if (!p || p <= 0) return;
    reset();
    writeContract({
      address: CONTRACTS.movePrice,
      abi: MovePriceABI,
      functionName: "pumpPrice",
      args: [BigInt(p)],
    });
  };

  return (
    <div className="space-y-2">
      <ActionInput value={percent} onChange={setPercent} placeholder="50" unit="%" />
      <ActionButton onClick={handlePump} disabled={isPending || !percent}>
        {isPending ? "Pumping..." : "Pump Price"}
      </ActionButton>
      <TxFeedback isPending={isPending} isSuccess={isSuccess} isError={isError} error={error} />
    </div>
  );
}

function FlagAtRisk() {
  const { address } = useAccount();
  const [target, setTarget] = useState("");
  const queryClient = useQueryClient();
  const { writeContract, isPending, isSuccess, isError, error, reset } =
    useWriteContract();

  useEffect(() => {
    if (isSuccess) queryClient.invalidateQueries();
  }, [isSuccess, queryClient]);

  const handleFlag = () => {
    const flagAddress = (target.trim() || address) as `0x${string}`;
    if (!flagAddress) return;
    reset();
    writeContract({
      address: CONTRACTS.lending,
      abi: LendingABI,
      functionName: "flagAtRisk",
      args: [flagAddress],
    });
  };

  return (
    <div className="space-y-2">
      <input
        type="text"
        value={target}
        onChange={(e) => setTarget(e.target.value)}
        placeholder={address ? `${address.slice(0, 10)}... (you)` : "0x..."}
        className="w-full px-3 py-2 rounded-lg bg-gray-700 border border-gray-600 text-white text-sm
                   placeholder:text-gray-500 focus:outline-none focus:border-amber-500 focus:ring-1 focus:ring-amber-500
                   font-mono"
      />
      <ActionButton onClick={handleFlag} disabled={isPending} variant="warning">
        {isPending ? "Flagging..." : "Flag At Risk"}
      </ActionButton>
      <TxFeedback isPending={isPending} isSuccess={isSuccess} isError={isError} error={error} />
    </div>
  );
}

function AdvanceTime() {
  const [hours, setHours] = useState("25");
  const [status, setStatus] = useState<"idle" | "pending" | "success" | "error">("idle");
  const [errorMsg, setErrorMsg] = useState("");
  const queryClient = useQueryClient();

  const handleAdvance = async () => {
    const h = parseFloat(hours);
    if (!h || h <= 0) return;
    setStatus("pending");
    setErrorMsg("");
    try {
      const seconds = Math.floor(h * 3600);
      await fetch("http://127.0.0.1:8545", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          jsonrpc: "2.0",
          method: "evm_increaseTime",
          params: [seconds],
          id: 1,
        }),
      });
      await fetch("http://127.0.0.1:8545", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          jsonrpc: "2.0",
          method: "evm_mine",
          params: [],
          id: 2,
        }),
      });
      setStatus("success");
      queryClient.invalidateQueries();
    } catch (e) {
      setStatus("error");
      setErrorMsg(e instanceof Error ? e.message : "RPC call failed");
    }
  };

  return (
    <div className="space-y-2">
      <ActionInput value={hours} onChange={setHours} placeholder="25" unit="hrs" />
      <ActionButton onClick={handleAdvance} disabled={status === "pending"} variant="neutral">
        {status === "pending" ? "Advancing..." : "Advance Block Time"}
      </ActionButton>
      {status === "success" && (
        <p className="text-xs text-emerald-400 mt-2">
          Time advanced by {hours}h and block mined
        </p>
      )}
      {status === "error" && (
        <p className="text-xs text-red-400 mt-2 break-all">{errorMsg}</p>
      )}
    </div>
  );
}

function CollapsibleSection({
  title,
  subtitle,
  icon,
  defaultOpen = false,
  children,
}: {
  title: string;
  subtitle: string;
  icon: string;
  defaultOpen?: boolean;
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);

  return (
    <div className="rounded-xl bg-gray-800/40 border border-gray-700/50 overflow-hidden">
      <button
        onClick={() => setOpen(!open)}
        className="w-full px-5 py-4 flex items-center gap-3 text-left hover:bg-gray-800/60 transition-colors"
      >
        <span className="text-lg">{icon}</span>
        <div className="flex-1">
          <h3 className="text-sm font-bold text-white">{title}</h3>
          <p className="text-xs text-gray-400">{subtitle}</p>
        </div>
        <svg
          className={`w-4 h-4 text-gray-400 transition-transform ${open ? "rotate-180" : ""}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      {open && <div className="px-5 pb-5 space-y-4">{children}</div>}
    </div>
  );
}

export default function InteractionPanel() {
  const { isConnected } = useAccount();

  if (!isConnected) return null;

  return (
    <div className="max-w-lg mx-auto mt-6 space-y-3">
      <h2 className="text-lg font-bold text-white px-1">Actions</h2>

      <CollapsibleSection
        title="Position Management"
        subtitle="Deposit, withdraw, borrow, and repay"
        icon="&#x1F3E6;"
        defaultOpen
      >
        <div className="space-y-5">
          <div>
            <p className="text-xs font-medium text-gray-300 mb-2">Deposit ETH</p>
            <DepositCollateral />
          </div>
          <div>
            <p className="text-xs font-medium text-gray-300 mb-2">Withdraw ETH</p>
            <WithdrawCollateral />
          </div>
          <div>
            <p className="text-xs font-medium text-gray-300 mb-2">Borrow CORN</p>
            <BorrowCorn />
          </div>
          <div>
            <p className="text-xs font-medium text-gray-300 mb-2">Repay CORN</p>
            <RepayCorn />
          </div>
        </div>
      </CollapsibleSection>

      <CollapsibleSection
        title="Price Control"
        subtitle="Crash or pump ETH/CORN price (owner only)"
        icon="&#x1F4C9;"
      >
        <div className="space-y-5">
          <div>
            <p className="text-xs font-medium text-gray-300 mb-2">Crash Price</p>
            <CrashPrice />
          </div>
          <div>
            <p className="text-xs font-medium text-gray-300 mb-2">Pump Price</p>
            <PumpPrice />
          </div>
        </div>
      </CollapsibleSection>

      <CollapsibleSection
        title="Risk Management"
        subtitle="Flag an undercollateralized position"
        icon="&#x26A0;&#xFE0F;"
      >
        <p className="text-xs text-gray-400 mb-1">
          Leave address blank to flag your own position. Anyone can call this if
          the target&apos;s health factor is below 1.0.
        </p>
        <FlagAtRisk />
      </CollapsibleSection>

      <CollapsibleSection
        title="Dev Tools"
        subtitle="Anvil time manipulation for testing"
        icon="&#x1F527;"
      >
        <p className="text-xs text-gray-400 mb-1">
          Fast-forward Anvil&apos;s block timestamp to simulate the grace period expiring.
          Default 25 hours exceeds the 24-hour Safety Net.
        </p>
        <AdvanceTime />
      </CollapsibleSection>
    </div>
  );
}
