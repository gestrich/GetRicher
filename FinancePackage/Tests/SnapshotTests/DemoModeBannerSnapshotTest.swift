import SwiftUI
import Testing

/// A standalone copy of DemoModeBanner for snapshot testing.
/// The real view lives in the Xcode app target and isn't importable from SPM tests,
/// so we duplicate it here to demonstrate the ImageRenderer technique.
private struct DemoModeBanner: View {
    var body: some View {
        Text("Demo Mode")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.orange)
    }
}

@MainActor
@Test func renderDemoModeBanner() async throws {
    let view = DemoModeBanner()
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor))

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0

    guard let image = renderer.cgImage else {
        Issue.record("Failed to render image")
        return
    }

    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        Issue.record("Failed to create PNG")
        return
    }

    let path = "/tmp/demo_mode_banner_snapshot.png"
    try data.write(to: URL(fileURLWithPath: path))
    print("Snapshot saved: \(path) (\(image.width)x\(image.height))")
}
