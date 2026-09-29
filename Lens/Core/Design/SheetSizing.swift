import SwiftUI

extension View {
    /// On iPad, a sheet sized like a page instead of the small default form, so a whole result or
    /// the studio fits without scrolling. iPhone sheets are unaffected.
    @ViewBuilder
    func pageSizedSheet() -> some View {
        if #available(iOS 18.0, *) {
            presentationSizing(.page)
        } else {
            self
        }
    }
}
