## 0.1.0

- Initial experimental Android embedded picker widget and controller.
- Runtime capability detection, host fallback, selection events, and lifecycle.
- Add detailed runtime capabilities for Android feature-level checks.
- Creation-time selection limits, MIME filters, preselection, accent, and theme.
- Add optional resolution, file-size, batch-size, duration, and selectable MIME
	constraints on API 37 and U SDK Extension 22+.
- Add opening-tab selection, album/search highlights, highlight presentation,
	and collapsed-mode scrolling with feature-level availability checks.
- Add an explicit, capability-gated opt-in for selected-media location metadata.
- Add embedded grid aspect-ratio and expanded selection-bar customization.
- Standalone example and Dart/native tests.
- Fix native picker taps by placing the child surface above its host window.
- Apply the requested expanded or collapsed state before opening the session.
- Add `EmbeddedPhotoPickerMedia.loadThumbnail` for bounded image/video PNG
	thumbnails, with background loading and cleanup on engine detachment.
- Demonstrate horizontal previews, removal, and host-owned slide transitions
	without custom Android code in the example.
- Add publishing metadata, MIT license, archive exclusions, and consumer docs.
