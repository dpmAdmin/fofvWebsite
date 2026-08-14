"use client";

import { fal } from "@fal-ai/client";

import type { AssetOutput, OutputKind } from "./types";

/**
 * Point the browser client at our own proxy rather than fal directly.
 *
 * With `proxyUrl` set, the client sends requests to `/api/fal/proxy`, which
 * attaches FAL_KEY server-side. No credentials are ever configured here, so
 * nothing sensitive reaches the bundle.
 */
fal.config({ proxyUrl: "/api/fal/proxy" });

export { fal };

const VIDEO_EXTENSIONS = /\.(mp4|webm|mov|m4v)(\?|$)/i;
const IMAGE_EXTENSIONS = /\.(png|jpe?g|webp|gif|avif)(\?|$)/i;

type FileLike = {
  url: string;
  content_type?: string;
  width?: number;
  height?: number;
};

function isFileLike(value: unknown): value is FileLike {
  return (
    typeof value === "object" &&
    value !== null &&
    typeof (value as { url?: unknown }).url === "string"
  );
}

function classify(file: FileLike, fallback: OutputKind): OutputKind {
  const contentType = file.content_type ?? "";
  if (contentType.startsWith("video/")) return "video";
  if (contentType.startsWith("image/")) return "image";
  if (VIDEO_EXTENSIONS.test(file.url)) return "video";
  if (IMAGE_EXTENSIONS.test(file.url)) return "image";
  return fallback;
}

/**
 * Pulls every produced file out of a fal response.
 *
 * fal endpoints do not share one output shape — some return `{ images: [...] }`,
 * others `{ image: {...} }`, `{ video: {...} }`, or nest files a level or two
 * deeper. Rather than hard-coding a shape per model (which silently breaks when
 * a model is versioned), this walks the response and collects anything that
 * looks like a file, preserving the order it appears in.
 */
export function extractOutputs(data: unknown, fallback: OutputKind): AssetOutput[] {
  const found: AssetOutput[] = [];
  const seen = new Set<string>();

  const visit = (node: unknown, depth: number) => {
    if (depth > 6 || node === null || typeof node !== "object") return;

    if (isFileLike(node)) {
      if (!seen.has(node.url)) {
        seen.add(node.url);
        found.push({
          url: node.url,
          kind: classify(node, fallback),
          contentType: node.content_type,
          width: node.width,
          height: node.height,
        });
      }
      return;
    }

    if (Array.isArray(node)) {
      for (const item of node) visit(item, depth + 1);
      return;
    }

    for (const value of Object.values(node)) visit(value, depth + 1);
  };

  visit(data, 0);
  return found;
}

/** Turns a fal or network error into something worth showing a user. */
export function describeError(error: unknown): string {
  if (error && typeof error === "object") {
    // ValidationError from the fal client carries per-field detail, which is
    // far more useful than the generic message when an input schema drifts.
    const body = (error as { body?: { detail?: unknown } }).body;
    const detail = body?.detail;

    if (Array.isArray(detail)) {
      const messages = detail
        .map((item) => {
          if (item && typeof item === "object") {
            const loc = (item as { loc?: unknown[] }).loc;
            const msg = (item as { msg?: string }).msg;
            const field = Array.isArray(loc) ? loc.filter((p) => p !== "body").join(".") : "";
            return field ? `${field}: ${msg}` : msg;
          }
          return String(item);
        })
        .filter(Boolean);
      if (messages.length > 0) return messages.join("; ");
    }

    if (typeof detail === "string") return detail;

    const status = (error as { status?: number }).status;
    if (status === 401 || status === 403) {
      return "Your session expired, or the server is missing its FAL_KEY. Try signing in again.";
    }

    const message = (error as { message?: string }).message;
    if (message) return message;
  }

  return "Something went wrong talking to fal.";
}

/** Best-effort filename for a downloaded asset. */
export function filenameFor(url: string, modelId: string, kind: OutputKind): string {
  const fromUrl = url.split("?")[0].split("/").pop();
  if (fromUrl && /\.[a-z0-9]{2,5}$/i.test(fromUrl)) {
    return `fofv-${modelId}-${fromUrl}`;
  }
  return `fofv-${modelId}-${Date.now()}.${kind === "video" ? "mp4" : "png"}`;
}
