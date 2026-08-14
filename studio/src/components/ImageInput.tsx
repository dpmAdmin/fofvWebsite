"use client";

import { useId, useRef, useState } from "react";

import { fal, describeError } from "@/lib/fal";
import { cn } from "@/lib/utils";

type Props = {
  /** Uploaded fal URLs. Single-image fields use a one-element array. */
  value: string[];
  onChange: (urls: string[]) => void;
  multiple?: boolean;
  disabled?: boolean;
};

/**
 * File picker that uploads to fal storage and yields the resulting URLs.
 *
 * Uploading on selection (rather than at submit time) means the form value is
 * always a plain URL, so a generation can be re-run straight from history
 * without the original file. Pasting an existing URL is also supported.
 */
export function ImageInput({ value, onChange, multiple = false, disabled }: Props) {
  const inputId = useId();
  const fileInput = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [dragging, setDragging] = useState(false);
  const [urlDraft, setUrlDraft] = useState("");

  async function uploadFiles(files: File[]) {
    if (files.length === 0) return;

    setUploading(true);
    setError(null);

    try {
      const urls = await Promise.all(files.map((file) => fal.storage.upload(file)));
      onChange(multiple ? [...value, ...urls] : urls.slice(0, 1));
    } catch (uploadError) {
      setError(describeError(uploadError));
    } finally {
      setUploading(false);
      // Clear the native input so re-picking the same file still fires change.
      if (fileInput.current) fileInput.current.value = "";
    }
  }

  function handleDrop(event: React.DragEvent) {
    event.preventDefault();
    setDragging(false);
    if (disabled || uploading) return;

    const files = Array.from(event.dataTransfer.files).filter((file) =>
      file.type.startsWith("image/"),
    );
    void uploadFiles(multiple ? files : files.slice(0, 1));
  }

  function addUrl() {
    const trimmed = urlDraft.trim();
    if (!trimmed) return;
    onChange(multiple ? [...value, trimmed] : [trimmed]);
    setUrlDraft("");
  }

  const busy = disabled || uploading;

  return (
    <div>
      {value.length > 0 && (
        <ul className="mb-3 flex flex-wrap gap-2.5">
          {value.map((url, index) => (
            <li key={url} className="group relative">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={url}
                alt={multiple ? `Source image ${index + 1}` : "Source image"}
                className="size-20 rounded-lg border border-ink-700 object-cover"
              />
              <button
                type="button"
                onClick={() => onChange(value.filter((item) => item !== url))}
                disabled={busy}
                aria-label={`Remove image ${index + 1}`}
                className="absolute -right-1.5 -top-1.5 grid size-5 place-items-center rounded-full bg-ink-700 text-xs leading-none text-chalk opacity-0 transition group-hover:opacity-100 focus-visible:opacity-100 hover:bg-danger disabled:hidden"
              >
                ×
              </button>
              {multiple && index === 0 && (
                <span className="absolute bottom-1 left-1 rounded bg-ink-950/80 px-1 py-0.5 text-[10px] font-semibold text-gold">
                  base
                </span>
              )}
            </li>
          ))}
        </ul>
      )}

      {(multiple || value.length === 0) && (
        <>
          <label
            htmlFor={inputId}
            onDragOver={(event) => {
              event.preventDefault();
              if (!busy) setDragging(true);
            }}
            onDragLeave={() => setDragging(false)}
            onDrop={handleDrop}
            className={cn(
              "flex cursor-pointer flex-col items-center justify-center rounded-lg border border-dashed px-4 py-6 text-center transition",
              dragging ? "border-gold bg-gold/5" : "border-ink-700 hover:border-ink-600",
              busy && "cursor-not-allowed opacity-60",
            )}
          >
            <span className="text-sm font-medium">
              {uploading ? "Uploading…" : "Drop an image or click to browse"}
            </span>
            <span className="mt-1 text-xs text-chalk-faint">
              JPG, PNG, or WebP{multiple ? " — add as many as you need" : ""}
            </span>
          </label>
          <input
            ref={fileInput}
            id={inputId}
            type="file"
            accept="image/*"
            multiple={multiple}
            disabled={busy}
            className="sr-only"
            onChange={(event) => void uploadFiles(Array.from(event.target.files ?? []))}
          />

          <div className="mt-2 flex gap-2">
            <input
              type="url"
              inputMode="url"
              placeholder="…or paste an image URL"
              value={urlDraft}
              disabled={busy}
              onChange={(event) => setUrlDraft(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter") {
                  event.preventDefault();
                  addUrl();
                }
              }}
              className="min-w-0 flex-1 rounded-lg border border-ink-700 bg-ink-900 px-3 py-1.5 text-xs text-chalk placeholder:text-chalk-faint focus:border-gold focus:outline-none"
            />
            <button
              type="button"
              onClick={addUrl}
              disabled={busy || urlDraft.trim().length === 0}
              className="rounded-lg border border-ink-700 px-3 py-1.5 text-xs font-semibold transition hover:border-ink-600 disabled:opacity-40"
            >
              Use
            </button>
          </div>
        </>
      )}

      {error && (
        <p role="alert" className="mt-2 text-xs text-danger">
          {error}
        </p>
      )}
    </div>
  );
}
