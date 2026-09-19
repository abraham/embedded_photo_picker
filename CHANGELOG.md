## 0.1.0

- Initial experimental Android embedded picker widget and controller.
- Runtime capability detection, host fallback, selection events, and lifecycle.
- Creation-time selection limits, MIME filters, preselection, accent, and theme.
- Standalone example and Dart/native tests.
- Fix native picker taps by placing the child surface above its host window.
- Add `EmbeddedPhotoPickerMedia.loadThumbnail` for bounded image/video PNG
	thumbnails, with background loading and cleanup on engine detachment.
- Demonstrate horizontal previews, removal, and host-owned slide transitions
	without custom Android code in the example.
- Add publishing metadata, MIT license, archive exclusions, and consumer docs.
