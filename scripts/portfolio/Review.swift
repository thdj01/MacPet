import AppKit
import Vision

// Supplement the required visual review with local OCR of every still and
// every one-second frame. This never sends captured content to a service.
var results: [String: [String]] = [:]
for path in CommandLine.arguments.dropFirst() {
    autoreleasepool {
        guard let image = NSImage(contentsOfFile: path),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: cg).perform([request])
        results[URL(fileURLWithPath: path).lastPathComponent] = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
    }
}
let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
try data.write(to: URL(fileURLWithPath: "/private/tmp/macpet-ocr-review.json"))
print("Reviewed \(results.count) images with local OCR.")
