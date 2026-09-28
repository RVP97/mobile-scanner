import Testing
@testable import Lens

struct PayloadParserTests {
    @Test func plainURLIsLink() {
        let payload = PayloadParser.parse("https://atlas-coffee.co/menu", symbology: .qr)
        #expect(payload.kind == .link)
    }
}
