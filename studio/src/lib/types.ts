/** Shared types for the model registry and generated assets. */

export type FieldType =
  | "text"
  | "textarea"
  | "select"
  | "number"
  | "boolean"
  | "image"
  | "images";

/**
 * One control in a model's input form.
 *
 * `name` is used verbatim as the key sent to fal, so it must match the model's
 * documented input schema exactly.
 */
export type Field = {
  name: string;
  label: string;
  type: FieldType;
  help?: string;
  required?: boolean;
  placeholder?: string;
  defaultValue?: string | number | boolean;
  /** Options for `select` fields. */
  options?: { label: string; value: string }[];
  /** Bounds for `number` fields, rendered as a slider when all three are set. */
  min?: number;
  max?: number;
  step?: number;
};

export type ModelCategory =
  | "generate"
  | "enhance"
  | "edit"
  | "stage"
  | "video";

export type OutputKind = "image" | "video";

export type ModelDef = {
  /** Stable internal slug, used in URLs and stored with each asset. */
  id: string;
  /** The fal endpoint, e.g. `fal-ai/flux/dev`. */
  endpointId: string;
  title: string;
  blurb: string;
  category: ModelCategory;
  outputKind: OutputKind;
  /** Roughly how long a job takes, shown to set expectations while queued. */
  eta?: string;
  /** Link to this model's page on fal, for checking the full input schema. */
  docsUrl?: string;
  fields: Field[];
  /** Fixed input values merged into every request for this model. */
  staticInput?: Record<string, unknown>;
};

/** A single generated file pulled out of a fal response. */
export type AssetOutput = {
  url: string;
  kind: OutputKind;
  contentType?: string;
  width?: number;
  height?: number;
};

/** One completed generation, as stored in the local asset library. */
export type Asset = {
  id: string;
  createdAt: number;
  modelId: string;
  modelTitle: string;
  endpointId: string;
  /** The exact input sent to fal, so a generation can be reproduced or tweaked. */
  input: Record<string, unknown>;
  output: AssetOutput;
  /** fal's request id, useful when asking fal support about a specific job. */
  requestId?: string;
  /** Free-text label the user can set. */
  note?: string;
};

export type JobPhase = "idle" | "uploading" | "queued" | "running" | "done" | "error";
