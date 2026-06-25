import SwiftUI

/// Shared spacing / sizing rhythm for the "flat & airy" look — generous
/// whitespace, no card backgrounds, hairline separators used sparingly.
enum Theme {
    /// Horizontal gutter for all surfaces.
    static let gutter: CGFloat = 16
    /// Vertical padding inside a list row (airy).
    static let rowVPad: CGFloat = 12
    /// Gap between a flag avatar and its text.
    static let avatarGap: CGFloat = 12

    /// Popover width.
    static let popoverWidth: CGFloat = 330

    enum FontSize {
        static let title: CGFloat = 13      // header / app name
        static let rowName: CGFloat = 14    // zone name
        static let meta: CGFloat = 11       // country · offset
        static let time: CGFloat = 19       // hero time (popover)
        static let timeSmall: CGFloat = 15  // time in dashboard rows
        static let tag: CGFloat = 10        // day-offset / phase
    }
}
