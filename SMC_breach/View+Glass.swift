import SwiftUI

extension View {
    /// Safely applies the Liquid Glass effect if available, falling back to ultra-thin material on older SDKs.
    @ViewBuilder
    func glassBackground(cornerRadius: CGFloat, variant: GlassVariant = .regular) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(variant == .regular ? .regular : .clear, in: .rect(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
        }
        #else
        self.background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
        #endif
    }
}

enum GlassVariant {
    case regular
    case clear
}
