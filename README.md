# Embedded Photo Picker

Embed Android's system photo picker directly in a Flutter layout. The plugin
supports selection callbacks, runtime availability checks, and image/video
thumbnails without requesting broad gallery permissions.

> This integration is experimental. Validate rendering, accessibility, cloud
> media, and OEM behavior on your target devices before production use.

## Requirements

- Flutter 3.44+, Dart 3.13+, Java 17, and Android compile SDK 37.1+
- Android Gradle Plugin 9.3.3+ and Gradle 9.5+
- App minSdk 23+
- Android 16/API 36+, or Android 14/15 with U SDK Extension 15+
- An installed embedded picker service

Unsupported devices and non-Android platforms render the supplied fallback.

## Usage

```sh
flutter pub add embedded_photo_picker
```

Set your Android app's compile SDK in `build.gradle.kts`:

```kotlin
android {
  compileSdk {
    version = release(37) {
      minorApiLevel = 1
    }
  }
}
```

Then add a bounded picker:

```dart
import 'package:embedded_photo_picker/embedded_photo_picker.dart';

SizedBox(
  height: 400,
  child: EmbeddedPhotoPicker(
    options: EmbeddedPhotoPickerOptions(
      maxSelection: 4,
      mimeTypes: ['image/*', 'video/*'],
      orderedSelection: true,
    ),
    onReady: (controller) => pickerController = controller,
    onUrisGranted: (uris) => addAttachments(uris),
    onUrisRevoked: (uris) => removeAttachments(uris),
    onSelectionComplete: closePicker,
    fallbackBuilder: (context) => YourExistingGalleryButton(),
    onError: reportPickerError,
  ),
)
```

No storage permission or custom activity code is required. To check support
before mounting the widget:

```dart
final available = await EmbeddedPhotoPickerController.isAvailable();
```

The plugin does not open a classic picker when the embedded picker is
unavailable.

For features introduced after the base API, inspect the device first:

```dart
final capabilities =
    await EmbeddedPhotoPickerController.getCapabilities();
```

### Selection constraints

Android 17/API 37 and Android 14+ with U SDK Extension 22 can disable media that
does not meet host requirements:

```dart
final options = EmbeddedPhotoPickerOptions(
  maxSelection: 4,
  selection: EmbeddedPhotoPickerSelectionOptions(
    maxMediaItemSizeInBytes: 10 * 1024 * 1024,
    maxSelectionBatchSizeInBytes: 25 * 1024 * 1024,
    minMediaItemResolutionInPixels: 1_000_000,
    maxVideoDuration: const Duration(minutes: 2),
    mimeTypes: ['image/jpeg', 'video/mp4'],
  ),
);
```

Check `capabilities.supportsSelectionConstraints` before using non-empty
constraints. On older devices, the session reports `unsupported_feature` rather
than silently ignoring them. Top-level `mimeTypes` hide unmatched media;
selection constraint MIME types leave unmatched media visible but disabled.

### Navigation and highlights

Choose the opening tab, highlight an album or search, and optionally enable
scrolling while collapsed:

```dart
final options = EmbeddedPhotoPickerOptions(
  navigation: EmbeddedPhotoPickerNavigationOptions(
    launchTab: EmbeddedPhotoPickerLaunchTab.collections,
    highlightAlbum: EmbeddedPhotoPickerHighlightAlbum.favorites,
    highlightType: EmbeddedPhotoPickerHighlightType.collapsed,
    collapsedModeScrollingEnabled: true,
  ),
);
```

Use `highlightSearchQuery` instead of `highlightAlbum` to highlight search
results. Album/search highlights require `supportsHighlights`; expanded
highlight presentation additionally requires `supportsInitialExpandedState`
and an initially expanded widget. Launch tabs and collapsed scrolling require
their corresponding capability flags. Unsupported settings report
`unsupported_feature`.

### Location metadata

Location metadata is redacted by default. On devices where
`capabilities.supportsLocationMetadata` is true, request access explicitly:

```dart
final options = EmbeddedPhotoPickerOptions(
  requestLocationMetadata: true,
);
```

Android may ask the user whether to share location metadata, and the user's
choice is final. A successful request does not guarantee metadata exists on a
selected item. Handle missing or redacted values and read metadata only while
URI access remains valid. Unsupported devices report `unsupported_feature`.

## Selection and lifecycle

- Grant and revoke callbacks contain changes, not complete selection snapshots.
  Track selected URIs in the host app and handle duplicate grants safely.
- `controller.deselect(uris)` updates Android but does not emit a revoke
  callback. Update app state after the command succeeds.
- Keep a controller only while its widget is mounted and ready. Do not dispose
  it yourself; `onReady` may provide it again after reattachment.
- Options are captured when mounted. Use a new widget key to apply new options.
- `expanded` changes the native picker mode but not the Flutter widget size.
- `visible: false` notifies Android but does not hide the Flutter widget.
- Session failures render the fallback. Remount with a new key to retry.

## Thumbnails and media

Selected values are Android `content://` URIs, not filesystem paths. Never pass
them to `File(uri.path)`. The host app owns copying, persistence, uploads, and
cleanup. Access may be revoked, and cloud media may require an asynchronous
download.

Load a bounded PNG thumbnail with the granted URI:

```dart
final png = await const EmbeddedPhotoPickerMedia().loadThumbnail(
  selectedUri,
  width: 384,
  height: 384,
);

final preview = Image.memory(png, fit: BoxFit.contain);
```

Thumbnail dimensions must be between 1 and 1024 physical pixels. The API
requires Android 10+ and existing read access; it does not request or persist
permissions. Handle `PlatformException`, revoked access, and image decoding
errors in the UI.

## Rendering constraints

The picker uses hybrid composition and a native `SurfaceView`. Give it finite
layout bounds and test interactions inside scrolling parents. Flutter content
cannot reliably draw over the picker, and Flutter's gesture arena cannot block
all native surface input. Unmount the picker before showing overlapping Flutter
menus or dialogs.

## Example

The example demonstrates previews, removal, expanded and collapsed modes, and
host-owned show/hide transitions:

```sh
cd example
flutter pub get
flutter run -d <android-id>
```

## Development

```sh
# From the package directory
flutter analyze
flutter test

cd example
flutter analyze
flutter test
flutter build apk --debug

cd android
./gradlew :embedded_photo_picker:testDebugUnitTest
```

GitHub Actions also checks formatting and validates the publication archive.
Before releasing, run:

```sh
flutter pub publish --dry-run
```

Unit tests cannot verify the remote picker surface or Android permission grants.
Test selection, revocation, cloud media, accessibility, orientation, lifecycle,
and overlays on supported and unsupported physical devices.

## References

- https://developer.android.com/training/data-storage/shared/photo-picker/embedded
- https://developer.android.com/reference/android/widget/photopicker/package-summary
- https://docs.flutter.dev/platform-integration/android/platform-views
