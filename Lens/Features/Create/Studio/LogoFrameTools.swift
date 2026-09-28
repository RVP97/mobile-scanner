import PhotosUI
import SwiftUI

struct LogoTool: View {
    @Bindable var model: StudioModel
    @State private var photoItem: PhotosPickerItem?
    @State private var choosingPhoto = false
    @State private var loadingPhoto = false
    @State private var initials = ""
    @FocusState private var initialsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToolHeader("Logo")
            SwatchRow {
                ShapeSwatch(title: "None", isSelected: model.style.logo == .none) {
                    model.style.logo = .none
                } glyph: {
                    Image(systemName: "circle.slash").font(.title3).foregroundStyle(.secondary)
                }
                ShapeSwatch(title: model.document.kind.title, isSelected: model.style.logo == .kindGlyph) {
                    model.style.logo = .kindGlyph
                } glyph: {
                    Image(systemName: model.document.kind.symbol).font(.title3.weight(.semibold))
                }
                ShapeSwatch(title: "Photo", isSelected: isPhoto) {
                    choosingPhoto = true
                } glyph: {
                    if loadingPhoto {
                        ProgressView()
                    } else if case .photo(let data, let shape) = model.style.logo, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .clipShape(shape == .circle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 6, style: .continuous)))
                    } else {
                        Image(systemName: "photo").font(.title3)
                    }
                }
                ShapeSwatch(title: "Initials", isSelected: isInitials) {
                    model.style.logo = .initials(initials.isEmpty ? defaultInitials : initials)
                    initialsFocused = true
                } glyph: {
                    Text(verbatim: initialsPreview).font(.headline.weight(.bold)).minimumScaleFactor(0.5)
                }
            }

            if case .photo(let data, let shape) = model.style.logo {
                Picker("Crop", selection: Binding { shape } set: { model.style.logo = .photo(data, $0) }) {
                    Text("Circle").tag(CodeStyle.PhotoShape.circle)
                    Text("Rounded").tag(CodeStyle.PhotoShape.rounded)
                }
                .pickerStyle(.segmented)
            }
            if isInitials {
                TextField("Initials", text: $initials)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($initialsFocused)
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12, style: .continuous))
                    .onChange(of: initials) { _, value in
                        let trimmed = String(value.prefix(3))
                        if trimmed != value { initials = trimmed }
                        model.style.logo = .initials(trimmed.isEmpty ? defaultInitials : trimmed)
                    }
            }
            Text("A logo keeps a clear zone around it and switches error correction to High, so the code still reads.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .photosPicker(isPresented: $choosingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .onAppear {
            if case .initials(let value) = model.style.logo { initials = value }
        }
    }

    private var isPhoto: Bool {
        if case .photo = model.style.logo { true } else { false }
    }

    private var isInitials: Bool {
        if case .initials = model.style.logo { true } else { false }
    }

    private var initialsPreview: String {
        if case .initials(let value) = model.style.logo { value } else { defaultInitials }
    }

    /// "Casa Chen" → "CC".
    private var defaultInitials: String {
        let letters = model.document.title.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "A" : String(letters).uppercased()
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        loadingPhoto = true
        defer { loadingPhoto = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let prepared = await Self.prepare(data) else { return }
        model.style.logo = .photo(prepared, .circle)
    }

    @concurrent
    private static func prepare(_ data: Data) async -> Data? {
        LogoImages.preparePhoto(data)
    }
}

struct FrameTool: View {
    @Bindable var model: StudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToolHeader("Frame")
            SwatchRow {
                ForEach(CodeStyle.Frame.allCases, id: \.self) { frame in
                    ShapeSwatch(title: frame.title, isSelected: model.style.frame == frame) {
                        model.style.frame = frame
                    } glyph: {
                        FrameGlyph(frame: frame)
                    }
                }
            }

            ToolHeader("Caption")
                .padding(.top, 4)
            HStack(spacing: 12) {
                TextField("Scan to join", text: $model.style.caption)
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12, style: .continuous))
                Menu {
                    Picker("Weight", selection: $model.style.captionWeight) {
                        ForEach(CodeStyle.CaptionWeight.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } label: {
                    Image(systemName: "bold")
                        .frame(width: 44, height: 44)
                        .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12, style: .continuous))
                }
                .accessibilityLabel(Text("Caption weight"))
            }
            .disabled(model.style.frame == .none)
            .opacity(model.style.frame == .none ? 0.5 : 1)
            if model.style.frame == .none {
                Text("Pick a frame to add a caption.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if model.isLinear {
                Toggle("Show digits under the bars", isOn: $model.style.showsText)
                    .padding(.top, 4)
            }
        }
    }
}

/// Tiny pictogram of each frame style.
private struct FrameGlyph: View {
    var frame: CodeStyle.Frame

    var body: some View {
        switch frame {
        case .none:
            Image(systemName: "qrcode").font(.title3)
        case .card:
            VStack(spacing: 3) {
                Image(systemName: "qrcode").font(.system(size: 16))
                Capsule().frame(width: 18, height: 3)
            }
            .padding(5)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.5), lineWidth: 1))
        case .badge:
            VStack(spacing: 0) {
                Image(systemName: "qrcode").font(.system(size: 15))
                    .padding(3)
                    .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 3))
                Capsule().fill(Color(.tertiarySystemGroupedBackground)).frame(width: 14, height: 2.5).padding(.vertical, 2)
            }
            .padding(2)
            .background(.primary, in: .rect(cornerRadius: 6))
        case .poster:
            VStack(spacing: 3) {
                Capsule().frame(width: 18, height: 3)
                Image(systemName: "qrcode").font(.system(size: 14))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.primary.opacity(0.5), lineWidth: 1))
        }
    }
}
