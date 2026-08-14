"use client";

import { useCallback, useEffect, useRef, useState } from "react";

import { GenerateForm } from "@/components/GenerateForm";
import { JobPanel } from "@/components/JobPanel";
import { LibraryView } from "@/components/LibraryView";
import { ModelPicker } from "@/components/ModelPicker";
import { describeError, extractOutputs, fal } from "@/lib/fal";
import {
  clearAssets,
  deleteAsset,
  listAssets,
  newAssetId,
  saveAssets,
} from "@/lib/library";
import { MODELS, buildInput, getModel } from "@/lib/models";
import type { Asset, JobPhase, ModelDef } from "@/lib/types";
import { cn } from "@/lib/utils";

type Tab = "generate" | "library";

export default function StudioPage() {
  const [tab, setTab] = useState<Tab>("generate");
  const [model, setModel] = useState<ModelDef>(MODELS[0]);
  const [prefill, setPrefill] = useState<Record<string, unknown> | null>(null);
  /**
   * Bumped whenever the form should start over. Combined with the model id it
   * forms the form's `key`, so React remounts it with fresh initial values
   * instead of the form resetting itself from an effect.
   */
  const [formNonce, setFormNonce] = useState(0);

  const [phase, setPhase] = useState<JobPhase>("idle");
  const [startedAt, setStartedAt] = useState<number | null>(null);
  const [logs, setLogs] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [results, setResults] = useState<Asset[]>([]);

  const [library, setLibrary] = useState<Asset[]>([]);
  const [libraryLoading, setLibraryLoading] = useState(true);

  const abortRef = useRef<AbortController | null>(null);
  const isBusy = phase === "uploading" || phase === "queued" || phase === "running";

  useEffect(() => {
    void listAssets().then((assets) => {
      setLibrary(assets);
      setLibraryLoading(false);
    });
  }, []);

  // Don't let a page close silently kill a job the user is paying for.
  useEffect(() => {
    if (!isBusy) return;
    const warn = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [isBusy]);

  const selectModel = useCallback((next: ModelDef) => {
    setModel(next);
    setPrefill(null);
    setFormNonce((nonce) => nonce + 1);
    setResults([]);
    setError(null);
    setPhase("idle");
  }, []);

  const handleGenerate = useCallback(
    async (values: Record<string, unknown>) => {
      const input = buildInput(model, values);
      const controller = new AbortController();
      abortRef.current = controller;

      setPhase("queued");
      setStartedAt(Date.now());
      setLogs([]);
      setError(null);
      setResults([]);

      try {
        const result = await fal.subscribe(model.endpointId, {
          input,
          logs: true,
          abortSignal: controller.signal,
          onQueueUpdate: (status) => {
            setPhase(status.status === "IN_QUEUE" ? "queued" : "running");
            if ("logs" in status && Array.isArray(status.logs)) {
              setLogs(status.logs.map((entry) => entry.message).filter(Boolean));
            }
          },
        });

        const outputs = extractOutputs(result.data, model.outputKind);
        if (outputs.length === 0) {
          setPhase("error");
          setError(
            "fal completed the job but returned no files. The model's output shape may have changed.",
          );
          return;
        }

        const created: Asset[] = outputs.map((output) => ({
          id: newAssetId(),
          createdAt: Date.now(),
          modelId: model.id,
          modelTitle: model.title,
          endpointId: model.endpointId,
          input,
          output,
          requestId: result.requestId,
        }));

        setResults(created);
        setPhase("done");

        await saveAssets(created);
        setLibrary((current) => [...created, ...current]);
      } catch (thrown) {
        // A user-initiated cancel isn't a failure worth reporting.
        if (controller.signal.aborted) {
          setPhase("idle");
          setLogs([]);
          return;
        }
        setPhase("error");
        setError(describeError(thrown));
      } finally {
        abortRef.current = null;
      }
    },
    [model],
  );

  const handleCancel = useCallback(() => {
    abortRef.current?.abort();
  }, []);

  const handleRerun = useCallback((asset: Asset) => {
    const target = getModel(asset.modelId);
    if (target) setModel(target);
    setPrefill({ ...asset.input });
    setFormNonce((nonce) => nonce + 1);
    setResults([]);
    setError(null);
    setPhase("idle");
    setTab("generate");
    window.scrollTo({ top: 0, behavior: "smooth" });
  }, []);

  const handleDelete = useCallback(async (asset: Asset) => {
    await deleteAsset(asset.id);
    setLibrary((current) => current.filter((item) => item.id !== asset.id));
  }, []);

  const handleClear = useCallback(async () => {
    await clearAssets();
    setLibrary([]);
  }, []);

  return (
    <div className="min-h-dvh">
      <header className="sticky top-0 z-20 border-b border-ink-800 bg-ink-950/85 backdrop-blur-xl">
        <div className="mx-auto flex max-w-[1600px] items-center gap-4 px-5 py-3">
          <div className="flex items-center gap-2.5">
            <span className="grid size-8 place-items-center rounded-lg bg-chalk text-sm font-extrabold tracking-tighter text-ink-950">
              Fv
            </span>
            <span className="hidden text-sm font-bold tracking-tight sm:block">FOFV Studio</span>
          </div>

          <nav className="ml-2 flex gap-1" aria-label="Sections">
            {(["generate", "library"] as const).map((value) => (
              <button
                key={value}
                type="button"
                onClick={() => setTab(value)}
                aria-current={tab === value ? "page" : undefined}
                className={cn(
                  "rounded-lg px-3 py-1.5 text-sm font-semibold capitalize transition",
                  tab === value
                    ? "bg-ink-800 text-chalk"
                    : "text-chalk-faint hover:text-chalk-dim",
                )}
              >
                {value}
                {value === "library" && library.length > 0 && (
                  <span className="ml-1.5 text-xs text-chalk-faint">{library.length}</span>
                )}
              </button>
            ))}
          </nav>

          {isBusy && (
            <span className="hidden items-center gap-2 text-xs text-gold sm:flex">
              <span className="size-1.5 animate-pulse rounded-full bg-gold" />
              job running
            </span>
          )}

          <form action="/api/auth/logout" method="post" className="ml-auto">
            <button
              type="submit"
              className="text-xs font-semibold text-chalk-faint transition hover:text-chalk"
            >
              Sign out
            </button>
          </form>
        </div>
      </header>

      <main className="mx-auto max-w-[1600px] px-5 py-6">
        {/*
          The visible headings change as you switch models, so the page needs a
          stable top-level heading. This is also what Next's route announcer
          reads out to screen readers after navigation.
        */}
        <h1 className="sr-only">FOFV Studio</h1>

        {tab === "generate" ? (
          <div className="grid gap-6 lg:grid-cols-[240px_minmax(0,380px)_minmax(0,1fr)]">
            <aside className="lg:sticky lg:top-20 lg:self-start">
              <ModelPicker selected={model} onSelect={selectModel} disabled={isBusy} />
            </aside>

            <section aria-label="Settings" className="min-w-0">
              <div className="rounded-card border border-ink-800 bg-ink-900/50 p-5">
                <h2 className="text-base font-bold tracking-tight">{model.title}</h2>
                <p className="mt-1 mb-5 text-xs leading-relaxed text-chalk-faint">
                  {model.blurb}
                </p>
                <GenerateForm
                  key={`${model.id}:${formNonce}`}
                  model={model}
                  disabled={isBusy}
                  onSubmit={(values) => void handleGenerate(values)}
                  prefill={prefill}
                />
              </div>
            </section>

            <section aria-label="Output" className="min-w-0">
              <JobPanel
                model={model}
                phase={phase}
                startedAt={startedAt}
                logs={logs}
                error={error}
                results={results}
                onRerun={handleRerun}
                onCancel={isBusy ? handleCancel : undefined}
              />
            </section>
          </div>
        ) : (
          <LibraryView
            assets={library}
            loading={libraryLoading}
            onRerun={handleRerun}
            onDelete={(asset) => void handleDelete(asset)}
            onClear={() => void handleClear()}
          />
        )}
      </main>
    </div>
  );
}
