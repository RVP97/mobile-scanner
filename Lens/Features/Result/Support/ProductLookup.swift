import Foundation

/// What the open product databases know about a barcode.
struct ProductInfo: Hashable {
    var name: String
    var brand: String
    var quantity: String
    var imageURL: URL?
    var categories: [String]
    var source: String
}

/// Open Food Facts, then Open Products Facts. Only called when the user opens a product result.
enum ProductLookup {
    enum Outcome: Hashable {
        case found(ProductInfo)
        case notFound
        case unavailable
    }

    private static let databases: [(host: String, name: String)] = [
        ("world.openfoodfacts.org", "Open Food Facts"),
        ("world.openproductsfacts.org", "Open Products Facts"),
    ]

    static func lookup(gtin: String) async -> Outcome {
        let code = GTIN.lookupCode(gtin)
        var reachedAny = false
        for database in databases {
            guard let url = URL(string: "https://\(database.host)/api/v2/product/\(code).json?fields=product_name,brands,image_front_url,quantity,categories") else { continue }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
            request.setValue("Lens/2.0 (iOS; com.rvp97.scanner)", forHTTPHeaderField: "User-Agent")
            guard let (data, _) = try? await session.data(for: request) else { continue }
            reachedAny = true
            if let info = parse(data, source: database.name) { return .found(info) }
        }
        return reachedAny ? .notFound : .unavailable
    }

    /// Reads an Open Food Facts–style v2 product response.
    static func parse(_ data: Data, source: String) -> ProductInfo? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (object["status"] as? Int) == 1 || (object["status"] as? String) == "success",
              let product = object["product"] as? [String: Any]
        else { return nil }

        func text(_ key: String) -> String { (product[key] as? String)?.trimmed ?? "" }
        let name = text("product_name")
        let brand = text("brands").split(separator: ",").first.map { String($0).trimmed } ?? ""
        guard !name.isEmpty || !brand.isEmpty else { return nil }

        let categories = text("categories")
            .split(separator: ",")
            .map { String($0).trimmed }
            .filter { !$0.isEmpty && !$0.contains(":") }
        return ProductInfo(
            name: name.isEmpty ? brand : name,
            brand: name.isEmpty ? "" : brand,
            quantity: text("quantity"),
            imageURL: URL(string: text("image_front_url")),
            categories: Array(categories.suffix(2)),
            source: source
        )
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()
}
