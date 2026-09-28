import Foundation

/// Opens a query in the browser's search. One place to change the engine.
enum WebSearch {
    static func url(for query: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }

    /// Shopping results for a product number or name.
    static func shoppingURL(for query: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "tbm", value: "shop")]
        return components?.url
    }
}
