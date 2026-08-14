"use client";

import { useState } from "react";

import { filenameFor } from "@/lib/fal";
import type { Asset } from "@/lib/types";
import { downloadUrl, timeAgo } from "@/lib/utils";

export function AssetTile({
  asset,
  onRerun,
  onDelete,
}: {
  asset: Asset;
  onRerun?: (asset: Asset) => void;
  onDelete?: (asset: Asset) => void;
}) {
  const [broken, setBroken] = useState(false);
  const { output } = asset;

  return (
    <figure className="group overflow-hidden rounded-card border border-ink-800 bg-ink-900">
      <div className="relative aspect-4/3 bg-ink-850">
        {broken ? (
          <div className="grid h-full place-items-center px-4 text-center">
            <p className="text-xs text-chalk-faint">
              This file is no longer available.
              <br />
              fal expires stored outputs — download assets you want to keep.
            </p>
          </div>
        ) : output.kind === "video" ? (
          <video
            src={output.url}
            controls
            playsInline
            preload="metadata"
            onError={() => setBroken(true)}
            className="h-full w-full object-contain"
          />
        ) : (
          /* eslint-disable-next-line @next/next/no-img-element */
          <img
            src={output.url}
            alt={`${asset.modelTitle} output`}
            loading="lazy"
            onError={() => setBroken(true)}
            className="h-full w-full object-contain"
          />
        )}
      </div>

      <figcaption className="border-t border-ink-800 p-3">
        <div className="flex items-baseline justify-between gap-2">
          <span className="truncate text-xs font-semibold">{asset.modelTitle}</span>
          <span className="shrink-0 text-[11px] text-chalk-faint">{timeAgo(asset.createdAt)}</span>
        </div>

        {typeof asset.input.prompt === "string" && asset.input.prompt.length > 0 && (
          <p className="mt-1 line-clamp-2 text-[11px] leading-snug text-chalk-faint">
            {asset.input.prompt}
          </p>
        )}

        <div className="mt-2.5 flex flex-wrap gap-1.5">
          <button
            type="button"
            onClick={() =>
              void downloadUrl(output.url, filenameFor(output.url, asset.modelId, output.kind))
            }
            className="rounded-md border border-ink-700 px-2 py-1 text-[11px] font-semibold transition hover:border-gold hover:text-gold"
          >
            Download
          </button>
          {onRerun && (
            <button
              type="button"
              onClick={() => onRerun(asset)}
              className="rounded-md border border-ink-700 px-2 py-1 text-[11px] font-semibold transition hover:border-gold hover:text-gold"
            >
              Re-run
            </button>
          )}
          <a
            href={output.url}
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-md border border-ink-700 px-2 py-1 text-[11px] font-semibold transition hover:border-gold hover:text-gold"
          >
            Open
          </a>
          {onDelete && (
            <button
              type="button"
              onClick={() => onDelete(asset)}
              className="ml-auto rounded-md border border-transparent px-2 py-1 text-[11px] font-semibold text-chalk-faint transition hover:text-danger"
            >
              Remove
            </button>
          )}
        </div>
      </figcaption>
    </figure>
  );
}
