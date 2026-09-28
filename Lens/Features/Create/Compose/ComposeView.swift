import SwiftUI

/// Fill in what the code holds, with a live preview and inline guidance, then continue to styling.
struct ComposeView: View {
    @State private var draft: CreateDraft

    init(draft: CreateDraft) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        let outcome = draft.outcome
        Form {
            Section {
                ComposePreview(document: outcome.document, kind: draft.kind)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            fields

            if draft.intent != .product {
                formatSection(outcome)
            } else if let issue = outcome.issues.first(where: { $0.field == .capacity }) {
                Section { IssueRow(issue: issue) }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            continueBar(outcome.document)
        }
    }

    private var title: Text {
        if let intent = draft.intent { Text(intent.title) } else { Text(draft.format.displayName) }
    }

    @ViewBuilder
    private var fields: some View {
        switch draft.intent {
        case .link: LinkFields(draft: draft)
        case .wifi: WiFiFields(draft: draft)
        case .contact: ContactFields(draft: draft)
        case .text: TextFields(draft: draft)
        case .email: EmailFields(draft: draft)
        case .sms: MessageFields(draft: draft)
        case .phone: PhoneFields(draft: draft)
        case .event: EventFields(draft: draft)
        case .location: LocationFields(draft: draft)
        case .product: ProductFields(draft: draft)
        case nil: AdvancedFields(draft: draft)
        }
    }

    @ViewBuilder
    private func formatSection(_ outcome: CreateDraft.Outcome) -> some View {
        if let intent = draft.intent {
            Section {
                Picker("Format", selection: $draft.format) {
                    ForEach(intent.formats) { Text($0.displayName).tag($0) }
                }
                if let issue = outcome.issues.first(where: { $0.field == .capacity }) {
                    IssueRow(issue: issue)
                }
            } footer: {
                Text("QR codes work with every phone camera. Pick another format only if something asks for it.")
            }
        } else if let issue = outcome.issues.first(where: { $0.field == .capacity }) {
            Section { IssueRow(issue: issue) }
        }
    }

    private func continueBar(_ document: CodeDocument?) -> some View {
        NavigationLink(value: document.map(CreateRoute.studio)) {
            Text("Continue")
        }
        .buttonStyle(.primaryAction(Palette.tint(for: draft.kind)))
        .disabled(document == nil)
        .opacity(document == nil ? 0.45 : 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: 640)
        .background(Color(.systemGroupedBackground))
    }
}

/// Small live rendering above the form, so every keystroke visibly becomes a code.
private struct ComposePreview: View {
    var document: CodeDocument?
    var kind: CodeKind

    var body: some View {
        ZStack {
            if let document, let scene = CodeRenderer.plainScene(raw: document.raw, symbology: document.symbology) {
                Canvas { context, size in
                    context.withCGContext { SceneRenderer.draw(scene, in: $0, rect: CGRect(origin: .zero, size: size)) }
                }
                .padding(12)
                .background(.white, in: .rect(cornerRadius: 16, style: .continuous))
                .transition(.opacity)
                .accessibilityLabel(Text("Preview of the \(document.symbology.displayName) for \(document.title)"))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .overlay {
                        VStack(spacing: 8) {
                            KindTile(kind: kind, size: 36)
                            Text("Your code appears here")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
            }
        }
        .frame(width: 168, height: 168)
        .frame(maxWidth: .infinity)
        .animation(.smooth(duration: 0.25), value: document == nil)
    }
}

/// Inline, human validation message with an optional one-tap fix.
struct IssueRow: View {
    var issue: DraftIssue

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label {
                Text(issue.message)
            } icon: {
                Image(systemName: "exclamationmark.circle.fill")
            }
            .font(.footnote)
            .foregroundStyle(Palette.danger)
            Spacer(minLength: 8)
            if let title = issue.fixTitle, let fix = issue.fix {
                Button(action: fix) { Text(title) }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderless)
            }
        }
    }
}

/// Neutral "Lunet did this for you" note (check digits, start/stop letters).
struct NoteRow: View {
    var note: LocalizedStringResource

    var body: some View {
        Label {
            Text(note)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
        }
        .font(.footnote)
        .foregroundStyle(Palette.safe)
    }
}

#Preview("Wi-Fi") {
    NavigationStack {
        ComposeView(draft: {
            let draft = CreateDraft(intent: .wifi)
            draft.wifi = WiFiNetwork(ssid: "Casa Chen", password: "correct horse")
            return draft
        }())
    }
}

#Preview("Product") {
    NavigationStack {
        ComposeView(draft: {
            let draft = CreateDraft(intent: .product)
            draft.product = "4006381333930"
            return draft
        }())
    }
}
