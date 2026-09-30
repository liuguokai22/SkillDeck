import AppKit
import SwiftUI

/// Renders the actual product mark for a supported Agent instead of an approximate SF Symbol.
///
/// `NSImage(contentsOf:)` lets the macOS image stack decode the bundled SVG while SwiftUI handles
/// layout and Retina scaling. Images are loaded once into a static dictionary, comparable to an
/// immutable process-wide cache in Java or Go, so long skill lists do not repeatedly parse SVGs.
struct AgentBrandIcon: View {

    let agentType: AgentType
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let image = AgentBrandImageCache.images[agentType] {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                // QClaw and WorkBuddy do not have a verified asset in the selected icon source.
                // A clear branded monogram is preferable to a misleading unrelated pictogram.
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .fill(Constants.AgentColors.color(for: agentType).opacity(0.16))

                    Text(agentType.brandMonogram)
                        .font(.system(size: size * 0.58, weight: .bold, design: .rounded))
                        .foregroundStyle(Constants.AgentColors.color(for: agentType))
                }
            }
        }
        .frame(width: size, height: size)
        // The adjacent product name supplies the accessible label in every current use site.
        .accessibilityHidden(true)
    }
}

private enum AgentBrandImageCache {

    static let images: [AgentType: NSImage] = {
        Dictionary(
            uniqueKeysWithValues: AgentType.allCases.compactMap { agentType in
                guard
                    let resourceName = agentType.brandIconResourceName,
                    let url = Bundle.module.url(
                        forResource: resourceName,
                        withExtension: "svg",
                        subdirectory: "AgentIcons"
                    ),
                    let image = NSImage(contentsOf: url)
                else {
                    return nil
                }

                return (agentType, image)
            }
        )
    }()
}
