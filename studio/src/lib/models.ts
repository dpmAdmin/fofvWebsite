import type { Field, ModelCategory, ModelDef } from "./types";

/**
 * The catalogue of fal models the studio exposes.
 *
 * This is intentionally plain data: adding a model means adding an entry here,
 * with no UI changes — `GenerateForm` renders whatever fields you declare and
 * sends them to fal as-is.
 *
 * Two things to know when editing:
 *
 *  1. Each `name` is sent to fal verbatim, so it has to match that model's
 *     documented input schema. Check the model's page on fal.ai (`docsUrl`)
 *     before changing one.
 *  2. Endpoint IDs and their schemas do change as fal ships new versions. If a
 *     model here starts returning a validation error, compare it against its
 *     fal page and correct the entry.
 *
 * This list is also the proxy's allowlist (see `app/api/fal/proxy/route.ts`),
 * so an endpoint that isn't here cannot be called at all — which is why there
 * is deliberately no "run any endpoint" escape hatch in the UI.
 */

// ---------------------------------------------------------------------------
// Reusable fields
// ---------------------------------------------------------------------------

const promptField: Field = {
  name: "prompt",
  label: "Prompt",
  type: "textarea",
  required: true,
  placeholder:
    "A sunlit modern kitchen with white oak cabinetry, marble waterfall island, and floor-to-ceiling windows",
  help: "Describe the finished image. Specific nouns and lighting beat long adjective lists.",
};

const imageSizeField: Field = {
  name: "image_size",
  label: "Aspect ratio",
  type: "select",
  defaultValue: "landscape_4_3",
  options: [
    { label: "Landscape 4:3 — MLS photo", value: "landscape_4_3" },
    { label: "Landscape 16:9 — web hero", value: "landscape_16_9" },
    { label: "Square 1:1 — feed post", value: "square_hd" },
    { label: "Portrait 3:4", value: "portrait_4_3" },
    { label: "Portrait 9:16 — reel / story", value: "portrait_16_9" },
  ],
};

const numImagesField: Field = {
  name: "num_images",
  label: "How many",
  type: "number",
  defaultValue: 1,
  min: 1,
  max: 4,
  step: 1,
  help: "Each image is billed separately.",
};

const sourceImageField = (help: string): Field => ({
  name: "image_url",
  label: "Source image",
  type: "image",
  required: true,
  help,
});

// ---------------------------------------------------------------------------
// Catalogue
// ---------------------------------------------------------------------------

export const MODELS: ModelDef[] = [
  // --- Generate -----------------------------------------------------------
  {
    id: "flux-dev",
    endpointId: "fal-ai/flux/dev",
    title: "FLUX.1 [dev]",
    blurb:
      "Strong general-purpose text-to-image. Good default for marketing graphics and social backgrounds.",
    category: "generate",
    outputKind: "image",
    eta: "~10s",
    docsUrl: "https://fal.ai/models/fal-ai/flux/dev",
    fields: [
      promptField,
      imageSizeField,
      numImagesField,
      {
        name: "num_inference_steps",
        label: "Steps",
        type: "number",
        defaultValue: 28,
        min: 1,
        max: 50,
        step: 1,
        help: "More steps means more detail and more time. 28 is a sensible middle.",
      },
      {
        name: "guidance_scale",
        label: "Prompt adherence",
        type: "number",
        defaultValue: 3.5,
        min: 1,
        max: 10,
        step: 0.5,
        help: "Higher sticks closer to the prompt; lower gives the model more freedom.",
      },
      {
        name: "seed",
        label: "Seed",
        type: "number",
        help: "Leave blank for a new result each time. Reuse a seed to reproduce one.",
      },
    ],
  },
  {
    id: "flux-pro-ultra",
    endpointId: "fal-ai/flux-pro/v1.1-ultra",
    title: "FLUX1.1 [pro] ultra",
    blurb: "Highest-fidelity text-to-image in the catalogue. Use it for hero and print work.",
    category: "generate",
    outputKind: "image",
    eta: "~15s",
    docsUrl: "https://fal.ai/models/fal-ai/flux-pro/v1.1-ultra",
    fields: [
      promptField,
      {
        name: "aspect_ratio",
        label: "Aspect ratio",
        type: "select",
        defaultValue: "16:9",
        options: [
          { label: "16:9 — web hero", value: "16:9" },
          { label: "4:3 — MLS photo", value: "4:3" },
          { label: "1:1 — feed post", value: "1:1" },
          { label: "3:4 — portrait", value: "3:4" },
          { label: "9:16 — reel / story", value: "9:16" },
          { label: "21:9 — ultrawide banner", value: "21:9" },
        ],
      },
      numImagesField,
      {
        name: "raw",
        label: "Raw mode",
        type: "boolean",
        defaultValue: false,
        help: "Less stylised, more photographic. Usually what you want for real estate.",
      },
      { name: "seed", label: "Seed", type: "number" },
    ],
  },

  // --- Enhance ------------------------------------------------------------
  {
    id: "clarity-upscaler",
    endpointId: "fal-ai/clarity-upscaler",
    title: "Clarity upscaler",
    blurb:
      "Enlarges and sharpens a photo while inventing believable detail. Rescues soft or low-resolution shots.",
    category: "enhance",
    outputKind: "image",
    eta: "~20s",
    docsUrl: "https://fal.ai/models/fal-ai/clarity-upscaler",
    fields: [
      sourceImageField("The photo to enlarge. Larger inputs cost more and take longer."),
      {
        name: "upscale_factor",
        label: "Scale",
        type: "number",
        defaultValue: 2,
        min: 1,
        max: 4,
        step: 1,
      },
      {
        name: "creativity",
        label: "Creativity",
        type: "number",
        defaultValue: 0.35,
        min: 0,
        max: 1,
        step: 0.05,
        help: "How much new detail to invent. Keep it low on real listings so rooms stay truthful.",
      },
      {
        name: "prompt",
        label: "Guidance (optional)",
        type: "text",
        placeholder: "masterpiece, best quality, highly detailed",
        help: "Nudges what kind of detail gets added.",
      },
    ],
  },
  {
    id: "aura-sr",
    endpointId: "fal-ai/aura-sr",
    title: "AuraSR 4x",
    blurb:
      "Fast, faithful 4x upscale. Adds no new detail, so it is the safer choice for MLS delivery.",
    category: "enhance",
    outputKind: "image",
    eta: "~10s",
    docsUrl: "https://fal.ai/models/fal-ai/aura-sr",
    fields: [sourceImageField("The photo to enlarge 4x.")],
  },
  {
    id: "remove-background",
    endpointId: "fal-ai/birefnet",
    title: "Remove background",
    blurb: "Cuts the subject out and returns a transparent PNG. Useful for agent headshots and logos.",
    category: "enhance",
    outputKind: "image",
    eta: "~5s",
    docsUrl: "https://fal.ai/models/fal-ai/birefnet",
    fields: [sourceImageField("The image to cut out.")],
  },

  // --- Edit ---------------------------------------------------------------
  {
    id: "kontext-edit",
    endpointId: "fal-ai/flux-pro/kontext",
    title: "Instruction edit (Kontext)",
    blurb:
      "Edits a photo from a plain-English instruction while keeping the rest of the frame intact. Best tool for sky replacement and twilight conversion.",
    category: "edit",
    outputKind: "image",
    eta: "~15s",
    docsUrl: "https://fal.ai/models/fal-ai/flux-pro/kontext",
    fields: [
      sourceImageField("The listing photo to edit."),
      {
        name: "prompt",
        label: "Instruction",
        type: "textarea",
        required: true,
        placeholder: "Replace the overcast sky with a clear blue sky and warm late-afternoon light",
        help: "Say what should change. Anything you do not mention should stay as it is.",
      },
      {
        name: "guidance_scale",
        label: "Edit strength",
        type: "number",
        defaultValue: 3.5,
        min: 1,
        max: 10,
        step: 0.5,
        help: "Higher follows the instruction harder but drifts further from the original.",
      },
      { name: "seed", label: "Seed", type: "number" },
    ],
  },
  {
    id: "nano-banana-edit",
    endpointId: "fal-ai/nano-banana/edit",
    title: "Multi-image edit (Nano Banana)",
    blurb:
      "Edits using one or more reference images — combine a room photo with a furniture reference, or apply a look across shots.",
    category: "edit",
    outputKind: "image",
    eta: "~15s",
    docsUrl: "https://fal.ai/models/fal-ai/nano-banana/edit",
    fields: [
      {
        name: "image_urls",
        label: "Source images",
        type: "images",
        required: true,
        help: "The first image is the one being edited; the rest act as references.",
      },
      {
        name: "prompt",
        label: "Instruction",
        type: "textarea",
        required: true,
        placeholder: "Furnish this living room using the sofa and rug from the second image",
      },
    ],
  },

  // --- Stage --------------------------------------------------------------
  {
    id: "virtual-staging",
    endpointId: "fal-ai/flux-pro/kontext",
    title: "Virtual staging",
    blurb:
      "Furnishes an empty room. Same engine as instruction edit, pre-loaded with staging guidance so the architecture is preserved.",
    category: "stage",
    outputKind: "image",
    eta: "~15s",
    docsUrl: "https://fal.ai/models/fal-ai/flux-pro/kontext",
    fields: [
      sourceImageField("A photo of the empty room."),
      {
        name: "style",
        label: "Furnishing style",
        type: "select",
        defaultValue: "modern",
        options: [
          { label: "Modern", value: "modern" },
          { label: "Mid-century modern", value: "mid-century modern" },
          { label: "Scandinavian", value: "scandinavian" },
          { label: "Transitional", value: "transitional" },
          { label: "Coastal", value: "coastal" },
          { label: "Traditional", value: "traditional" },
          { label: "Industrial loft", value: "industrial loft" },
        ],
      },
      {
        name: "room",
        label: "Room type",
        type: "select",
        defaultValue: "living room",
        options: [
          { label: "Living room", value: "living room" },
          { label: "Primary bedroom", value: "primary bedroom" },
          { label: "Bedroom", value: "bedroom" },
          { label: "Dining room", value: "dining room" },
          { label: "Home office", value: "home office" },
          { label: "Kitchen", value: "kitchen" },
          { label: "Patio", value: "outdoor patio" },
        ],
      },
      {
        name: "notes",
        label: "Extra direction (optional)",
        type: "text",
        placeholder: "Keep the palette light and neutral, add a large area rug",
      },
    ],
  },

  // --- Video --------------------------------------------------------------
  {
    id: "kling-i2v",
    endpointId: "fal-ai/kling-video/v2/master/image-to-video",
    title: "Image to video (Kling 2 Master)",
    blurb:
      "Turns a still into a cinematic clip with real camera movement. The best-looking option for listing films.",
    category: "video",
    outputKind: "video",
    eta: "~3-5 min",
    docsUrl: "https://fal.ai/models/fal-ai/kling-video/v2/master/image-to-video",
    fields: [
      sourceImageField("The still to animate. A clean, well-lit frame gives the best motion."),
      {
        name: "prompt",
        label: "Motion direction",
        type: "textarea",
        required: true,
        placeholder: "Slow cinematic dolly forward through the living room, gentle parallax",
        help: "Describe the camera move, not the room. The room is already in the image.",
      },
      {
        name: "duration",
        label: "Duration",
        type: "select",
        defaultValue: "5",
        options: [
          { label: "5 seconds", value: "5" },
          { label: "10 seconds", value: "10" },
        ],
      },
      {
        name: "negative_prompt",
        label: "Avoid",
        type: "text",
        defaultValue: "blur, distort, warping walls, morphing furniture",
        help: "Artefacts to suppress. Warping architecture is the usual failure mode.",
      },
    ],
  },
  {
    id: "seedance-i2v",
    endpointId: "fal-ai/bytedance/seedance/v1/pro/image-to-video",
    title: "Image to video (Seedance Pro)",
    blurb: "Quicker and cheaper than Kling. Good for social cutdowns where the bar is lower.",
    category: "video",
    outputKind: "video",
    eta: "~2 min",
    docsUrl: "https://fal.ai/models/fal-ai/bytedance/seedance/v1/pro/image-to-video",
    fields: [
      sourceImageField("The still to animate."),
      {
        name: "prompt",
        label: "Motion direction",
        type: "textarea",
        required: true,
        placeholder: "Slow push in, soft handheld drift",
      },
      {
        name: "resolution",
        label: "Resolution",
        type: "select",
        defaultValue: "1080p",
        options: [
          { label: "1080p", value: "1080p" },
          { label: "720p — faster", value: "720p" },
        ],
      },
    ],
  },
];

export const CATEGORY_LABELS: Record<ModelCategory, string> = {
  generate: "Generate",
  enhance: "Enhance",
  edit: "Edit",
  stage: "Stage",
  video: "Video",
};

export const CATEGORY_ORDER: ModelCategory[] = [
  "generate",
  "enhance",
  "edit",
  "stage",
  "video",
];

export function getModel(id: string): ModelDef | undefined {
  return MODELS.find((model) => model.id === id);
}

/**
 * Builds the payload sent to fal from raw form values.
 *
 * Blank optional fields are dropped rather than sent as empty strings, so that
 * fal applies its own documented defaults instead of rejecting the request.
 */
export function buildInput(
  model: ModelDef,
  values: Record<string, unknown>,
): Record<string, unknown> {
  const input: Record<string, unknown> = { ...model.staticInput };

  for (const field of model.fields) {
    const value = values[field.name];
    if (value === undefined || value === null || value === "") continue;
    if (Array.isArray(value) && value.length === 0) continue;
    input[field.name] = value;
  }

  // The staging model is Kontext underneath: fold the three staging controls
  // into the single instruction the endpoint actually accepts.
  if (model.id === "virtual-staging") {
    const style = (values.style as string) ?? "modern";
    const room = (values.room as string) ?? "living room";
    const notes = ((values.notes as string) ?? "").trim();

    delete input.style;
    delete input.room;
    delete input.notes;

    input.prompt = [
      `Furnish this empty ${room} in a ${style} style with realistic, appropriately scaled furniture and decor.`,
      "Keep the room's architecture, windows, doors, flooring, wall colour, and camera angle exactly as they are.",
      "Match the existing lighting and shadows so the result looks photographed, not composited.",
      notes,
    ]
      .filter(Boolean)
      .join(" ");
  }

  return input;
}
