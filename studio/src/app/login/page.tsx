"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setPending(true);
    setError(null);

    try {
      const response = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ password }),
      });

      if (!response.ok) {
        const body = await response.json().catch(() => ({}));
        setError(body.error ?? "Could not sign in.");
        setPending(false);
        return;
      }

      // `next` is a same-origin path from our own middleware. Reject anything
      // else so a crafted link can't turn the login into an open redirect.
      const requested = searchParams.get("next");
      const destination = requested?.startsWith("/") && !requested.startsWith("//")
        ? requested
        : "/";

      router.replace(destination);
      router.refresh();
    } catch {
      setError("Could not reach the server. Check your connection and try again.");
      setPending(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="w-full max-w-sm">
      <div className="mb-8">
        <div className="mb-5 grid size-11 place-items-center rounded-xl bg-chalk font-extrabold tracking-tighter text-ink-950">
          Fa
        </div>
        <h1 className="text-2xl font-bold tracking-tight">Fabrik</h1>
        <p className="mt-2 text-sm text-chalk-dim">
          Internal asset creation tools. Enter the studio password to continue.
        </p>
      </div>

      <label htmlFor="password" className="mb-2 block text-sm font-semibold">
        Studio password
      </label>
      <input
        id="password"
        name="password"
        type="password"
        autoComplete="current-password"
        autoFocus
        required
        value={password}
        onChange={(event) => setPassword(event.target.value)}
        className="w-full rounded-lg border border-ink-700 bg-ink-900 px-3.5 py-2.5 text-chalk placeholder:text-chalk-faint focus:border-gold focus:outline-none"
        placeholder="••••••••••••"
      />

      {error && (
        <p role="alert" className="mt-3 text-sm text-danger">
          {error}
        </p>
      )}

      <button
        type="submit"
        disabled={pending || password.length === 0}
        className="mt-5 w-full rounded-lg bg-gold px-4 py-2.5 font-semibold text-ink-950 transition hover:bg-gold-bright disabled:cursor-not-allowed disabled:opacity-40"
      >
        {pending ? "Checking…" : "Enter studio"}
      </button>
    </form>
  );
}

export default function LoginPage() {
  return (
    <main className="grid min-h-dvh place-items-center px-6">
      <Suspense fallback={null}>
        <LoginForm />
      </Suspense>
    </main>
  );
}
