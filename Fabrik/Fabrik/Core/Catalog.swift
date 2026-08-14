import Foundation

// MARK: - Schema

enum FieldType: Equatable, Hashable, Sendable {
    case text
    case multilineText
    case picker
    case number
    case toggle
    case image
    case images
}

struct FieldOption: Identifiable, Hashable, Sendable {
    var value: String
    var label: String
    var id: String { value }
}

/// One control in a model's input form.
///
/// `name` is sent to fal verbatim, so it must match the model's documented
/// input schema exactly.
struct Field: Identifiable, Sendable {
    var name: String
    var label: String
    var type: FieldType
    var help: String?
    var isRequired: Bool = false
    var placeholder: String?
    var defaultValue: JSONValue?
    var options: [FieldOption] = []
    /// When min/max/step are all set, a `number` field renders as a slider.
    var minimum: Double?
    var maximum: Double?
    var step: Double?

    var id: String { name }

    var isSlider: Bool { minimum != nil && maximum != nil && step != nil }
    var isFileField: Bool { type == .image || type == .images }
}

enum ModelCategory: String, CaseIterable, Identifiable, Sendable {
    case generate, enhance, edit, stage, video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .generate: return "Generate"
        case .enhance: return "Enhance"
        case .edit: return "Edit"
        case .stage: return "Stage"
        case .video: return "Video"
        }
    }

    var symbol: String {
        switch self {
        case .generate: return "sparkles"
        case .enhance: return "wand.and.stars"
        case .edit: return "slider.horizontal.3"
        case .stage: return "sofa"
        case .video: return "film"
        }
    }
}

struct FalModel: Identifiable, Sendable {
    var id: String
    var endpointId: String
    var title: String
    var blurb: String
    var category: ModelCategory
    var outputKind: OutputKind
    var eta: String?
    var docsURL: URL?
    var fields: [Field]
    var staticInput: [String: JSONValue] = [:]
}

// MARK: - Catalogue

/// Everything Fabrik can do, as plain data.
///
/// The sidebar, the input form, and validation are all generated from this, so
/// adding a model is one entry here with no UI changes.
///
/// Two things to know when editing:
///
///  1. Each `name` is sent to fal verbatim, so it has to match that model's
///     documented input schema. Check the model's page on fal.ai (`docsURL`)
///     before changing one.
///  2. Endpoint ids and their schemas change as fal ships new versions. If a
///     model starts returning a validation error, compare it against its fal
///     page and correct the entry here.
enum Catalog {
    static let models: [FalModel] = [
        // MARK: Generate

        FalModel(
            id: "flux-dev",
            endpointId: "fal-ai/flux/dev",
            title: "FLUX.1 [dev]",
            blurb: "Strong general-purpose text-to-image. Good default for marketing graphics and social backgrounds.",
            category: .generate,
            outputKind: .image,
            eta: "~10s",
            docsURL: URL(string: "https://fal.ai/models/fal-ai/flux/dev"),
            fields: [
                .prompt,
                .imageSize,
                .numImages,
                Field(
                    name: "num_inference_steps",
                    label: "Steps",
                    type: .number,
                    help: "More steps means more detail and more time. 28 is a sensible middle.",
                    defaultValue: .int(28),
                    minimum: 1, maximum: 50, step: 1
                ),
                Field(
                    name: "guidance_scale",
                    label: "Prompt adherence",
                    type: .number,
                    help: "Higher sticks closer to the prompt; lower gives the model more freedom.",
                    defaultValue: .double(3.5),
                    minimum: 1, maximum: 10, step: 0.5
                ),
                .seed,
            ]
        ),

        FalModel(
            id: "flux-pro-ultra",
            endpointId: "fal-ai/flux-pro/v1.1-ultra",
            title: "FLUX1.1 [pro] ultra",
            blurb: "Highest-fidelity text-to-image in the catalogue. Use it for hero and print work.",
            category: .generate,
            outputKind: .image,
            eta: "~15s",
            docsURL: URL(string: "https://fal.ai/models/fal-ai/flux-pro/v1.1-ultra"),
            fields: [
                .prompt,
                Field(
                    name: "aspect_ratio",
                    label: "Aspect ratio",
                    type: .picker,
                    defaultValue: .string("16:9"),
                    options: [
                        FieldOption(value: "16:9", label: "16:9 — web hero"),
                        FieldOption(value: "4:3", label: "4:3 — MLS photo"),
                        FieldOption(value: "1:1", label: "1:1 — feed post"),
                        FieldOption(value: "3:4", label: "3:4 — portrait"),
                        FieldOption(value: "9:16", label: "9:16 — reel / story"),
                        FieldOption(value: "21:9", label: "21:9 — ultrawide banner"),
                    ]
                ),
                .numImages,
                Field(
                    name: "raw",
                    label: "Raw mode",
                    type: .toggle,
                    help: "Less stylised, more photographic. Usually what you want for property work.",
                    defaultValue: .bool(false)
                ),
                .seed,
            ]
        ),

        FalModel(
            id: "nano-banana",
            endpointId: "fal-ai/nano-banana",
            title: "Nano Banana",
            blurb: "Google's fast, cheap text-to-image (Gemini 2.5 Flash Image). Great for quick drafts and social volume at ~$0.04 per image.",
            category: .generate,
            outputKind: .image,
            eta: "~5s",
            docsURL: URL(string: "https://fal.ai/models/fal-ai/nano-banana"),
            fields: [
                .prompt,
                .nanoAspectRatio,
                .numImages,
                .seed,
            ]
        ),

        FalModel(
            id: "nano-banana-pro",
            endpointId: "fal-ai/nano-banana-pro",
            title: "Nano Banana Pro",
            blurb: "Google's flagship image model (Gemini 3 Pro Image). Legible text in images, up to 4K, strong scene logic. ~$0.15 per image, 4K doubles it.",
            category: .generate,
            outputKind: .image,
            eta: "~15s",
            docsURL: URL(string: "https://fal.ai/models/fal-ai/nano-banana-pro"),
            fields: [
                .prompt,
                .nanoAspectRatio,
                .nanoResolution,
                .numImages,
                .seed,
            ]
        ),

        // MARK: Enhance

        FalModel(
            id: "clarity-upscaler",
            endpointId: "fal-ai/clarity-upscaler",
            title: "Clarity upscaler",
            blurb: "Enlarges and sharpens a photo while inventing believable detail. Rescues soft or low-resolution shots.",
            category: .enhance,
            outputKind: .image,
            eta: "~20s",
            docsURL: URL(string: "https://fal.ai/models/fal-ai/clarity-upscaler"),
            fields: [
                .sourceImage("The photo to enlarge. Larger inputs cost more and take longer."),
                Field(
                    name: "upscale_factor",
                    label: "Scale",
                    type: .number,
                    defaultValue: .int(2),
                    minimum: 1, maximum: 4, step: 1
                ),
                Field(
                    name: "creativity",
                    label: "Creativity",
                    type: .number,
                    help: "How much new detail to invent. Keep it low on real listings so rooms stay truthful.",
                    defaultValue: .double(0.35),
                    minimum: 0, maximum: 1, step: 0.05
                ),
                Field(
                    name: "prompt",
                    label: "Guidance (optional)",
                    type: .text,
                    help: "Nudges what kind of detail gets added.",
                    placeholder: "masterpiece, best quality, highly detailed"
                ),
            ]
        ),

        FalModel(
            id: "aura-sr",
            endpointId: "fal-ai/aura-sr",
            title: "AuraSR 4x",
            blurb: "Fast, faithful 4x upscale. Adds no new detail, so it is the safer choice for MLS delivery.",
            category: .enhance,
            outputKind: .image,
            eta: "~10s",
            docsURL: URL(string: "https://fal.ai/models/fal-ai/aura-sr"),
            fields: [.sourceImage("The photo to enlarge 4x.")]
        ),

        FalModel(
            id: "remove-background",
            endpointId: "fal-ai/birefnet",
            title: "Remove background",
            blurb: "Cuts the subject out and returns a transparent PNG. Useful for headshots and logos.",
            category: .enhance,
            outputKind: .image,
            eta: "~5s",
            docsURL: URL(string: "https://fal.ai/models/fal-ai/birefnet"),
            fields: [.sourceImage("The image to cut out.")]
        ),

        // MARK: Edit

        FalModel(
            id: "kontext-edit",
            endpointId: "fal-ai/flux-pro/kontext",
            title: "Instruction edit (Kontext)",
            blurb: "Edits a photo from a plain-English instruction while keeping the rest of the frame intact. Best tool for sky replacement and twilight conversion.",
            category: .edit,
            outputKind: .image,
            eta: "~15s",
            docsURL: URL(string: "https://fal.ai/models/fal-ai/flux-pro/kontext"),
            fields: [
                .sourceImage("The photo to edit."),
                Field(
                    name: "prompt",
                    label: "Instruction",
                    type: .multilineText,
                    help: "Say what should change. Anything you do not mention should stay as it is.",
                    isRequired: true,
                    placeholder: "Replace the overcast sky with a clear blue sky and warm late-afternoon light"
                ),
                Field(
                    name: "guidance_scale",
                    label: "Edit strength",
                    type: .number,
                    help: "Higher follows the instruction harder but drifts further from the original.",
                    defaultValue: .double(3.5),
                    minimum: 1, maximum: 10, step: 0.5
                ),
                .seed,
            ]
        ),

        FalModel(
            id: "nano-banana-edit",
            endpointId: "fal-ai/nano-banana/edit",
            title: "Multi-image edit (Nano Banana)",
            blurb: "Edits using one or more reference images — combine a room photo with a furniture reference, or apply a look across shots.",
            category: .edit,
            outputKind: .image,
            eta: "~15s",
            docsURL: URL(string: "https://fal.ai/models/fal-ai/nano-banana/edit"),
            fields: [
                Field(
                    name: "image_urls",
                    label: "Source images",
                    type: .images,
                    help: "The first image is the one being edited; the rest act as references.",
                    isRequired: true
                ),
                Field(
                    name: "prompt",
                    label: "Instruction",
                    type: .multilineText,
                    isRequired: true,
                    placeholder: "Furnish this living room using the sofa and rug from the second image"
                ),
            ]
        ),

        FalModel(
            id: "nano-banana-pro-edit",
            endpointId: "fal-ai/nano-banana-pro/edit",
            title: "Multi-image edit (Nano Banana Pro)",
            blurb: "The strongest editor in the catalogue: up to ~14 reference images, 4K output, and reliable text rendering. ~$0.15 per image.",
            category: .edit,
            outputKind: .image,
            eta: "~20s",
            docsURL: URL(string: "https://fal.ai/models/fal-ai/nano-banana-pro/edit"),
            fields: [
                Field(
                    name: "image_urls",
                    label: "Source images",
                    type: .images,
                    help: "The first image is the one being edited; the rest act as references.",
                    isRequired: true
                ),
                Field(
                    name: "prompt",
                    label: "Instruction",
                    type: .multilineText,
                    isRequired: true,
                    placeholder: "Restyle this living room to match the mood board in the second image"
                ),
                .nanoResolution,
                .seed,
            ]
        ),

        // MARK: Stage

        FalModel(
            id: "virtual-staging",
            endpointId: "fal-ai/flux-pro/kontext",
            title: "Virtual staging",
            blurb: "Furnishes an empty room. Same engine as instruction edit, pre-loaded with staging guidance so the architecture is preserved.",
            category: .stage,
            outputKind: .image,
            eta: "~15s",
            docsURL: URL(string: "https://fal.ai/models/fal-ai/flux-pro/kontext"),
            fields: [
                .sourceImage("A photo of the empty room."),
                Field(
                    name: "style",
                    label: "Furnishing style",
                    type: .picker,
                    defaultValue: .string("modern"),
                    options: [
                        FieldOption(value: "modern", label: "Modern"),
                        FieldOption(value: "mid-century modern", label: "Mid-century modern"),
                        FieldOption(value: "scandinavian", label: "Scandinavian"),
                        FieldOption(value: "transitional", label: "Transitional"),
                        FieldOption(value: "coastal", label: "Coastal"),
                        FieldOption(value: "traditional", label: "Traditional"),
                        FieldOption(value: "industrial loft", label: "Industrial loft"),
                    ]
                ),
                Field(
                    name: "room",
                    label: "Room type",
                    type: .picker,
                    defaultValue: .string("living room"),
                    options: [
                        FieldOption(value: "living room", label: "Living room"),
                        FieldOption(value: "primary bedroom", label: "Primary bedroom"),
                        FieldOption(value: "bedroom", label: "Bedroom"),
                        FieldOption(value: "dining room", label: "Dining room"),
                        FieldOption(value: "home office", label: "Home office"),
                        FieldOption(value: "kitchen", label: "Kitchen"),
                        FieldOption(value: "outdoor patio", label: "Patio"),
                    ]
                ),
                Field(
                    name: "notes",
                    label: "Extra direction (optional)",
                    type: .text,
                    placeholder: "Keep the palette light and neutral, add a large area rug"
                ),
            ]
        ),

        // MARK: Video

        FalModel(
            // Keeps the v2-era id so "Re-run" on older library entries still
            // resolves. Note the v3 schema renamed the image field:
            // `start_image_url`, not `image_url`.
            id: "kling-i2v",
            endpointId: "fal-ai/kling-video/v3/pro/image-to-video",
            title: "Image to video (Kling 3 Pro)",
            blurb: "Turns a still into a cinematic clip with real camera movement and native audio. The best-looking option for listing films. ~$0.11/s silent, ~$0.17/s with audio.",
            category: .video,
            outputKind: .video,
            eta: "~3-5 min",
            docsURL: URL(string: "https://fal.ai/models/fal-ai/kling-video/v3/pro/image-to-video"),
            fields: [
                Field(
                    name: "start_image_url",
                    label: "Source image",
                    type: .image,
                    help: "The still to animate. A clean, well-lit frame gives the best motion.",
                    isRequired: true
                ),
                Field(
                    name: "prompt",
                    label: "Motion direction",
                    type: .multilineText,
                    help: "Describe the camera move, not the room. Optional, but strongly recommended.",
                    placeholder: "Slow cinematic dolly forward through the living room, gentle parallax"
                ),
                Field(
                    name: "duration",
                    label: "Duration",
                    type: .picker,
                    defaultValue: .string("5"),
                    options: (3...15).map { FieldOption(value: String($0), label: "\($0) seconds") }
                ),
                Field(
                    name: "generate_audio",
                    label: "Generate audio",
                    type: .toggle,
                    help: "Ambient sound generated with the clip. Turning it off is ~35% cheaper.",
                    defaultValue: .bool(true)
                ),
                Field(
                    name: "aspect_ratio",
                    label: "Aspect ratio",
                    type: .picker,
                    defaultValue: .string("16:9"),
                    options: [
                        FieldOption(value: "16:9", label: "16:9 — listing film"),
                        FieldOption(value: "9:16", label: "9:16 — reel / story"),
                        FieldOption(value: "1:1", label: "1:1 — feed post"),
                    ]
                ),
                Field(
                    name: "end_image_url",
                    label: "End frame (optional)",
                    type: .image,
                    help: "Give the clip a destination — useful for room-to-room transitions."
                ),
                Field(
                    name: "negative_prompt",
                    label: "Avoid",
                    type: .text,
                    help: "Artefacts to suppress. Warping architecture is the usual failure mode.",
                    defaultValue: .string("blur, distort, warping walls, morphing furniture")
                ),
                Field(
                    name: "cfg_scale",
                    label: "Prompt adherence",
                    type: .number,
                    help: "Higher sticks closer to the motion direction; lower gives Kling more freedom.",
                    defaultValue: .double(0.5),
                    minimum: 0, maximum: 1, step: 0.05
                ),
            ]
        ),

        FalModel(
            id: "seedance-i2v",
            endpointId: "fal-ai/bytedance/seedance/v1/pro/image-to-video",
            title: "Image to video (Seedance Pro)",
            blurb: "Quicker and cheaper than Kling. Good for social cutdowns where the bar is lower.",
            category: .video,
            outputKind: .video,
            eta: "~2 min",
            docsURL: URL(string: "https://fal.ai/models/fal-ai/bytedance/seedance/v1/pro/image-to-video"),
            fields: [
                .sourceImage("The still to animate."),
                Field(
                    name: "prompt",
                    label: "Motion direction",
                    type: .multilineText,
                    isRequired: true,
                    placeholder: "Slow push in, soft handheld drift"
                ),
                Field(
                    name: "resolution",
                    label: "Resolution",
                    type: .picker,
                    defaultValue: .string("1080p"),
                    options: [
                        FieldOption(value: "1080p", label: "1080p"),
                        FieldOption(value: "720p", label: "720p — faster"),
                    ]
                ),
            ]
        ),
    ]

    static func model(id: String) -> FalModel? {
        models.first { $0.id == id }
    }

    static func models(in category: ModelCategory) -> [FalModel] {
        models.filter { $0.category == category }
    }
}

// MARK: - Reusable fields

extension Field {
    static let prompt = Field(
        name: "prompt",
        label: "Prompt",
        type: .multilineText,
        help: "Describe the finished image. Specific nouns and lighting beat long adjective lists.",
        isRequired: true,
        placeholder: "A sunlit modern kitchen with white oak cabinetry, marble waterfall island, and floor-to-ceiling windows"
    )

    static let imageSize = Field(
        name: "image_size",
        label: "Aspect ratio",
        type: .picker,
        defaultValue: .string("landscape_4_3"),
        options: [
            FieldOption(value: "landscape_4_3", label: "Landscape 4:3 — MLS photo"),
            FieldOption(value: "landscape_16_9", label: "Landscape 16:9 — web hero"),
            FieldOption(value: "square_hd", label: "Square 1:1 — feed post"),
            FieldOption(value: "portrait_4_3", label: "Portrait 3:4"),
            FieldOption(value: "portrait_16_9", label: "Portrait 9:16 — reel / story"),
        ]
    )

    static let numImages = Field(
        name: "num_images",
        label: "How many",
        type: .number,
        help: "Each image is billed separately.",
        defaultValue: .int(1),
        minimum: 1, maximum: 4, step: 1
    )

    static let seed = Field(
        name: "seed",
        label: "Seed",
        type: .number,
        help: "Leave blank for a new result each time. Reuse a seed to reproduce one."
    )

    /// Aspect ratios shared by the Nano Banana family.
    static let nanoAspectRatio = Field(
        name: "aspect_ratio",
        label: "Aspect ratio",
        type: .picker,
        defaultValue: .string("4:3"),
        options: [
            FieldOption(value: "4:3", label: "4:3 — MLS photo"),
            FieldOption(value: "16:9", label: "16:9 — web hero"),
            FieldOption(value: "1:1", label: "1:1 — feed post"),
            FieldOption(value: "3:4", label: "3:4 — portrait"),
            FieldOption(value: "9:16", label: "9:16 — reel / story"),
            FieldOption(value: "21:9", label: "21:9 — ultrawide banner"),
        ]
    )

    /// Output resolution for Nano Banana Pro endpoints. 4K bills at 2x.
    static let nanoResolution = Field(
        name: "resolution",
        label: "Resolution",
        type: .picker,
        defaultValue: .string("1K"),
        options: [
            FieldOption(value: "1K", label: "1K"),
            FieldOption(value: "2K", label: "2K"),
            FieldOption(value: "4K", label: "4K — costs 2x"),
        ]
    )

    static func sourceImage(_ help: String) -> Field {
        Field(
            name: "image_url",
            label: "Source image",
            type: .image,
            help: help,
            isRequired: true
        )
    }
}

// MARK: - Payload assembly

enum InputBuilder {
    /// Turns raw form values into the payload sent to fal.
    ///
    /// Empty optional fields are dropped rather than sent as empty strings, so
    /// fal applies its own documented defaults instead of rejecting the request.
    static func build(model: FalModel, values: [String: JSONValue]) -> [String: JSONValue] {
        var input = model.staticInput

        for field in model.fields {
            guard let value = values[field.name] else { continue }
            switch value {
            case .null: continue
            case .string(let text) where text.isEmpty: continue
            case .array(let items) where items.isEmpty: continue
            default: break
            }

            // Single-image fields are edited as arrays (the picker works in
            // lists) but fal expects one plain URL string for them.
            if field.type == .image, let first = value.arrayValue?.first {
                input[field.name] = first
            } else {
                input[field.name] = value
            }
        }

        // Virtual staging is Kontext underneath: fold its three staging controls
        // into the single instruction the endpoint actually accepts.
        if model.id == "virtual-staging" {
            let style = values["style"]?.stringValue ?? "modern"
            let room = values["room"]?.stringValue ?? "living room"
            let notes = (values["notes"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            input.removeValue(forKey: "style")
            input.removeValue(forKey: "room")
            input.removeValue(forKey: "notes")

            let sentences = [
                "Furnish this empty \(room) in a \(style) style with realistic, appropriately scaled furniture and decor.",
                "Keep the room's architecture, windows, doors, flooring, wall colour, and camera angle exactly as they are.",
                "Match the existing lighting and shadows so the result looks photographed, not composited.",
                notes,
            ].filter { !$0.isEmpty }

            input["prompt"] = .string(sentences.joined(separator: " "))
        }

        return input
    }

    /// Fields the user still has to fill in.
    static func missingRequired(model: FalModel, values: [String: JSONValue]) -> [Field] {
        model.fields.filter { field in
            guard field.isRequired else { return false }
            guard let value = values[field.name] else { return true }
            switch value {
            case .null: return true
            case .string(let text): return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .array(let items): return items.isEmpty
            default: return false
            }
        }
    }

    /// Starting values for a model's form, optionally seeded from a past run.
    static func initialValues(model: FalModel, prefill: [String: JSONValue]? = nil) -> [String: JSONValue] {
        var values: [String: JSONValue] = [:]

        for field in model.fields {
            switch field.type {
            case .image, .images:
                values[field.name] = .array([])
            case .toggle:
                values[field.name] = field.defaultValue ?? .bool(false)
            default:
                values[field.name] = field.defaultValue ?? .string("")
            }

            guard let incoming = prefill?[field.name] else { continue }

            switch field.type {
            case .image:
                // Stored as a single URL string; the editor works in arrays.
                if let url = incoming.stringValue {
                    values[field.name] = JSONValue.array([JSONValue.string(url)])
                } else {
                    values[field.name] = JSONValue.array([])
                }
            case .images:
                values[field.name] = JSONValue.array(incoming.arrayValue ?? [])
            default:
                values[field.name] = incoming
            }
        }

        return values
    }
}
