import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'picker_codec.dart';
import 'picker_config.dart';
import 'picker_platform.dart';
import 'picker_support.dart';

/// A complete picker selection and the native delta that produced it.
@immutable
class PickerSelectionChange {
  /// Creates an immutable selection snapshot and native delta.
  PickerSelectionChange({
    required List<Uri> selection,
    List<Uri> added = const [],
    List<Uri> removed = const [],
  }) : selection = List.unmodifiable(selection),
       added = List.unmodifiable(added),
       removed = List.unmodifiable(removed);

  /// The current ordered selection snapshot.
  final List<Uri> selection;

  /// URIs newly granted by Android.
  final List<Uri> added;

  /// URIs whose grants Android revoked.
  final List<Uri> removed;
}

/// Embeds Android's system photo picker using hybrid composition.
///
/// [selection] is controlled by the host. Native grants and revocations are
/// reported as immutable snapshots through [onChanged]. Removing an item from
/// [selection] also deselects it in Android.
class EmbeddedPhotoPicker extends StatefulWidget {
  /// Creates a bounded inline picker with declarative selection state.
  const EmbeddedPhotoPicker({
    required this.selection,
    required this.onChanged,
    super.key,
    this.config = PickerConfig.defaults,
    this.onDone,
    this.onReady,
    this.onError,
    this.loadingBuilder,
    this.fallbackBuilder,
    this.expanded = true,
    this.visible = true,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  /// Checks whether a device supports the base picker and every feature in
  /// [config]. The widget performs this check automatically before mounting.
  static Future<PickerSupport> checkSupport([
    PickerConfig config = PickerConfig.defaults,
  ]) => PickerPlatform.checkSupport(config);

  /// The current ordered selection owned by the host application.
  final List<Uri> selection;

  /// Called for native grants and revocations with a complete snapshot.
  final ValueChanged<PickerSelectionChange> onChanged;

  /// Creation-time picker configuration.
  final PickerConfig config;

  /// Called when the user indicates they are done selecting.
  final ValueChanged<List<Uri>>? onDone;

  /// Called when the native picker is ready.
  final VoidCallback? onReady;

  /// Called before a failed picker switches to [fallbackBuilder].
  final ValueChanged<PlatformException>? onError;

  /// UI displayed while checking device and feature support.
  final WidgetBuilder? loadingBuilder;

  /// UI displayed for unsupported devices, configurations, or session errors.
  final WidgetBuilder? fallbackBuilder;

  /// Whether to show Android's expanded picker features.
  final bool expanded;

  /// Whether the mounted picker is visible to the user.
  final bool visible;

  /// Gestures forwarded to Flutter's platform-view gesture arena.
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  @override
  State<EmbeddedPhotoPicker> createState() => _EmbeddedPhotoPickerState();
}

class _EmbeddedPhotoPickerState extends State<EmbeddedPhotoPicker> {
  NativePickerController? _controller;
  PickerSupport? _support;
  late List<Uri> _selection = _copySelection(widget.selection);
  bool _ready = false;
  bool _failed = false;
  int _viewGeneration = 0;
  int _supportGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_checkSupport());
  }

  Future<void> _checkSupport() async {
    final generation = ++_supportGeneration;
    if (!widget.expanded &&
        widget.config.presentation?.highlight?.style ==
            PickerHighlightStyle.expanded) {
      _fail(
        PlatformException(
          code: 'invalid_configuration',
          message: 'Expanded highlights require an expanded picker',
        ),
      );
      return;
    }
    try {
      final support = await EmbeddedPhotoPicker.checkSupport(widget.config);
      if (!mounted || generation != _supportGeneration) return;
      setState(() => _support = support);
      if (support.available && support.unsupportedFeatures.isNotEmpty) {
        widget.onError?.call(
          PlatformException(
            code: 'unsupported_feature',
            message:
                'Unsupported picker features: '
                '${support.unsupportedFeatures.map((feature) => feature.name).join(', ')}',
          ),
        );
      }
    } on PlatformException catch (error) {
      _fail(error);
    }
  }

  void _created(int viewId, int generation) {
    if (!mounted ||
        generation != _viewGeneration ||
        _support?.isSupported != true) {
      return;
    }
    final controller = NativePickerController(
      viewId,
      onReady: () {
        if (!mounted) return;
        _ready = true;
        unawaited(_synchronize());
      },
      onGranted: _granted,
      onRevoked: _revoked,
      onComplete: () => widget.onDone?.call(List.unmodifiable(_selection)),
      onError: _fail,
    );
    _controller = controller;
    unawaited(_guard(controller.connect));
  }

  void _granted(List<Uri> uris) {
    final added = uris.where((uri) => !_selection.contains(uri)).toList();
    if (added.isEmpty) return;
    _selection = List.unmodifiable([..._selection, ...added]);
    widget.onChanged(
      PickerSelectionChange(selection: _selection, added: added),
    );
  }

  void _revoked(List<Uri> uris) {
    final removed = uris.where(_selection.contains).toList();
    if (removed.isEmpty) return;
    final removedSet = removed.toSet();
    _selection = List.unmodifiable(
      _selection.where((uri) => !removedSet.contains(uri)),
    );
    widget.onChanged(
      PickerSelectionChange(selection: _selection, removed: removed),
    );
  }

  Future<void> _synchronize({bool notifyReady = true}) async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    await _guard(() async {
      await controller.setExpanded(widget.expanded);
      if (!mounted || _controller != controller) return;
      await controller.setVisible(widget.visible);
      if (mounted && _controller == controller && notifyReady) {
        widget.onReady?.call();
      }
    });
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

  void _fail(PlatformException error) {
    if (!mounted || _failed) return;
    _controller?.dispose();
    _controller = null;
    _ready = false;
    setState(() => _failed = true);
    widget.onError?.call(error);
  }

  @override
  void didUpdateWidget(EmbeddedPhotoPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSelection = _copySelection(widget.selection);
    final nextSet = nextSelection.toSet();
    final removed = _selection.where((uri) => !nextSet.contains(uri)).toList();
    final currentSet = _selection.toSet();
    final added = nextSelection
        .where((uri) => !currentSet.contains(uri))
        .toList();
    _selection = nextSelection;

    if (oldWidget.config != widget.config || added.isNotEmpty) {
      _remount(recheckSupport: oldWidget.config != widget.config);
      return;
    }
    if (removed.isNotEmpty) {
      if (_ready && _controller != null) {
        unawaited(_guard(() => _controller!.deselect(removed)));
      } else {
        _remount(recheckSupport: false);
        return;
      }
    }
    if (oldWidget.expanded != widget.expanded ||
        oldWidget.visible != widget.visible) {
      unawaited(_synchronize(notifyReady: false));
    }
  }

  void _remount({required bool recheckSupport}) {
    _controller?.dispose();
    _controller = null;
    _ready = false;
    _failed = false;
    _viewGeneration++;
    if (recheckSupport) {
      _support = null;
      unawaited(_checkSupport());
    }
  }

  @override
  void dispose() {
    _supportGeneration++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.fallbackBuilder?.call(context) ?? const SizedBox.shrink();
    }
    final support = _support;
    if (support == null) {
      return widget.loadingBuilder?.call(context) ?? const SizedBox.shrink();
    }
    if (!support.isSupported) {
      return widget.fallbackBuilder?.call(context) ?? const SizedBox.shrink();
    }
    return KeyedSubtree(
      key: ValueKey(_viewGeneration),
      child: PlatformViewLink(
        viewType: 'embedded_photo_picker/view',
        surfaceFactory: (context, controller) => AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: widget.gestureRecognizers,
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        ),
        onCreatePlatformView: (params) {
          final generation = _viewGeneration;
          final creationParams = {
            ...encodePickerConfig(widget.config, _selection),
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
          controller.addOnPlatformViewCreatedListener(
            (viewId) => _created(viewId, generation),
          );
          unawaited(_guard(controller.create));
          return controller;
        },
      ),
    );
  }
}

List<Uri> _copySelection(List<Uri> selection) => List.unmodifiable(selection);
