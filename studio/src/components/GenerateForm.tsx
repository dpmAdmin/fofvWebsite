"use client";

import { useMemo, useState } from "react";

import { ImageInput } from "@/components/ImageInput";
import type { Field, ModelDef } from "@/lib/types";
import { cn } from "@/lib/utils";

type Values = Record<string, unknown>;

/**
 * Builds the form's starting values: the model's declared defaults, with any
 * re-run values layered on top.
 *
 * This runs once per mount. The parent remounts this component (via `key`)
 * whenever the model changes or a re-run is requested, which is why there is no
 * effect here resetting state — that pattern causes a cascading second render.
 */
function initialValues(model: ModelDef, prefill?: Values | null): Values {
  const values: Values = {};

  for (const field of model.fields) {
    if (field.type === "image" || field.type === "images") {
      values[field.name] = [];
    } else if (field.defaultValue !== undefined) {
      values[field.name] = field.defaultValue;
    } else if (field.type === "boolean") {
      values[field.name] = false;
    } else {
      values[field.name] = "";
    }

    if (!prefill) continue;

    const incoming = prefill[field.name];
    if (incoming === undefined) continue;

    if (field.type === "image") {
      values[field.name] = typeof incoming === "string" ? [incoming] : [];
    } else if (field.type === "images") {
      values[field.name] = Array.isArray(incoming) ? incoming : [];
    } else {
      values[field.name] = incoming;
    }
  }

  return values;
}

/** Field values are stored loosely; this normalises them for fal. */
function coerce(field: Field, raw: unknown): unknown {
  if (field.type === "number") {
    if (raw === "" || raw === null || raw === undefined) return undefined;
    const parsed = Number(raw);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  if (field.type === "image") {
    const urls = raw as string[];
    return urls?.[0];
  }
  return raw;
}

function isMissing(field: Field, raw: unknown): boolean {
  if (!field.required) return false;
  if (field.type === "image" || field.type === "images") {
    return !Array.isArray(raw) || raw.length === 0;
  }
  return raw === "" || raw === null || raw === undefined;
}

/** DOM id for a field's wrapper row, used to scroll to the first error. */
function rowId(model: ModelDef, fieldName: string): string {
  return `row-${model.id}-${fieldName}`;
}

const labelClass = "mb-1.5 block text-sm font-semibold";
const controlClass =
  "w-full rounded-lg border border-ink-700 bg-ink-900 px-3 py-2 text-sm text-chalk placeholder:text-chalk-faint focus:border-gold focus:outline-none disabled:opacity-50";

export function GenerateForm({
  model,
  disabled,
  onSubmit,
  prefill,
}: {
  model: ModelDef;
  disabled: boolean;
  onSubmit: (values: Values) => void;
  /** Values from a re-run, applied over the model's defaults. */
  prefill?: Values | null;
}) {
  const [values, setValues] = useState<Values>(() => initialValues(model, prefill));
  const [showErrors, setShowErrors] = useState(false);

  const missing = useMemo(
    () => model.fields.filter((field) => isMissing(field, values[field.name])),
    [model, values],
  );

  function set(name: string, value: unknown) {
    setValues((current) => ({ ...current, [name]: value }));
  }

  function handleSubmit(event: React.FormEvent) {
    event.preventDefault();

    if (missing.length > 0) {
      setShowErrors(true);
      // The form is taller than the viewport, so an error above the fold would
      // otherwise be invisible and the button would look inert.
      document
        .getElementById(rowId(model, missing[0].name))
        ?.scrollIntoView({ behavior: "smooth", block: "center" });
      return;
    }

    const payload: Values = {};
    for (const field of model.fields) {
      const coerced = coerce(field, values[field.name]);
      if (coerced !== undefined) payload[field.name] = coerced;
    }
    onSubmit(payload);
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5">
      {model.fields.map((field) => {
        const raw = values[field.name];
        const invalid = showErrors && isMissing(field, raw);
        const fieldId = `field-${model.id}-${field.name}`;
        // File pickers manage their own inner inputs, so there is no single
        // control for a <label for> to point at — they get a labelled group.
        const isFileField = field.type === "image" || field.type === "images";
        const labelContent = (
          <>
            {field.label}
            {field.required && <span className="ml-1 text-gold">*</span>}
          </>
        );

        return (
          <div key={field.name} id={rowId(model, field.name)} className="scroll-mt-24">
            {isFileField ? (
              <span id={`${fieldId}-label`} className={labelClass}>
                {labelContent}
              </span>
            ) : (
              <label htmlFor={fieldId} className={labelClass}>
                {labelContent}
              </label>
            )}

            {field.type === "textarea" && (
              <textarea
                id={fieldId}
                rows={4}
                disabled={disabled}
                placeholder={field.placeholder}
                value={String(raw ?? "")}
                onChange={(event) => set(field.name, event.target.value)}
                className={cn(controlClass, "resize-y", invalid && "border-danger")}
              />
            )}

            {field.type === "text" && (
              <input
                id={fieldId}
                type="text"
                disabled={disabled}
                placeholder={field.placeholder}
                value={String(raw ?? "")}
                onChange={(event) => set(field.name, event.target.value)}
                className={cn(controlClass, invalid && "border-danger")}
              />
            )}

            {field.type === "select" && (
              <select
                id={fieldId}
                disabled={disabled}
                value={String(raw ?? "")}
                onChange={(event) => set(field.name, event.target.value)}
                className={cn(controlClass, invalid && "border-danger")}
              >
                {field.options?.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            )}

            {field.type === "number" &&
              (field.min !== undefined && field.max !== undefined && field.step !== undefined ? (
                <div className="flex items-center gap-3">
                  <input
                    id={fieldId}
                    type="range"
                    disabled={disabled}
                    min={field.min}
                    max={field.max}
                    step={field.step}
                    value={Number(raw ?? field.min)}
                    onChange={(event) => set(field.name, Number(event.target.value))}
                    className="h-1 flex-1 cursor-pointer appearance-none rounded-full bg-ink-700 accent-gold disabled:opacity-50"
                  />
                  <output className="w-12 shrink-0 text-right font-mono text-sm tabular-nums text-chalk-dim">
                    {String(raw ?? field.min)}
                  </output>
                </div>
              ) : (
                <input
                  id={fieldId}
                  type="number"
                  disabled={disabled}
                  placeholder={field.placeholder ?? "auto"}
                  value={raw === undefined || raw === null ? "" : String(raw)}
                  onChange={(event) => set(field.name, event.target.value)}
                  className={cn(controlClass, invalid && "border-danger")}
                />
              ))}

            {field.type === "boolean" && (
              <label className="flex cursor-pointer items-center gap-2.5">
                <input
                  id={fieldId}
                  type="checkbox"
                  disabled={disabled}
                  checked={Boolean(raw)}
                  onChange={(event) => set(field.name, event.target.checked)}
                  className="size-4 accent-gold"
                />
                <span className="text-sm text-chalk-dim">Enabled</span>
              </label>
            )}

            {isFileField && (
              <div role="group" aria-labelledby={`${fieldId}-label`}>
                <ImageInput
                  value={(raw as string[]) ?? []}
                  onChange={(urls) => set(field.name, urls)}
                  multiple={field.type === "images"}
                  disabled={disabled}
                />
              </div>
            )}

            {field.help && <p className="mt-1.5 text-xs text-chalk-faint">{field.help}</p>}
            {invalid && (
              <p role="alert" className="mt-1.5 text-xs text-danger">
                {field.label} is required.
              </p>
            )}
          </div>
        );
      })}

      <button
        type="submit"
        disabled={disabled}
        className="w-full rounded-lg bg-gold px-4 py-2.5 font-semibold text-ink-950 transition hover:bg-gold-bright disabled:cursor-not-allowed disabled:opacity-40"
      >
        {disabled ? "Working…" : `Generate${model.eta ? ` · ${model.eta}` : ""}`}
      </button>
    </form>
  );
}
