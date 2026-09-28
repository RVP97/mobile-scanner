import Foundation

/// `WIFI:T:WPA;S:Atlas Guest;P:cortado-2019;H:false;;` — fields may appear in any order.
enum WiFiParser {
    static func parse(_ raw: String) -> WiFiNetwork? {
        guard raw.hasPrefixIgnoringCase("WIFI:") else { return nil }
        var ssid = ""
        var password = ""
        var type = ""
        var hidden = false
        for field in EscapedFields.fields(raw.dropFirst(5)) {
            switch field.key {
            case "S": ssid = field.value
            case "P": password = field.value
            case "T": type = field.value.trimmed.uppercased()
            case "H": hidden = ["TRUE", "1", "YES"].contains(field.value.trimmed.uppercased())
            default: break
            }
        }
        guard !ssid.isEmpty else { return nil }

        let security: WiFiNetwork.Security = switch type {
        case "WEP": .wep
        case "NOPASS", "NONE", "OPEN": .open
        case "": password.isEmpty ? .open : .wpa
        default: .wpa // WPA, WPA2, WPA3, SAE, WPA2-EAP…
        }
        return WiFiNetwork(
            ssid: ssid,
            password: security == .open ? "" : password,
            security: security,
            isHidden: hidden
        )
    }
}
