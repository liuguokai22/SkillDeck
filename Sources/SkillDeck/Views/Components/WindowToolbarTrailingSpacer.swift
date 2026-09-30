import AppKit

/// Installs a native flexible-space item immediately after SwiftUI's split-view separator.
///
/// `ToolbarSpacer(.flexible)` is scoped to the content-column toolbar section created by
/// `NavigationSplitView`, so it does not consume the empty width above the detail column. AppKit's
/// window toolbar spacer is not column-scoped and therefore keeps the action cluster attached to
/// the true trailing edge while preserving SwiftUI's native sidebar toggle and its animation.
@MainActor
enum WindowToolbarLayout {
    static func installTrailingSpacer(in window: NSWindow) {
        // Match Mail's continuous titlebar treatment. Removing the horizontal titlebar separator
        // also eliminates the 2 pt stair-step where it met the split-view divider.
        window.titlebarSeparatorStyle = .none

        guard let toolbar = window.toolbar else { return }
        guard !toolbar.items.contains(where: { $0.itemIdentifier == .flexibleSpace }) else {
            return
        }

        let splitSeparatorIndex = toolbar.items.firstIndex {
            $0.itemIdentifier.rawValue.contains("splitViewSeparator")
        }
        let insertionIndex = min((splitSeparatorIndex.map { $0 + 1 } ?? 1), toolbar.items.count)
        toolbar.insertItem(withItemIdentifier: .flexibleSpace, at: insertionIndex)
    }
}
