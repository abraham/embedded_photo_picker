import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Commands and events for one native picker view.
///
/// The widget owns this controller. Commands require an open session and throw
/// [PlatformException] if Android cannot complete them. URIs are not file paths.
class EmbeddedPhotoPickerController {
  /// Connects to a platform view; normally created by the picker widget.
  @internal
  EmbeddedPhotoPickerController(
    int viewId, {
    required this.onReady,
    required this.onGranted,
    required this.onRevoked,
    required this.onComplete,
    required this.onError,
  }) : _channel = MethodChannel('embedded_photo_picker/view/$viewId') {
    _channel.setMethodCallHandler(_handleCall);
  }

  final MethodChannel _channel;
  bool _disposed = false;

  /// The callback when Android opens a session, including after reattachment.
  final VoidCallback onReady;

  /// The callback for newly granted media URIs.
  final ValueChanged<List<Uri>> onGranted;

  /// The callback for media deselected inside the native picker.
  final ValueChanged<List<Uri>> onRevoked;

  /// The callback when the user completes selection.
  final VoidCallback onComplete;

  /// The callback for native session failures.
  final ValueChanged<PlatformException> onError;

  /// Checks device capability without creating a native view.
  ///
  /// Returns `false` on other platforms or when the plugin is not registered.
  /// Session opening can still fail after a successful capability check.
  static Future<bool> isAvailable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await const MethodChannel('embedded_photo_picker')
              .invokeMethod<bool>('isAvailable') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Starts event delivery after the Dart listener is registered.
  @internal
  Future<void> connect() => _invoke('connect');

  /// Notifies Android of expanded or collapsed presentation.
  ///
  /// The host must separately resize the Flutter layout.
  Future<void> setExpanded({required bool expanded}) =>
      _invoke('setExpanded', expanded);

  /// Notifies Android when a mounted picker is hidden behind another route.
  Future<void> setVisible({required bool visible}) =>
      _invoke('setVisible', visible);

  /// Deselects URIs in Android without emitting [onRevoked].
  ///
  /// Update the host's own selection after this succeeds. The host must also
  /// cancel pending work and remove any copies it owns for deselected items.
  Future<void> deselect(List<Uri> uris) {
    if (uris.any((uri) => uri.scheme != 'content' || uri.authority.isEmpty)) {
      throw ArgumentError.value(uris, 'uris', 'Expected content URIs');
    }
    return _invoke('deselect', uris.map((uri) => uri.toString()).toList());
  }

  Future<void> _invoke(String method, [Object? arguments]) {
    if (_disposed) throw StateError('The picker controller has been disposed');
    return _channel.invokeMethod<void>(method, arguments);
  }

  Future<void> _handleCall(MethodCall call) async {
    if (_disposed) return;
    switch (call.method) {
      case 'ready':
        onReady();
      case 'granted':
        onGranted(_uris(call.arguments));
      case 'revoked':
        onRevoked(_uris(call.arguments));
      case 'complete':
        onComplete();
      case 'error':
        final details = Map<Object?, Object?>.from(call.arguments as Map);
        onError(
          PlatformException(
            code: details['code']! as String,
            message: details['message'] as String?,
          ),
        );
    }
  }

  List<Uri> _uris(Object? arguments) =>
      List.unmodifiable((arguments! as List).cast<String>().map(Uri.parse));

  /// Disconnects Dart callbacks; the platform view releases native resources.
  @internal
  void dispose() {
    _disposed = true;
    _channel.setMethodCallHandler(null);
  }
}
