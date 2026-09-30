import SwiftUI

/// TagFlowView arranges tag views in a wrapping flow layout (similar to CSS flexbox with flex-wrap)
///
/// Since SwiftUI doesn't have a native wrapping HStack, this component uses
/// GeometryReader to measure available width and manually calculates line breaks.
/// Tags that don't fit on the current line wrap to the next line.
///
/// Usage:
/// ```swift
/// TagFlowView(tags: ["科研", "开发", "求职"]) { tag in
///     Text(tag)
///         .padding(4)
///         .background(.blue.opacity(0.1))
///         .clipShape(Capsule())
/// }
/// ```
struct TagFlowView<Content: View>: View {

    let tags: [String]
    let content: (String) -> Content

    /// Spacing between tags (horizontal and vertical)
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6

    init(tags: [String], @ViewBuilder content: @escaping (String) -> Content) {
        self.tags = tags
        self.content = content
    }

    var body: some View {
        // Use a custom layout that wraps children across lines
        // For simplicity, we use a VStack of HStacks approach with GeometryReader
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        // Use fixed height based on content to avoid GeometryReader taking all available space
        .frame(height: totalHeight)
    }

    /// Total height of the flow layout, computed by measuring tag sizes
    @State private var totalHeight: CGFloat = 30

    /// Generate wrapped content using overlay-based size measurement
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            ForEach(tags, id: \.self) { tag in
                content(tag)
                    .padding(.horizontal, horizontalSpacing / 2)
                    .padding(.vertical, verticalSpacing / 2)
                    .alignmentGuide(.leading) { dimension in
                        // If this tag exceeds the available width, wrap to next line
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height
                        }
                        let result = width
                        // If this is the last tag, reset width for next layout pass
                        if tag == tags.last {
                            width = 0
                        } else {
                            width -= dimension.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if tag == tags.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(
            // Invisible GeometryReader to measure total content height
            GeometryReader { geometry in
                Color.clear
                    .preference(key: FlowHeightPreferenceKey.self, value: geometry.size.height)
            }
        )
        .onPreferenceChange(FlowHeightPreferenceKey.self) { value in
            totalHeight = value
        }
    }
}

/// Preference key for communicating height from child to parent
/// SwiftUI's PreferenceKey mechanism allows child views to pass data up to parent views
/// (the reverse of environment values which flow down). Similar to React's "lifting state up" pattern.
private struct FlowHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
