#if targetEnvironment(macCatalyst)
import MapKit
import SwiftUI
import UIKit

enum SnapshotExporter {
    static func makeFilename(district: String, date: Date = Date()) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmm"
        return "\(district)学片图_\(df.string(from: date)).png"
    }

    static func outputDirectory() -> URL {
        let dir = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PropertyAtlas", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func export(
        camera: MKMapCamera,
        aspect: CanvasAspect,
        overlayView: some View,
        district: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let opts = MKMapSnapshotter.Options()
        opts.camera = camera
        opts.size = aspect.pixelSize
        opts.mapType = .mutedStandard
        let snapshotter = MKMapSnapshotter(options: opts)
        snapshotter.start { snapshot, err in
            guard let snap = snapshot else {
                completion(.failure(err ?? NSError(domain: "snap", code: 0)))
                return
            }
            UIGraphicsBeginImageContextWithOptions(snap.image.size, true, 1.0)
            snap.image.draw(at: .zero)
            let renderer = ImageRenderer(
                content: overlayView.frame(width: snap.image.size.width, height: snap.image.size.height)
            )
            renderer.scale = 1.0
            if let uiImage = renderer.uiImage {
                uiImage.draw(at: .zero, blendMode: .normal, alpha: 1.0)
            }
            let combined = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            guard let combined, let data = combined.pngData() else {
                completion(.failure(NSError(domain: "snap", code: 1)))
                return
            }
            let url = outputDirectory().appendingPathComponent(makeFilename(district: district))
            do {
                try data.write(to: url)
                completion(.success(url))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
#endif
