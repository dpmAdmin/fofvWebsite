"use client";

import { useEffect, useRef, useState } from "react";

import { AssetTile } from "@/components/AssetTile";
import type { Asset, JobPhase, ModelDef } from "@/lib/types";
import { cn, formatElapsed } from "@/lib/utils";

const PHASE_COPY: Record<Exclude<JobPhase, "idle" | "done" | "error">, string> = {
  uploading: "Uploading source files",
  queued: "Queued at fal",
  running: "Generating",
};

/** Ticking elapsed-time counter, so a long video job doesn't look frozen. */
function Elapsed({ since }: { since: number }) {
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);

  return (
    <span className="font-mono text-xs tabular-nums text-chalk-faint">
      {formatElapsed(now - since)}
    </span>
  );
}

export function JobPanel({
  model,
  phase,
  startedAt,
  logs,
  error,
  results,
  onRerun,
  onCancel,
}: {
  model: ModelDef;
  phase: JobPhase;
  startedAt: number | null;
  logs: string[];
  error: string | null;
  results: Asset[];
  onRerun: (asset: Asset) => void;
  onCancel?: () => void;
}) {
  const logRef = useRef<HTMLPreElement>(null);
  const isBusy = phase === "uploading" || phase === "queued" || phase === "running";

  // Keep the newest log line in view.
  useEffect(() => {
    if (logRef.current) logRef.current.scrollTop = logRef.current.scrollHeight;
  }, [logs]);

  if (phase === "idle" && results.length === 0) {
    return (
      <div className="grid h-full min-h-80 place-items-center rounded-card border border-dashed border-ink-800 px-6 text-center">
        <div>
          <p className="text-sm font-semibold text-chalk-dim">{model.title}</p>
          <p className="mx-auto mt-1.5 max-w-sm text-xs leading-relaxed text-chalk-faint">
            {model.blurb}
          </p>
          {model.docsUrl && (
            <a
              href={model.docsUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="mt-3 inline-block text-xs font-semibold text-gold hover:text-gold-bright"
            >
              View this model on fal ↗
            </a>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {isBusy && (
        <div className="rounded-card border border-ink-800 bg-ink-900 p-4">
          <div className="flex items-center gap-3">
            <span className="size-2 shrink-0 animate-pulse rounded-full bg-gold" />
            <span className="flex-1 text-sm font-semibold">
              {PHASE_COPY[phase as keyof typeof PHASE_COPY]}
              {model.eta && phase !== "uploading" && (
                <span className="ml-2 font-normal text-chalk-faint">typically {model.eta}</span>
              )}
            </span>
            {startedAt && <Elapsed since={startedAt} />}
            {onCancel && phase !== "uploading" && (
              <button
                type="button"
                onClick={onCancel}
                className="rounded-md border border-ink-700 px-2 py-1 text-[11px] font-semibold text-chalk-dim transition hover:border-danger hover:text-danger"
              >
                Cancel
              </button>
            )}
          </div>

          <div className="mt-3 h-1 overflow-hidden rounded-full bg-ink-800 shimmer" />

          {logs.length > 0 && (
            <pre
              ref={logRef}
              className="mt-3 max-h-32 overflow-y-auto whitespace-pre-wrap break-words rounded-md bg-ink-950 p-2.5 font-mono text-[11px] leading-relaxed text-chalk-faint"
            >
              {logs.join("\n")}
            </pre>
          )}
        </div>
      )}

      {error && (
        <div
          role="alert"
          className="rounded-card border border-danger/40 bg-danger/5 p-4 text-sm text-danger"
        >
          <p className="font-semibold">That generation failed.</p>
          <p className="mt-1 leading-relaxed break-words">{error}</p>
          {model.docsUrl && (
            <p className="mt-2 text-xs text-chalk-faint">
              If this mentions an unexpected or missing field, the model&apos;s input schema has
              probably changed.{" "}
              <a
                href={model.docsUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="font-semibold text-gold hover:text-gold-bright"
              >
                Check it on fal ↗
              </a>{" "}
              and update <code className="font-mono">src/lib/models.ts</code>.
            </p>
          )}
        </div>
      )}

      {results.length > 0 && (
        <div
          className={cn(
            "grid gap-4",
            results.length === 1 ? "grid-cols-1" : "grid-cols-1 sm:grid-cols-2",
          )}
        >
          {results.map((asset) => (
            <AssetTile key={asset.id} asset={asset} onRerun={onRerun} />
          ))}
        </div>
      )}
    </div>
  );
}
