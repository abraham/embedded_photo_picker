import 'package:flutter/services.dart';

/// Reads thumbnails for Android content URIs with existing read access.
///
/// This does not request or persist URI permissions, copy original media, or
/// cache thumbnails. It can also load thumbnails for selected videos.
class EmbeddedPhotoPickerMedia {
  /// Creates a media repository backed by Android's content resolver.
  const EmbeddedPhotoPickerMedia();

  static const _channel = MethodChannel('embedded_photo_picker/media');

  /// Loads a PNG thumbnail, requesting [width] and [height] in physical pixels.
  ///
  /// Each dimension must be between 1 and 1024. Android may return a thumbnail
  /// with a different aspect ratio or size. Requires Android 10 or newer and
  /// an accessible `content://` URI. Cloud providers may download media.
  ///
  /// Throws [ArgumentError] for invalid arguments and [PlatformException] with
  /// code `thumbnail_unavailable` for failed reads or revoked permissions, or
  /// `unsupported_platform` on older Android versions. On platforms without
  /// this plugin, throws [MissingPluginException].
  Future<Uint8List> loadThumbnail(
    Uri uri, {
    int width = 384,
    int height = 384,
  }) async {
    if (uri.scheme != 'content' || uri.authority.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'Expected an Android content URI');
    }
    RangeError.checkValueInInterval(width, 1, 1024, 'width');
    RangeError.checkValueInInterval(height, 1, 1024, 'height');
    final bytes = await _channel.invokeMethod<Uint8List>('loadThumbnail', {
      'uri': uri.toString(),
      'width': width,
      'height': height,
    });
    if (bytes == null || bytes.isEmpty) {
      throw PlatformException(code: 'thumbnail_unavailable');
    }
    return bytes;
  }
}
