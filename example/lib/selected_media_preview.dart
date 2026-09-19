import 'package:embedded_photo_picker/embedded_photo_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SelectedMediaPreview extends StatefulWidget {
  const SelectedMediaPreview({
    required this.uri,
    required this.onRemove,
    super.key,
  });

  final Uri uri;
  final VoidCallback onRemove;

  @override
  State<SelectedMediaPreview> createState() => _SelectedMediaPreviewState();
}

class _SelectedMediaPreviewState extends State<SelectedMediaPreview> {
  late Future<Uint8List> _thumbnail = const EmbeddedPhotoPickerMedia()
      .loadThumbnail(widget.uri);

  @override
  void didUpdateWidget(SelectedMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _thumbnail = const EmbeddedPhotoPickerMedia().loadThumbnail(widget.uri);
    }
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List>(
            future: _thumbnail,
            builder: (context, snapshot) {
              const unavailable = Center(
                child: Tooltip(
                  message: 'Preview unavailable',
                  child: Icon(Icons.broken_image_outlined),
                ),
              );
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final bytes = snapshot.data;
              if (bytes == null) return unavailable;
              return Image.memory(
                bytes,
                fit: BoxFit.contain,
                semanticLabel: 'Selected image',
                errorBuilder: (_, _, _) => unavailable,
              );
            },
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton.filledTonal(
              tooltip: 'Remove attachment',
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onRemove,
            ),
          ),
        ],
      ),
    ),
  );
}
