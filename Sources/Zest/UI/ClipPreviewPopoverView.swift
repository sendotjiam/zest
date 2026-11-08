import SwiftUI
import AppKit

public struct ClipPreviewPopoverView: View {
    public let item: ClipItem
    public let onPaste: () -> Void
    public let onDismiss: () -> Void

    public init(item: ClipItem, onPaste: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.item = item
        self.onPaste = onPaste
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header bar
            HStack(spacing: 8) {
                Text(item.detectedType.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(item.detectedType.systemColor.opacity(0.2))
                    .foregroundColor(item.detectedType.systemColor)
                    .cornerRadius(4)

                if let app = item.sourceApp, !app.isEmpty {
                    Text(app)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if item.isImage {
                    if let w = item.imageWidth, let h = item.imageHeight {
                        Text("\(w) × \(h) px")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if let size = item.formattedFileSize {
                        Text(size)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("\(item.lineCount) lines")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(item.characterCount) chars")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)

            Divider()

            // Content Viewer
            if item.isImage, let data = item.imageData, let nsImage = NSImage(data: data) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 420, maxHeight: 300)
                        .cornerRadius(6)
                        .padding(4)
                }
                .frame(maxWidth: .infinity, maxHeight: 320)
                .background(Color.black.opacity(0.2))
                .cornerRadius(6)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(item.rawContent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 320)
                .background(Color.black.opacity(0.25))
                .cornerRadius(6)
            }

            // Footer actions
            HStack(spacing: 12) {
                Text("Space: Close  •  Return: Paste  •  ⇧Return: Copy")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                Button("Paste") {
                    onPaste()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 440)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}
