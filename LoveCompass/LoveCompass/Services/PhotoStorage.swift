import SwiftUI
import PhotosUI

/// Saves and loads a partner photo to the app's documents directory.
final class PhotoStorage: ObservableObject {
    static let shared = PhotoStorage()

    @Published var partnerImage: UIImage?

    private let fileName = "partner_photo.jpg"

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    private init() {
        loadImage()
    }

    func saveImage(_ image: UIImage) {
        partnerImage = image
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: fileURL)
        }
    }

    func deleteImage() {
        partnerImage = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func loadImage() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else { return }
        partnerImage = image
    }
}
