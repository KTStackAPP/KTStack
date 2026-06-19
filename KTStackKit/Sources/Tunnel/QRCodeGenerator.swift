import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

public enum QRCodeGenerator {
    public static func image(for url: URL, size: CGFloat = 200) -> NSImage? {
        image(for: url.absoluteString, size: size)
    }

    public static func image(for text: String, size: CGFloat = 200) -> NSImage? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, size > 0 else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(trimmedText.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let extent = outputImage.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }

        let scale = ceil(size / max(extent.width, extent.height))
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let renderExtent = scaledImage.extent.integral
        let context = CIContext()

        guard let cgImage = context.createCGImage(scaledImage, from: renderExtent) else { return nil }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
