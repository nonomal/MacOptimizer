import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AIAttachment: Identifiable {
    let id: UUID
    let data: Data
    let fileName: String
    let mimeType: String

    init(id: UUID = UUID(), data: Data, fileName: String, mimeType: String) {
        self.id = id
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }

    var image: NSImage? { NSImage(data: data) }
    var payload: AIAttachmentPayload { .init(data: data, mimeType: mimeType) }
}

enum AIAttachmentLoadError: Error {
    case tooMany
    case tooLarge
    case unsupportedFormat
    case unreadable
}

enum AIAttachmentLoader {
    static let maximumCount = 8
    static let maximumBytes = 15 * 1024 * 1024

    static func load(urls: [URL], availableSlots: Int) throws -> [AIAttachment] {
        guard availableSlots > 0 else { throw AIAttachmentLoadError.tooMany }
        let candidates = Array(urls.prefix(availableSlots))
        guard candidates.count == urls.count else { throw AIAttachmentLoadError.tooMany }
        return try candidates.map(load(url:))
    }

    static func load(url: URL) throws -> AIAttachment {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= maximumBytes else { throw AIAttachmentLoadError.tooLarge }
        let fileName = url.lastPathComponent.isEmpty ? "image" : url.lastPathComponent
        let fileType = UTType(filenameExtension: url.pathExtension.lowercased())

        if fileType?.conforms(to: .png) == true {
            return try validated(data: data, fileName: fileName, mimeType: "image/png")
        }
        if fileType?.conforms(to: .jpeg) == true {
            return try validated(data: data, fileName: fileName, mimeType: "image/jpeg")
        }
        if fileType?.identifier == UTType.webP.identifier {
            return try validated(data: data, fileName: fileName, mimeType: "image/webp")
        }
        if fileType?.conforms(to: .heic) == true || fileType?.conforms(to: .heif) == true {
            guard let image = NSImage(data: data) else { throw AIAttachmentLoadError.unreadable }
            return try load(image: image, fileName: replacingExtension(of: fileName, with: "jpg"))
        }
        throw AIAttachmentLoadError.unsupportedFormat
    }

    static func load(image: NSImage, fileName: String = "pasted-image.png") throws -> AIAttachment {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw AIAttachmentLoadError.unreadable
        }
        guard data.count <= maximumBytes else { throw AIAttachmentLoadError.tooLarge }
        return AIAttachment(data: data, fileName: fileName, mimeType: "image/png")
    }

    static func urls(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return (pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]) ?? []
    }

    static func attachments(from pasteboard: NSPasteboard, availableSlots: Int) throws -> [AIAttachment] {
        let urls = urls(from: pasteboard)
        if !urls.isEmpty { return try load(urls: urls, availableSlots: availableSlots) }
        guard availableSlots > 0 else { throw AIAttachmentLoadError.tooMany }
        guard let image = NSImage(pasteboard: pasteboard) else { return [] }
        return [try load(image: image)]
    }

    private static func validated(data: Data, fileName: String, mimeType: String) throws -> AIAttachment {
        guard NSImage(data: data) != nil else { throw AIAttachmentLoadError.unreadable }
        return AIAttachment(data: data, fileName: fileName, mimeType: mimeType)
    }

    private static func replacingExtension(of fileName: String, with extensionName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        return "\(stem.isEmpty ? "image" : stem).\(extensionName)"
    }
}

struct AIComposerTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat
    let onSend: () -> Void
    let onPasteAttachments: (NSPasteboard) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = AIComposerNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.textContainerInset = NSSize(width: 0, height: 5)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.registerForDraggedTypes([.fileURL, .png, .tiff])
        textView.onSend = onSend
        textView.onPasteAttachments = onPasteAttachments
        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? AIComposerNSTextView else { return }
        context.coordinator.parent = self
        textView.onSend = onSend
        textView.onPasteAttachments = onPasteAttachments
        if textView.string != text {
            textView.string = text
            textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
        }
        context.coordinator.updateHeight()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AIComposerTextView
        weak var textView: NSTextView?

        init(parent: AIComposerTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            updateHeight()
        }

        func updateHeight() {
            guard let textView,
                  let container = textView.textContainer,
                  let layoutManager = textView.layoutManager else { return }
            layoutManager.ensureLayout(for: container)
            let contentHeight = ceil(layoutManager.usedRect(for: container).height + 10)
            let nextHeight = min(126, max(32, contentHeight))
            if abs(parent.measuredHeight - nextHeight) > 0.5 {
                DispatchQueue.main.async { self.parent.measuredHeight = nextHeight }
            }
        }
    }
}

private final class AIComposerNSTextView: NSTextView {
    var onSend: (() -> Void)?
    var onPasteAttachments: ((NSPasteboard) -> Bool)?

    override func paste(_ sender: Any?) {
        if onPasteAttachments?(NSPasteboard.general) == true { return }
        super.paste(sender)
    }

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        let isComposing = hasMarkedText()
        if isReturn && !isComposing && !event.modifierFlags.contains(.shift) && !event.modifierFlags.contains(.option) {
            onSend?()
            return
        }
        super.keyDown(with: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        canAcceptImages(from: sender.draggingPasteboard) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onPasteAttachments?(sender.draggingPasteboard) == true
    }

    private func canAcceptImages(from pasteboard: NSPasteboard) -> Bool {
        if !AIAttachmentLoader.urls(from: pasteboard).isEmpty { return true }
        return NSImage(pasteboard: pasteboard) != nil
    }
}
