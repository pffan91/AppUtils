//
//  GrayscaleImageHelper.swift
//  AppUtils
//
//  Created by Vladyslav Semenchenko on 16/02/2025.
//

import UIKit

public final class GrayscaleImageCache {

    public final class CustomKey: NSObject {

        let string: String

        public init(string: String) {
            self.string = string
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? CustomKey else { return false }
            return string == other.string
        }

        public override var hash: Int {
            return string.hashValue
        }
    }

    public static let shared = GrayscaleImageCache()

    private let cache: NSCache<CustomKey, UIImage> = {
        let cache = NSCache<CustomKey, UIImage>()
        return cache
    }()

    public func grayscaleImage(for url: CustomKey, original: UIImage, amount: CGFloat = 0.05) async -> UIImage? {
        // If cached, return immediately (no need for await here as it's synchronous)
        if let cached = cache.object(forKey: url as CustomKey) { return cached }

        // Processing in a background task
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                // Convert UIImage to CIImage
                guard let ciImage = CIImage(image: original) else { continuation.resume(returning: nil); return }

                // Apply grayscale effect (CIPhotoEffectTonal)
                guard let grayscaleFilter = CIFilter(name: "CIPhotoEffectTonal") else { continuation.resume(returning: nil); return }
                grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)

                // Apply brightness adjustment to lighten the image
                guard let lighteningFilter = CIFilter(name: "CIColorControls") else { continuation.resume(returning: nil); return }

                if let grayscaleOutput = grayscaleFilter.outputImage {
                    lighteningFilter.setValue(grayscaleOutput, forKey: kCIInputImageKey)
                    lighteningFilter.setValue(amount, forKey: kCIInputBrightnessKey)
                } else {
                    continuation.resume(returning: nil)
                    return
                }

                // Render the final image
                let context = CIContext(options: nil)
                if let output = lighteningFilter.outputImage,
                   let cgImage = context.createCGImage(output, from: output.extent) {
                    let grayscale = UIImage(cgImage: cgImage)
                    // Cache the result
                    self.cache.setObject(grayscale, forKey: url as CustomKey)
                    continuation.resume(returning: grayscale)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
