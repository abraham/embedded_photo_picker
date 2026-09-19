import 'package:embedded_photo_picker/embedded_photo_picker.dart';
import 'package:embedded_photo_picker_example/selected_media_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PickerExample extends StatefulWidget {
  const PickerExample({super.key});

  @override
  State<PickerExample> createState() => _PickerExampleState();
}

class _PickerExampleState extends State<PickerExample>
    with SingleTickerProviderStateMixin {
  final _selected = <Uri>{};
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..addStatusListener(_slideStatusChanged);
  EmbeddedPhotoPickerController? _controller;
  bool _showPicker = false;
  bool _pickerMounted = false;
  double _pickerFraction = 0.75;
  String? _error;

  void _resizePicker(double fraction) {
    if (!_showPicker || !_slide.isCompleted) return;
    if (fraction <= 0) {
      _close();
      return;
    }
    setState(() => _pickerFraction = fraction.clamp(0.0, 1.0));
  }

  Future<void> _remove(Uri uri) async {
    try {
      await _controller?.deselect([uri]);
      if (mounted) setState(() => _selected.remove(uri));
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  void _slideStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !_showPicker) {
      setState(() {
        _controller = null;
        _pickerMounted = false;
      });
    }
  }

  void _close() {
    setState(() => _showPicker = false);
    if (_slide.isDismissed || MediaQuery.disableAnimationsOf(context)) {
      _slide.value = 0;
      _slideStatusChanged(AnimationStatus.dismissed);
    } else {
      _slide.reverse();
    }
  }

  void _open() {
    final reversing = _pickerMounted;
    setState(() {
      _error = null;
      if (!reversing) _pickerFraction = _pickerFraction.clamp(0.35, 1.0);
      _showPicker = true;
      _pickerMounted = true;
    });
    if (reversing) _reveal();
  }

  void _reveal() {
    if (!mounted || !_showPicker) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _slide.value = 1;
    } else {
      _slide.forward();
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Photo picker')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const TextField(
                  minLines: 5,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: _showPicker ? 'Close picker' : 'Open picker',
                      icon: const Icon(Icons.photo_library_outlined),
                      onPressed: () {
                        if (_showPicker) {
                          _close();
                        } else {
                          _open();
                        }
                      },
                    ),
                    const FilledButton(onPressed: null, child: Text('Post')),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => AnimatedBuilder(
                animation: _slide,
                builder: (context, child) {
                  final handleHeight = constraints.maxHeight.clamp(0.0, 48.0);
                  final previewHeight = _selected.isEmpty ? 0.0 : 96.0;
                  final maxPanelHeight = (constraints.maxHeight - previewHeight)
                      .clamp(handleHeight, constraints.maxHeight);
                  final panelHeight = (constraints.maxHeight * _pickerFraction)
                      .clamp(handleHeight, maxPanelHeight);
                  final pickerHeight = panelHeight - handleHeight;
                  final visibleHeight =
                      panelHeight *
                      Curves.easeInOutCubic.transform(_slide.value);
                  return Stack(
                    children: [
                      Positioned.fill(
                        bottom: visibleHeight,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            height: 144,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.all(16),
                              itemExtent: 120,
                              children: [
                                for (final uri in _selected)
                                  Padding(
                                    key: ValueKey(uri),
                                    padding: const EdgeInsets.only(right: 8),
                                    child: SelectedMediaPreview(
                                      uri: uri,
                                      onRemove: () => _remove(uri),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_pickerMounted)
                        Positioned(
                          top:
                              constraints.maxHeight -
                              visibleHeight +
                              handleHeight,
                          left: 0,
                          right: 0,
                          height: pickerHeight,
                          child: EmbeddedPhotoPicker(
                            options: EmbeddedPhotoPickerOptions(
                              maxSelection: 4,
                              preselectedUris: _selected.toList(),
                              orderedSelection: true,
                            ),
                            onReady: (controller) {
                              _controller = controller;
                              _reveal();
                            },
                            onUrisGranted: (uris) =>
                                setState(() => _selected.addAll(uris)),
                            onUrisRevoked: (uris) =>
                                setState(() => _selected.removeAll(uris)),
                            onSelectionComplete: _close,
                            onError: (error) => setState(() {
                              _controller = null;
                              _error = error.message ?? error.code;
                            }),
                            loadingBuilder: (_) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            fallbackBuilder: (_) {
                              if (_showPicker && _slide.isDismissed) {
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _reveal(),
                                );
                              }
                              return const Center(
                                child: Text('Picker unavailable'),
                              );
                            },
                          ),
                        ),
                      if (_pickerMounted)
                        Positioned(
                          top: constraints.maxHeight - visibleHeight,
                          left: 0,
                          right: 0,
                          height: handleHeight,
                          child: Semantics(
                            label: 'Resize photo picker',
                            value: '${(_pickerFraction * 100).round()}%',
                            increasedValue:
                                '${((_pickerFraction + 0.1).clamp(0.0, 1.0) * 100).round()}%',
                            decreasedValue:
                                '${((_pickerFraction - 0.1).clamp(0.0, 1.0) * 100).round()}%',
                            onIncrease: () =>
                                _resizePicker(_pickerFraction + 0.1),
                            onDecrease: () =>
                                _resizePicker(_pickerFraction - 0.1),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.resizeUpDown,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragUpdate: (details) {
                                  if (!_showPicker ||
                                      !_slide.isCompleted ||
                                      constraints.maxHeight <= handleHeight) {
                                    return;
                                  }
                                  final currentHeight =
                                      (constraints.maxHeight * _pickerFraction)
                                          .clamp(handleHeight, maxPanelHeight);
                                  final nextHeight =
                                      currentHeight - details.delta.dy;
                                  if (nextHeight <= handleHeight) {
                                    _close();
                                    return;
                                  }
                                  _resizePicker(
                                    nextHeight / constraints.maxHeight,
                                  );
                                },
                                child: Material(
                                  color: Colors.transparent,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(28),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(28),
                                      ),
                                      border: Border(
                                        top: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant,
                                        ),
                                      ),
                                    ),
                                    child: Center(
                                      child: SizedBox(
                                        width: 32,
                                        height: 4,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
