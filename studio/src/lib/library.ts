"use client";

import { openDB, type DBSchema, type IDBPDatabase } from "idb";

import type { Asset } from "./types";

/**
 * Local asset library.
 *
 * Generations are recorded in IndexedDB in the browser rather than a server
 * database, which keeps the studio deployable as a single stateless app with no
 * infrastructure to run. The trade-off is that history is per-browser and not
 * shared between devices — when the studio needs a shared team library, replace
 * this module's five functions with API calls and the UI stays unchanged.
 *
 * Only metadata and fal CDN URLs are stored, never the file bytes.
 *
 * Note: fal's stored outputs expire, so old entries can end up pointing at URLs
 * that 404. The gallery shows a placeholder in that case rather than a broken
 * image, and anything worth keeping should be downloaded.
 */

const DB_NAME = "fofv-studio";
const DB_VERSION = 1;
const STORE = "assets";

interface StudioDB extends DBSchema {
  [STORE]: {
    key: string;
    value: Asset;
    indexes: { "by-createdAt": number };
  };
}

let dbPromise: Promise<IDBPDatabase<StudioDB>> | null = null;

function getDb(): Promise<IDBPDatabase<StudioDB>> {
  if (typeof indexedDB === "undefined") {
    return Promise.reject(new Error("IndexedDB is unavailable in this browser."));
  }
  dbPromise ??= openDB<StudioDB>(DB_NAME, DB_VERSION, {
    upgrade(db) {
      const store = db.createObjectStore(STORE, { keyPath: "id" });
      store.createIndex("by-createdAt", "createdAt");
    },
  });
  return dbPromise;
}

/** Newest first. */
export async function listAssets(): Promise<Asset[]> {
  try {
    const db = await getDb();
    const assets = await db.getAllFromIndex(STORE, "by-createdAt");
    return assets.reverse();
  } catch (error) {
    console.error("Could not read the asset library:", error);
    return [];
  }
}

export async function saveAsset(asset: Asset): Promise<void> {
  const db = await getDb();
  await db.put(STORE, asset);
}

export async function saveAssets(assets: Asset[]): Promise<void> {
  const db = await getDb();
  const tx = db.transaction(STORE, "readwrite");
  await Promise.all([...assets.map((asset) => tx.store.put(asset)), tx.done]);
}

export async function deleteAsset(id: string): Promise<void> {
  const db = await getDb();
  await db.delete(STORE, id);
}

export async function clearAssets(): Promise<void> {
  const db = await getDb();
  await db.clear(STORE);
}

export function newAssetId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}
