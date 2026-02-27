"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";
import ProtectionDashboard from "@/components/ProtectionDashboard";
import InteractionPanel from "@/components/InteractionPanel";

export default function Home() {
  return (
    <main className="min-h-screen px-4 py-8">
      <header className="max-w-lg mx-auto flex items-center justify-between mb-8">
        <h1 className="text-2xl font-bold tracking-tight">
          <span className="text-emerald-400">40</span> Acres
        </h1>
        <ConnectButton />
      </header>

      <ProtectionDashboard />
      <InteractionPanel />

      <footer className="max-w-lg mx-auto mt-12 text-center text-sm text-gray-600">
        Protecting asset ownership. Preventing displacement.
      </footer>
    </main>
  );
}
