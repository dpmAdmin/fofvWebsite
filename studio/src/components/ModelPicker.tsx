"use client";

import { CATEGORY_LABELS, CATEGORY_ORDER, MODELS } from "@/lib/models";
import type { ModelDef } from "@/lib/types";
import { cn } from "@/lib/utils";

export function ModelPicker({
  selected,
  onSelect,
  disabled,
}: {
  selected: ModelDef;
  onSelect: (model: ModelDef) => void;
  disabled: boolean;
}) {
  return (
    <nav aria-label="Model catalogue" className="space-y-6">
      {CATEGORY_ORDER.map((category) => {
        const models = MODELS.filter((model) => model.category === category);
        if (models.length === 0) return null;

        return (
          <section key={category}>
            <h2 className="mb-2 px-1 text-[11px] font-bold uppercase tracking-[0.14em] text-chalk-faint">
              {CATEGORY_LABELS[category]}
            </h2>
            <ul className="space-y-1.5">
              {models.map((model) => {
                const isSelected = model.id === selected.id;
                return (
                  <li key={model.id}>
                    <button
                      type="button"
                      disabled={disabled}
                      aria-current={isSelected ? "true" : undefined}
                      onClick={() => onSelect(model)}
                      className={cn(
                        "w-full rounded-lg border px-3 py-2.5 text-left transition disabled:cursor-not-allowed disabled:opacity-50",
                        isSelected
                          ? "border-gold/60 bg-gold/10"
                          : "border-transparent hover:border-ink-700 hover:bg-ink-900",
                      )}
                    >
                      <span
                        className={cn(
                          "block text-sm font-semibold",
                          isSelected ? "text-gold-bright" : "text-chalk",
                        )}
                      >
                        {model.title}
                      </span>
                      <span className="mt-0.5 block text-xs leading-snug text-chalk-faint">
                        {model.blurb}
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>
          </section>
        );
      })}
    </nav>
  );
}
