import Vision
import UIKit

/// Extracts individual text lines from an image using the Vision framework.
final class OCRService {

    func extractLines(from image: UIImage) async -> [String] {
        // Downscale before OCR: large camera images (12MP+) slow Vision down
        // considerably. 2048px on the long edge is more than enough for text recognition.
        let scaled = resized(image, maxLongEdge: 2048)
        guard let cgImage = scaled.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            // Dispatch to a background queue so the main thread is never blocked
            // while Vision processes the image (can take 1–3 s on slow devices).
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, _ in
                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: lines)
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["en-US"]

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    // MARK: - Helpers

    private func resized(_ image: UIImage, maxLongEdge: CGFloat) -> UIImage {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxLongEdge else { return image }
        let scale = maxLongEdge / longEdge
        let newSize = CGSize(width: (size.width * scale).rounded(),
                             height: (size.height * scale).rounded())
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
