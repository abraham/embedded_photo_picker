# Embedded Photo Picker

Embed Android's system photo picker directly in a Flutter layout. The plugin
supports continuous selection, runtime support checks, advanced filtering, and
image/video thumbnails without broad gallery permissions.

> [!NOTE]
> This integration is experimental. Validate rendering, accessibility, cloud
> media, and OEM behavior on your target devices before production use.

| Collapsed picker | Expanded picker | Selected media |
| --- | --- | --- |
| ![Collapsed system photo picker embedded below a chat composer](https://github.com/abraham/embedded_photo_picker/blob/main/doc/screenshots/chat-collapsed.png?raw=true) | ![Expanded system photo picker embedded below a chat composer](https://github.com/abraham/embedded_photo_picker/blob/main/doc/screenshots/chat-expanded.png?raw=true) | ![Selected media in system photo picker embedded below a chat composer](https://github.com/abraham/embedded_photo_picker/blob/main/doc/screenshots/chat-selected.png?raw=true) |
| ![Collapsed system photo picker embedded below a message composer](https://github.com/abraham/embedded_photo_picker/blob/main/doc/screenshots/compose-collapsed.png?raw=true) | ![Expanded system photo picker embedded below a message composer](https://github.com/abraham/embedded_photo_picker/blob/main/doc/screenshots/compose-expanded.png?raw=true) | ![Selected media in system photo picker embedded below a message composer](https://github.com/abraham/embedded_photo_picker/blob/main/doc/screenshots/compose-selected.png?raw=true) |

## Requirements

- Flutter 3.44+, Dart 3.13+, Java 17
- Android compile SDK 37.1+, Android Gradle Plugin 9.3.3+, Gradle 9.5+
- App minSdk 23+
- Embedded picking requires Android 16+, or Android 14/15 with U SDK Extension
  15+ and an installed embedded picker service

Unsupported devices and non-Android platforms render the supplied fallback.

## Usage

```sh
flutter pub add embedded_photo_picker
```

The picker uses controlled selection state. Native grants and revocations arrive
as complete snapshots, while `added` and `removed` remain available for work
that depends on the individual change.

```dart
List<Uri> selected = [];

EmbeddedPhotoPicker(
  selection: selected,
  onChanged: (change) {
    setState(() => selected = change.selection);
  },
  onDone: (selection) => closePicker(),
  fallbackBuilder: (context) => YourExistingGalleryButton(),
)
```

Removing a URI from `selection` automatically deselects it in Android. The
widget owns its native controller and remounts itself when creation-time config
or externally added selection changes.

## Configuration

Common options:

```dart
final config = PickerConfig(
  maxSelection: 4,
  filter: PickerFilter.images,
  ordered: true,
  accentColor: const Color(0xff087f8c),
);

EmbeddedPhotoPicker(
  selection: selected,
  config: config,
  onChanged: (change) => setState(() => selected = change.selection),
)
```

Use `PickerFilter.all`, `.images`, `.videos`, or
`PickerFilter.mimeTypes([...])`. Filter MIME types hide unmatched media.

### Constraints

Constraints keep unmatched media visible but unavailable to select:

```dart
final config = PickerConfig(
  maxSelection: 4,
  constraints: PickerConstraints(
    maxFileSizeBytes: 10 * 1024 * 1024,
    maxTotalSizeBytes: 25 * 1024 * 1024,
    minResolutionPixels: 1_000_000,
    maxVideoDuration: const Duration(minutes: 2),
    allowedMimeTypes: ['image/jpeg', 'video/mp4'],
  ),
);
```

### Presentation

Navigation, highlights, and appearance share one presentation object. Highlight
factories make album and search requests mutually exclusive.

```dart
final config = PickerConfig(
  presentation: const PickerPresentation(
    initialTab: PickerTab.collections,
    highlight: PickerHighlight.album(
      PickerAlbum.favorites,
      style: PickerHighlightStyle.section,
    ),
    collapsedScrolling: true,
    gridAspectRatio: PickerGridAspectRatio.portrait9By16,
    showSelectionBar: false,
  ),
);
```

Use `PickerHighlight.search('receipts')` for text-query highlights.

### Location metadata

Location metadata stays redacted unless explicitly requested:

```dart
final config = PickerConfig(
  locationMetadata: PickerLocationMetadata.request,
);
```

Android may ask the user whether to share location metadata, and the user's
choice is final. A successful request does not guarantee metadata exists.

## Device support

The widget checks its config automatically and renders the fallback instead of
opening a partially configured picker. Check support yourself only when the
surrounding UI needs to adapt in advance:

```dart
final support = await EmbeddedPhotoPicker.checkSupport(config);

if (support.isSupported) {
  // Every feature required by config is available.
} else {
  print(support.unsupportedFeatures);
}
```

Feature availability depends on Android SDK extensions delivered through system
updates. Unsupported requested features report `unsupported_feature` through
`onError`.

## Thumbnails and media

Selected values are Android `content://` URIs, not filesystem paths. Never pass
them to `File(uri.path)`. The host owns copying, persistence, uploads, and
cleanup. Access can be revoked and cloud media may download asynchronously.

```dart
final png = await const PhotoPickerMedia().loadThumbnail(
  selectedUri,
  width: 384,
  height: 384,
);

final preview = Image.memory(png, fit: BoxFit.contain);
```

Thumbnail dimensions must be between 1 and 1024 physical pixels. The API
requires Android 10+ and existing read access; it does not request or persist
permissions.

## Rendering constraints

The picker uses hybrid composition and a native `SurfaceView`. Give it finite
layout bounds and test interactions inside scrolling parents. Flutter content
cannot reliably draw over the picker, and Flutter's gesture arena cannot block
all native surface input. Unmount the picker before showing overlapping Flutter
menus or dialogs.

## Example

```sh
cd example
flutter pub get
flutter run -d <android-id>
```

The example demonstrates expanded and collapsed pickers, previews, host-side
removal, message sending, and show/hide transitions.

## Development

```sh
flutter analyze
flutter test

cd example
flutter test
flutter build apk --debug

cd android
./gradlew :embedded_photo_picker:testDebugUnitTest
```

Before releasing, run `flutter pub publish --dry-run`. Unit tests cannot verify
the remote picker surface or Android permission grants, so test selection,
revocation, cloud media, accessibility, lifecycle, and overlays on target
physical devices.

## References

- https://developer.android.com/training/data-storage/shared/photo-picker/embedded
- https://developer.android.com/reference/android/widget/photopicker/package-summary
- https://docs.flutter.dev/platform-integration/android/platform-views
