import StoreKit
import SwiftData
import SwiftUI

/// Home: the person's codes, their recent scans, and the Scan lens in the thumb zone. The camera
/// isn't running here; it opens from the lens.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @AppStorage(Pref.requireFaceID) private var requireFaceID = Pref.Default.requireFaceID
    @AppStorage(Pref.successfulScans) private var successfulScans = 0
    @AppStorage(Pref.lastReviewPromptScans) private var lastReviewPromptScans = 0
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Reads codes from photos picked on Home.
    @State private var importer = ScanCoordinator()
    private let lock = HistoryLock.shared

    private var isLocked: Bool { requireFaceID && !lock.isUnlocked }

    /// Nothing is covering Home.
    private var isFrontmost: Bool {
        !model.isScannerPresented && model.sheet == nil && model.modal == nil && model.codeOnDisplay == nil
            && model.path.isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                if isWide(proxy.size) {
                    wideLayout
                } else {
                    narrowLayout
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .overlay(alignment: .top) { statusBarFade }
        .overlay(alignment: .top) { toast }
        .toolbar(.hidden, for: .navigationBar)
        .task { LegacyImporter.runIfNeeded(into: modelContext) }
        .task {
            // Once Home has settled: the scanner then opens onto a live feed even on a quick tap.
            try? await Task.sleep(for: .seconds(0.6))
            model.camera.prewarm()
        }
        .onChange(of: isFrontmost) { _, frontmost in
            if frontmost { promptForReviewIfDue() }
        }
        .onChange(of: model.sheet) { _, sheet in
            if case .result = sheet { ReviewPrompter.leftHomeForResult = true }
        }
    }

    /// Room for two panes: iPhone Duo open and turned sideways, iPad in landscape. Upright, a pane would
    /// be too narrow for a card, so the page stays one column (its codes two to a row).
    private func isWide(_ size: CGSize) -> Bool {
        sizeClass == .regular && size.width >= 760 && size.width > size.height
    }

    /// iPhone: one column, the Scan lens in the thumb zone under it.
    private var narrowLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    header(showsSettings: true)
                    if isLocked {
                        LockedHomeCard()
                            .padding(.horizontal, 20)
                    } else {
                        YourCodesSection()
                    }
                }
                if !isLocked {
                    RecentSection()
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
            // On iPad, a readable column rather than a row stretched across the screen.
            .frame(maxWidth: sizeClass == .regular ? 820 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
    }

    /// Wide: the codes on one side of the hinge; recent scans and the Scan lens on the other, so the lens
    /// is never on the fold and stays under the thumb.
    private var wideLayout: some View {
        HingeSplit {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header(showsSettings: false)
                    if isLocked {
                        LockedHomeCard()
                            .padding(.horizontal, 20)
                    } else {
                        YourCodesSection()
                            .environment(\.stacksCodeCards, true)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        } trailing: {
            ScrollView {
                Group {
                    if isLocked {
                        HStack {
                            Spacer(minLength: 0)
                            HomeSettingsButton()
                        }
                        .padding(.horizontal, 20)
                    } else {
                        RecentSection(titlesPane: true)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
        }
    }

    private var actionBar: some View {
        HomeActionBar(
            isLensAnimating: isFrontmost,
            onScan: { model.openScanner() },
            onPhotos: scanFromPhotos,
            onMultiScan: { model.openScanner(multi: true) },
            onCreate: { model.openCreate() }
        )
    }

    private func header(showsSettings: Bool) -> some View {
        // Content first, as Wallet does: the page is titled by what's on it, not by the app's name.
        HStack(spacing: 12) {
            Text("Your codes")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if showsSettings { HomeSettingsButton() }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 20)
    }


    /// Content scrolling up under the clock softens away instead of colliding with it.
    private var statusBarFade: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [Color(.systemGroupedBackground), Color(.systemGroupedBackground).opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: proxy.safeAreaInsets.top + 12)
            .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var toast: some View {
        if let toast = importer.toast {
            ScannerToast(toast: toast)
                .environment(\.colorScheme, .dark)
                .id(toast.id)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
        }
    }

    private func scanFromPhotos() {
        let context = ScanCoordinator.Context(model: model, modelContext: modelContext, openURL: openURL)
        Task {
            guard let data = await PhotoImport.pickImage(from: nil) else { return }
            await importer.importImage(data, context: context)
        }
    }

    /// Asks for a rating right after the user comes back from a result at a scan milestone.
    private func promptForReviewIfDue() {
        guard ReviewPrompter.leftHomeForResult else { return }
        ReviewPrompter.leftHomeForResult = false
        guard let milestone = ReviewPrompter.milestone(scans: successfulScans, lastPrompted: lastReviewPromptScans)
        else { return }
        lastReviewPromptScans = milestone
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            requestReview()
        }
    }
}

/// Home's way into Settings: a glass gear beside the page title.
struct HomeSettingsButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.openSettings() } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
                .lensGlass(.regular, in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }
}

/// With History locked, Home keeps codes and scans out of sight until the owner unlocks.
private struct LockedHomeCard: View {
    private let lock = HistoryLock.shared
    private let biometry = BiometryKind.current

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 60, height: 60)
                .background(.fill.tertiary, in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("Your codes and scans are locked")
                    .font(.headline)
                Text("Unlock to see what you’ve saved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            Button {
                Task { await lock.unlock() }
            } label: {
                Label("Unlock", systemImage: biometry.symbol)
                    .padding(.horizontal, 24)
            }
            .buttonStyle(.primaryAction())
            .fixedSize()
            .disabled(lock.isAuthenticating)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
    }
}

#if DEBUG
#Preview("Home") {
    NavigationStack { HomeView() }
        .environment(AppModel())
        .modelContainer(HistorySamples.container)
}

#Preview("New user") {
    NavigationStack { HomeView() }
        .environment(AppModel())
        .modelContainer(for: ScanRecord.self, inMemory: true)
}
#endif
