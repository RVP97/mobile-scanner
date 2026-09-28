import NetworkExtension
import SwiftUI

/// Wi-Fi: network, security, a password you can reveal or copy, and "Join Network".
struct WiFiResultView: View {
    var network: WiFiNetwork
    var result: ScanResult

    @State private var revealsPassword = false
    @State private var joinState = JoinState.idle

    enum JoinState: Equatable {
        case idle, joining, joined
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ResultCard {
                if network.security == .open {
                    Label("No password needed", systemImage: "lock.open.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44, alignment: .leading)
                } else {
                    passwordRow
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                joinButton
                statusLine
            }

            ResultActionRow(result: result, copyText: nil) {
                if network.security != .open {
                    CopyButton(text: network.password, title: "Copy Password")
                } else {
                    CopyButton(text: network.ssid, title: "Copy Name")
                }
            }
        }
        .sensoryFeedback(.success, trigger: joinState == .joined) { _, joined in joined }
        .animation(.smooth, value: joinState)
    }

    private var passwordRow: some View {
        DetailRow(
            label: "Password",
            value: revealsPassword ? network.password : String(repeating: "•", count: min(max(network.password.count, 8), 16)),
            monospaced: true
        ) {
            RowIconButton(symbol: revealsPassword ? "eye.slash" : "eye",
                          label: revealsPassword ? "Hide Password" : "Show Password") {
                revealsPassword.toggle()
            }
            .contentTransition(.symbolEffect(.replace))
        }
    }

    @ViewBuilder private var joinButton: some View {
        if joinState == .joined {
            Label("Connected to \(network.ssid)", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(Palette.safe)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Palette.safe.opacity(0.16), in: .capsule)
                .transition(.opacity)
        } else {
            ResultPrimaryButton(title: "Join Network", symbol: "wifi", tint: CodeKind.wifi.tint,
                                isBusy: joinState == .joining) {
                Task { await join() }
            }
        }
    }

    @ViewBuilder private var statusLine: some View {
        switch joinState {
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(Palette.caution)
        case .joined:
            Text("Your iPhone will join automatically next time.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        default:
            if revealsPassword {
                Text("The password hides again when you close this.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func join() async {
        joinState = .joining
        joinState = await WiFiJoiner.join(network)
    }
}

/// Wraps `NEHotspotConfigurationManager` and turns its errors into plain sentences.
enum WiFiJoiner {
    static func join(_ network: WiFiNetwork) async -> WiFiResultView.JoinState {
        let configuration: NEHotspotConfiguration = switch network.security {
        case .open: NEHotspotConfiguration(ssid: network.ssid)
        case .wep: NEHotspotConfiguration(ssid: network.ssid, passphrase: network.password, isWEP: true)
        case .wpa: NEHotspotConfiguration(ssid: network.ssid, passphrase: network.password, isWEP: false)
        }
        configuration.joinOnce = false
        configuration.hidden = network.isHidden

        do {
            try await NEHotspotConfigurationManager.shared.apply(configuration)
            return .joined
        } catch let error as NSError where error.domain == NEHotspotConfigurationErrorDomain {
            switch NEHotspotConfigurationError(rawValue: error.code) {
            case .alreadyAssociated:
                return .joined
            case .userDenied:
                return .failed(String(localized: "You chose not to join. Tap Join Network to try again."))
            case .invalidWPAPassphrase, .invalidWEPPassphrase:
                return .failed(String(localized: "The password in this code isn't valid for \(network.ssid)."))
            case .invalidSSID, .invalidSSIDPrefix:
                return .failed(String(localized: "This code has a network name iPhone can't use."))
            case .applicationIsNotInForeground:
                return .failed(String(localized: "Keep Lunet open while it joins."))
            default:
                return .failed(String(localized: "Couldn't join \(network.ssid). Make sure you're in range and try again."))
            }
        } catch {
            return .failed(String(localized: "Couldn't join \(network.ssid). Make sure you're in range and try again."))
        }
    }
}

#if DEBUG
#Preview { ResultPreview(.sampleWiFi) }
#endif
