import AppKit
import SwiftUI

struct MacVisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}

struct IconButton: View {
    let systemImage: String
    let help: String
    var size: CGFloat = 11
    var frameSize: CGFloat = 22
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .medium))
                .frame(width: frameSize, height: frameSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovering ? Color.primary : Color.secondary)
        .background {
            RoundedRectangle(cornerRadius: max(5, frameSize * 0.22), style: .continuous)
                .fill(isHovering ? Color.white.opacity(0.10) : .clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: max(5, frameSize * 0.22), style: .continuous))
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isHovering)
        .accessibilityLabel(help)
        .help(help)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.24))
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
