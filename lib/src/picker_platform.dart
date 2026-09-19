import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'picker_config.dart';
import 'picker_support.dart';

class PickerPlatform {
  static const _channel = MethodChannel('embedded_photo_picker');

  static Future<PickerSupport> checkSupport(PickerConfig config) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _unsupported(config);
    }
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>(
        'getCapabilities',
      );
      if (map == null) return _unsupported(config);
      final supported = <PickerFeature>{
        if (map['supportsHighlights'] == true) PickerFeature.highlights,
        if (map['supportsInitialExpandedState'] == true)
          PickerFeature.initialExpandedState,
        if (map['supportsSelectionConstraints'] == true)
          PickerFeature.selectionConstraints,
        if (map['supportsLaunchTab'] == true) PickerFeature.launchTab,
        if (map['supportsLocationMetadata'] == true)
          PickerFeature.locationMetadata,
        if (map['supportsCollapsedModeScrolling'] == true)
          PickerFeature.collapsedModeScrolling,
        if (map['supportsEmbeddedUiCustomization'] == true)
          PickerFeature.embeddedUiCustomization,
      };
      final required = config.requiredFeatures;
      return PickerSupport(
        available: map['available'] as bool? ?? false,
        androidApiLevel: map['androidApiLevel'] as int? ?? 0,
        uExtensionVersion: map['uExtensionVersion'] as int? ?? 0,
        supportedFeatures: Set.unmodifiable(supported),
        unsupportedFeatures: Set.unmodifiable(required.difference(supported)),
      );
    } on MissingPluginException {
      return _unsupported(config);
    }
  }

  static PickerSupport _unsupported(PickerConfig config) => PickerSupport(
    available: false,
    androidApiLevel: 0,
    uExtensionVersion: 0,
    supportedFeatures: const {},
    unsupportedFeatures: config.requiredFeatures,
  );
}

class NativePickerController {
  NativePickerController(
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
  final VoidCallback onReady;
  final ValueChanged<List<Uri>> onGranted;
  final ValueChanged<List<Uri>> onRevoked;
  final VoidCallback onComplete;
  final ValueChanged<PlatformException> onError;
  bool _disposed = false;

  Future<void> connect() => _invoke('connect');

  Future<void> setExpanded(bool expanded) => _invoke('setExpanded', expanded);

  Future<void> setVisible(bool visible) => _invoke('setVisible', visible);

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

  void dispose() {
    _disposed = true;
    _channel.setMethodCallHandler(null);
  }
}
