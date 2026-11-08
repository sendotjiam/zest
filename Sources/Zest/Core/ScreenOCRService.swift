import Foundation
import AppKit
import Vision
import CoreGraphics

public final class ScreenOCRService: @unchecked Sendable {
    public static let shared = ScreenOCRService()

    public init() {}

    /// Checks if macOS Screen Recording permission is currently granted
    public static var hasScreenRecordingPermission: Bool {
        return CGPreflightScreenCaptureAccess()
    }

    /// Requests Screen Recording permission and opens System Settings if not granted
    public static func requestScreenRecordingPermission() {
        if !CGRequestScreenCaptureAccess() {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Performs optical character recognition on a given CGImage using Apple's Vision framework.
    public func recognizeText(from image: CGImage) throws -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            return nil
        }

        let recognizedLines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        let combined = recognizedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? nil : combined
    }

    /// Invokes macOS native interactive screen capture (`screencapture -i -s`),
    /// extracts recognized text from the selected region, writes it to the clipboard,
    /// and immediately saves it into Zest clipboard history.
    @discardableResult
    public func captureAndRecognize() async -> String? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zest_ocr_\(UUID().uuidString).png")
        let tempPath = tempURL.path

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-s", tempPath]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            await MainActor.run {
                NSSound.beep()
            }
            return nil
        }

        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: tempPath),
              let nsImage = NSImage(contentsOfFile: tempPath),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            // User cancelled via Esc or selection was empty
            return nil
        }

        do {
            if let recognizedText = try recognizeText(from: cgImage) {
                await MainActor.run {
                    ClipboardEngine.shared.add(text: recognizedText, sourceApp: "Screen OCR")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(recognizedText, forType: .string)
                    NSSound(named: "Tink")?.play()
                }
                return recognizedText
            } else {
                // If Vision found no text, check if Screen Recording permission was missing
                if !Self.hasScreenRecordingPermission {
                    await MainActor.run {
                        Self.requestScreenRecordingPermission()
                    }
                }
                await MainActor.run {
                    NSSound.beep()
                }
                return nil
            }
        } catch {
            await MainActor.run {
                NSSound.beep()
            }
            return nil
        }
    }
}
