"use client";

import { useMemo, useState } from "react";

import { AssetTile } from "@/components/AssetTile";
import type { Asset } from "@/lib/types";
import { cn } from "@/lib/utils";

export function LibraryView({
  assets,
  loading,
  onRerun,
  onDelete,
  onClear,
}: {
  assets: Asset[];
  loading: boolean;
  onRerun: (asset: Asset) => void;
  onDelete: (asset: Asset) => void;
  onClear: () => void;
}) {
  const [filter, setFilter] = useState<string>("all");
  const [confirmingClear, setConfirmingClear] = useState(false);

  // Only offer filters for models actually present in the library.
  const models = useMemo(() => {
    const seen = new Map<string, string>();
    for (const asset of assets) seen.set(asset.modelId, asset.modelTitle);
    return [...seen].map(([id, title]) => ({ id, title }));
  }, [assets]);

  const visible = filter === "all" ? assets : assets.filter((a) => a.modelId === filter);

  if (loading) {
    return <p className="py-16 text-center text-sm text-chalk-faint">Loading your library…</p>;
  }

  if (assets.length === 0) {
    return (
      <div className="grid min-h-80 place-items-center rounded-card border border-dashed border-ink-800 px-6 text-center">
        <div>
          <p className="text-sm font-semibold text-chalk-dim">Nothing here yet</p>
          <p className="mx-auto mt-1.5 max-w-sm text-xs leading-relaxed text-chalk-faint">
            Everything you generate is saved here automatically, in this browser.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="mb-5 flex flex-wrap items-center gap-2">
        <button
          type="button"
          onClick={() => setFilter("all")}
          className={cn(
            "rounded-full border px-3 py-1 text-xs font-semibold transition",
            filter === "all"
              ? "border-gold/60 bg-gold/10 text-gold-bright"
              : "border-ink-700 text-chalk-dim hover:border-ink-600",
          )}
        >
          All ({assets.length})
        </button>

        {models.map((model) => (
          <button
            key={model.id}
            type="button"
            onClick={() => setFilter(model.id)}
            className={cn(
              "rounded-full border px-3 py-1 text-xs font-semibold transition",
              filter === model.id
                ? "border-gold/60 bg-gold/10 text-gold-bright"
                : "border-ink-700 text-chalk-dim hover:border-ink-600",
            )}
          >
            {model.title}
          </button>
        ))}

        <div className="ml-auto">
          {confirmingClear ? (
            <span className="flex items-center gap-2 text-xs">
              <span className="text-chalk-dim">Clear all {assets.length}?</span>
              <button
                type="button"
                onClick={() => {
                  onClear();
                  setConfirmingClear(false);
                }}
                className="rounded-md border border-danger px-2 py-1 font-semibold text-danger"
              >
                Yes, clear
              </button>
              <button
                type="button"
                onClick={() => setConfirmingClear(false)}
                className="rounded-md border border-ink-700 px-2 py-1 font-semibold text-chalk-dim"
              >
                Cancel
              </button>
            </span>
          ) : (
            <button
              type="button"
              onClick={() => setConfirmingClear(true)}
              className="text-xs font-semibold text-chalk-faint transition hover:text-danger"
            >
              Clear library
            </button>
          )}
        </div>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4">
        {visible.map((asset) => (
          <AssetTile key={asset.id} asset={asset} onRerun={onRerun} onDelete={onDelete} />
        ))}
      </div>
    </div>
  );
}
