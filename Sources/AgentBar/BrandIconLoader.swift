import AppKit

enum BrandIconLoader {
    static func image(named name: String, size: NSSize = NSSize(width: 14, height: 14)) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "svg"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = size
        image.isTemplate = true
        return image
    }
}
