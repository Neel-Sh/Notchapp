import SwiftUI

struct IconButton: View {
    let systemImage: String
    let help: String
    var size: CGFloat = 11
    var frameSize: CGFloat = 22
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .medium))
                .frame(width: frameSize, height: frameSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.64))
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
