import Photos
import SwiftUI
import UniformTypeIdentifiers

/// Save to Photos, Share (PNG · PDF · SVG), Print and Copy. Any of them files the code in History.
struct ExportBar: View {
    var model: StudioModel
    @State private var confirmation: (message: LocalizedStringResource, success: Bool)?
    @State private var confirmations = 0
    @State private var working = false
    @State private var photosDenied = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await saveToPhotos() }
            } label: {
                Label("Save to Photos", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.primaryAction(Palette.tint(for: model.document.kind)))
            .disabled(model.scene == nil || working)

            shareMenu
            iconButton("Print", systemImage: "printer") { Task { await printCode() } }
            iconButton("Copy Image", systemImage: "doc.on.doc") { Task { await copyImage() } }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .top) {
            if let confirmation {
                StatusPill(
                    text: LocalizedStringKey(String(localized: confirmation.message)),
                    symbol: confirmation.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    tint: confirmation.success ? Palette.safe : Palette.danger
                )
                    .background(Color(.systemBackground), in: .capsule)
                    .offset(y: -40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sensoryFeedback(trigger: confirmations) { _, _ in confirmation?.success == false ? .error : .success }
        .alert("Allow Photos Access", isPresented: $photosDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Ojito can only add images to your library. Turn on access in Settings to save codes there.")
        }
    }

    @ViewBuilder
    private var shareMenu: some View {
        if let scene = model.scene {
            let name = model.document.title.isEmpty ? String(localized: "Code") : model.document.title
            let record: @MainActor @Sendable () -> Void = { [model] in model.recordCreation() }
            Menu {
                ShareLink(item: CodeExport<PNGFormat>(scene: scene, fileName: name, onExport: record), preview: SharePreview(name)) {
                    Label("Image (PNG)", systemImage: "photo")
                }
                ShareLink(item: CodeExport<PDFFormat>(scene: scene, fileName: name, onExport: record), preview: SharePreview(name)) {
                    Label("PDF (Vector)", systemImage: "doc.richtext")
                }
                ShareLink(item: CodeExport<SVGFormat>(scene: scene, fileName: name, onExport: record), preview: SharePreview(name)) {
                    Label("SVG (Vector)", systemImage: "square.on.circle")
                }
            } label: {
                circle(systemImage: "square.and.arrow.up")
            }
            .tint(.primary)
            .accessibilityLabel(Text("Share"))
        }
    }

    private func iconButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { circle(systemImage: systemImage) }
            .buttonStyle(.plain)
            .disabled(model.scene == nil || working)
            .accessibilityLabel(Text(title))
    }

    private func circle(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 54, height: 54)
            .background(.fill.secondary, in: .circle)
    }

    // MARK: Actions

    private func confirm(_ message: LocalizedStringResource, success: Bool = true) {
        withAnimation(.snappy) { confirmation = (message, success) }
        confirmations += 1
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.smooth) { confirmation = nil }
        }
    }

    private func saveToPhotos() async {
        guard let scene = model.scene else { return }
        working = true
        defer { working = false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            photosDenied = true
            return
        }
        let png = await ExportRenderer.png(scene)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: png, options: nil)
            }
            model.recordCreation()
            confirm("Saved to Photos")
        } catch {
            confirm("Couldn't save. Try again.", success: false)
        }
    }

    private func printCode() async {
        guard let scene = model.scene else { return }
        let pdf = await ExportRenderer.pdf(scene)
        let info = UIPrintInfo.printInfo()
        info.jobName = model.document.title
        info.outputType = .general
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItem = pdf
        controller.present(animated: true) { _, completed, _ in
            if completed { model.recordCreation() }
        }
    }

    private func copyImage() async {
        guard let scene = model.scene else { return }
        let png = await ExportRenderer.png(scene)
        UIPasteboard.general.setData(png, forPasteboardType: UTType.png.identifier)
        model.recordCreation()
        confirm("Copied")
    }
}
