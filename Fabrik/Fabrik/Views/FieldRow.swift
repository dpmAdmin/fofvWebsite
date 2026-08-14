import SwiftUI

/// Renders one catalogue `Field` as the appropriate control.
///
/// Everything here is driven by the field's declaration, so adding a model to
/// `Catalog` needs no changes in this file.
struct FieldRow: View {
    let field: Field

    @Environment(StudioModel.self) private var studio

    private var isMissing: Bool {
        studio.showValidation && studio.missingFields.contains { $0.name == field.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text(field.label)
                    .font(.subheadline.weight(.semibold))
                if field.isRequired {
                    Text("*").foregroundStyle(Theme.accent)
                }
            }

            control

            if let help = field.help {
                Text(help)
                    .font(.caption2)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isMissing {
                Text("\(field.label) is required.")
                    .font(.caption2)
                    .foregroundStyle(Theme.danger)
            }
        }
    }

    @ViewBuilder
    private var control: some View {
        switch field.type {
        case .text:
            TextField(field.placeholder ?? "", text: stringBinding)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 8))
                .overlay(border)
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif

        case .multilineText:
            TextEditor(text: stringBinding)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 88)
                .padding(6)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 8))
                .overlay(border)
                .overlay(alignment: .topLeading) {
                    // TextEditor has no placeholder of its own.
                    if stringBinding.wrappedValue.isEmpty, let placeholder = field.placeholder {
                        Text(placeholder)
                            .font(.body)
                            .foregroundStyle(Theme.textFaint)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }

        case .picker:
            Picker(field.label, selection: stringBinding) {
                ForEach(field.options) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Theme.text)

        case .toggle:
            Toggle(isOn: boolBinding) {
                Text("Enabled").font(.subheadline).foregroundStyle(Theme.textDim)
            }
            .toggleStyle(.switch)

        case .number:
            if field.isSlider,
               let minimum = field.minimum,
               let maximum = field.maximum,
               let step = field.step {
                HStack(spacing: 12) {
                    Slider(value: doubleBinding, in: minimum...maximum, step: step)
                    Text(formatted(doubleBinding.wrappedValue, step: step))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 46, alignment: .trailing)
                }
            } else {
                TextField(field.placeholder ?? "auto", text: numberTextBinding)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(border)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }

        case .image, .images:
            ImageField(field: field)
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isMissing ? Theme.danger : Theme.hairline, lineWidth: 1)
    }

    /// Trims trailing zeros for whole-number steps so sliders read "2" not "2.0".
    private func formatted(_ value: Double, step: Double) -> String {
        if step >= 1, value == value.rounded() { return String(Int(value)) }
        return String(format: "%.2f", value)
            .replacingOccurrences(of: "0$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }

    // MARK: - Bindings
    //
    // Values live in a loosely-typed `[String: JSONValue]` because fal's inputs
    // vary per model, so each control gets a small typed view onto that store.

    private var stringBinding: Binding<String> {
        Binding(
            get: { studio.values[field.name]?.stringValue ?? "" },
            set: { studio.values[field.name] = .string($0) }
        )
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: {
                if case .bool(let value) = studio.values[field.name] ?? .null { return value }
                return false
            },
            set: { studio.values[field.name] = .bool($0) }
        )
    }

    private var doubleBinding: Binding<Double> {
        Binding(
            get: {
                switch studio.values[field.name] ?? .null {
                case .int(let value): return Double(value)
                case .double(let value): return value
                default: return field.minimum ?? 0
                }
            },
            set: { newValue in
                // Keep integral steps integral so fal receives 2 rather than 2.0.
                if let step = field.step, step >= 1 {
                    studio.values[field.name] = .int(Int(newValue.rounded()))
                } else {
                    studio.values[field.name] = .double(newValue)
                }
            }
        )
    }

    /// Free-entry numbers (seed) stay text so the field can be left blank,
    /// which makes fal apply its own default instead of receiving 0.
    private var numberTextBinding: Binding<String> {
        Binding(
            get: {
                switch studio.values[field.name] ?? .null {
                case .int(let value): return String(value)
                case .double(let value): return String(value)
                case .string(let value): return value
                default: return ""
                }
            },
            set: { text in
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    studio.values[field.name] = .string("")
                } else if let intValue = Int(trimmed) {
                    studio.values[field.name] = .int(intValue)
                } else if let doubleValue = Double(trimmed) {
                    studio.values[field.name] = .double(doubleValue)
                } else {
                    studio.values[field.name] = .string(trimmed)
                }
            }
        )
    }
}
