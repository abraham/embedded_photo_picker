import 'dart:async';

import 'package:embedded_photo_picker/src/embedded_photo_picker_controller.dart';
import 'package:embedded_photo_picker/src/embedded_photo_picker_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Embeds Android's system photo picker using hybrid composition.
///
/// Supply bounded width and height. Keep the widget mounted to preserve its
/// session. Options are captured on mount; use a new key to change them.
/// No permissions or fallback picker activities are launched automatically.
class EmbeddedPhotoPicker extends StatefulWidget {
  /// Creates an inline picker with host-owned selection and fallback UI.
  const EmbeddedPhotoPicker({
    required this.options,
    required this.onUrisGranted,
    required this.onUrisRevoked,
    required this.onSelectionComplete,
    required this.fallbackBuilder,
    super.key,
    this.onReady,
    this.onError,
    this.loadingBuilder,
    this.expanded = true,
    this.visible = true,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  /// Creation-time native session options.
  final EmbeddedPhotoPickerOptions options;

  /// Newly accessible media, which may require a cloud download when opened.
  final ValueChanged<List<Uri>> onUrisGranted;

  /// Media deselected by the user, whose grants may already be revoked.
  final ValueChanged<List<Uri>> onUrisRevoked;

  /// Completion notification; the host decides whether to hide the picker.
  final VoidCallback onSelectionComplete;

  /// UI for unavailable devices or failed sessions; no native picker is kept.
  final WidgetBuilder fallbackBuilder;

  /// Called when the native session is ready to accept controller commands.
  final ValueChanged<EmbeddedPhotoPickerController>? onReady;

  /// Session or platform errors, delivered before switching to the fallback.
  final ValueChanged<PlatformException>? onError;

  /// UI displayed during the device capability check.
  final WidgetBuilder? loadingBuilder;

  /// Whether to show Android's expanded picker features.
  ///
  /// This does not resize the widget. Collapsed mode may not allow scrolling.
  final bool expanded;

  /// Whether the picker is visible, including when obscured by another route.
  ///
  /// This only notifies Android's session; it does not hide the native surface.
  /// Remove the widget before showing overlapping Flutter dialogs or menus.
  final bool visible;

  /// Gestures forwarded to the platform view by Flutter's gesture arena.
  ///
  /// The remote Android surface also receives native input directly. This
  /// setting cannot be used to block interaction with that surface.
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  @override
  State<EmbeddedPhotoPicker> createState() => _EmbeddedPhotoPickerState();
}

class _EmbeddedPhotoPickerState extends State<EmbeddedPhotoPicker> {
  late final EmbeddedPhotoPickerOptions _options = widget.options;
  EmbeddedPhotoPickerController? _controller;
  bool? _available;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_checkAvailability());
  }

  Future<void> _checkAvailability() async {
    try {
      final available = await EmbeddedPhotoPickerController.isAvailable();
      if (mounted) setState(() => _available = available);
    } on PlatformException catch (error) {
      _fail(error);
    }
  }

  void _fail(PlatformException error) {
    if (!mounted || _available == false) return;
    _controller?.dispose();
    _controller = null;
    _ready = false;
    setState(() => _available = false);
    widget.onError?.call(error);
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException catch (error) {
      _fail(error);
    } on MissingPluginException catch (error) {
      _fail(PlatformException(code: 'missing_plugin', message: error.message));
    }
  }

  void _created(int viewId) {
    if (!mounted || _available != true) return;
    final controller = EmbeddedPhotoPickerController(
      viewId,
      onReady: () {
        if (!mounted) return;
        _ready = true;
        unawaited(_synchronize());
      },
      onGranted: (uris) => widget.onUrisGranted(uris),
      onRevoked: (uris) => widget.onUrisRevoked(uris),
      onComplete: () => widget.onSelectionComplete(),
      onError: _fail,
    );
    _controller = controller;
    unawaited(_guard(controller.connect));
  }

  Future<void> _synchronize({bool notifyReady = true}) async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    await _guard(() async {
      await controller.setExpanded(expanded: widget.expanded);
      if (!mounted || _controller != controller) return;
      await controller.setVisible(visible: widget.visible);
      if (mounted && _controller == controller && notifyReady) {
        widget.onReady?.call(controller);
      }
    });
  }

  @override
  void didUpdateWidget(EmbeddedPhotoPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded ||
        oldWidget.visible != widget.visible) {
      unawaited(_synchronize(notifyReady: false));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_available == null) {
      return widget.loadingBuilder?.call(context) ?? const SizedBox.shrink();
    }
    if (!_available!) return widget.fallbackBuilder(context);
    return PlatformViewLink(
      viewType: 'embedded_photo_picker/view',
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: widget.gestureRecognizers,
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        final creationParams = {
          ..._options.toMap(),
          'initialExpanded': widget.expanded,
        };
        final controller = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: 'embedded_photo_picker/view',
          layoutDirection: Directionality.of(context),
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        );
        controller.addOnPlatformViewCreatedListener(
          params.onPlatformViewCreated,
        );
        controller.addOnPlatformViewCreatedListener(_created);
        unawaited(_guard(controller.create));
        return controller;
      },
    );
  }
}
