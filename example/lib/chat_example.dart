import 'package:embedded_photo_picker/embedded_photo_picker.dart';
import 'package:embedded_photo_picker_example/chat_message_bubble.dart';
import 'package:embedded_photo_picker_example/selected_media_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatExample extends StatefulWidget {
  const ChatExample({super.key});

  @override
  State<ChatExample> createState() => _ChatExampleState();
}

class _ChatExampleState extends State<ChatExample>
    with SingleTickerProviderStateMixin {
  final _message = TextEditingController();
  final _focus = FocusNode();
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  final _selected = <Uri>{};
  final _sent = <({String text, List<Uint8List> images})>[];
  EmbeddedPhotoPickerController? _picker;
  bool _showPicker = false;
  bool _sending = false;
  String? _error;

  void _closePicker() => setState(() {
    _showPicker = false;
    _picker = null;
    _slide.value = 0;
  });

  void _revealPicker() {
    if (!mounted || !_showPicker) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _slide.value = 1;
    } else {
      _slide.forward();
    }
  }

  Future<void> _remove(Uri uri) async {
    try {
      await _picker?.deselect([uri]);
      if (mounted) setState(() => _selected.remove(uri));
    } on PlatformException {
      if (mounted) setState(() => _error = 'Unable to remove attachment');
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (_sending || (text.isEmpty && _selected.isEmpty)) return;
    final uris = _selected.toList();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final images = await Future.wait(
        uris.map(const EmbeddedPhotoPickerMedia().loadThumbnail),
      );
      if (!mounted) return;
      if (!uris.every(_selected.contains)) {
        setState(() => _error = 'Attachments changed. Review and send again.');
        return;
      }
      if (uris.isNotEmpty) await _picker?.deselect(uris);
      if (!mounted) return;
      setState(() {
        _sent.add((text: text, images: images));
        _selected.removeAll(uris);
        _message.clear();
      });
    } on PlatformException {
      if (mounted) setState(() => _error = 'Unable to load attachments');
    } on MissingPluginException {
      if (mounted) setState(() => _error = 'Media unavailable on this device');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    _message.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6FAFC),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF6FAFC),
      titleSpacing: 0,
      title: const Row(
        children: [
          Icon(Icons.icecream_outlined, size: 22),
          SizedBox(width: 8),
          Flexible(
            child: Text('Ice cream fans', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Expanded(
              child: ListView(
                reverse: true,
                children: [
                  for (final message in _sent.reversed)
                    ChatMessageBubble(
                      text: message.text,
                      images: message.images,
                      outgoing: true,
                    ),
                  const ChatMessageBubble(
                    text: "I don't remember it, can you send me pictures?",
                    outgoing: false,
                  ),
                  const ChatMessageBubble(
                    text: "Hey Ahmed, I want the same ones we've ordered last time",
                    outgoing: true,
                  ),
                  const ChatMessageBubble(
                    text: 'Hey Yacine, what kind of ice creams do you want to get?',
                    outgoing: false,
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFD5EAF0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selected.isNotEmpty)
                      SizedBox(
                        height: 96,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          itemExtent: 88,
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _message,
                              focusNode: _focus,
                              readOnly: _sending,
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                border: InputBorder.none,
                              ),
                              onTap: _closePicker,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          IconButton(
                            tooltip: _showPicker
                                ? 'Close photos'
                                : 'Add photos',
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            onPressed: () {
                              if (_showPicker) {
                                _closePicker();
                              } else {
                                _focus.unfocus();
                                setState(() => _showPicker = true);
                              }
                            },
                          ),
                          IconButton.filled(
                            tooltip: 'Send message',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF087F8C),
                            ),
                            onPressed:
                                _sending ||
                                    (_message.text.trim().isEmpty &&
                                        _selected.isEmpty)
                                ? null
                                : _send,
                            icon: _sending
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showPicker)
              AnimatedBuilder(
                animation: _slide,
                builder: (context, child) {
                  final pickerHeight = constraints.maxHeight * 0.36;
                  return SizedBox(
                    height:
                        pickerHeight *
                        Curves.easeInOutCubic.transform(_slide.value),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: pickerHeight,
                          child: child!,
                        ),
                      ],
                    ),
                  );
                },
                child: EmbeddedPhotoPicker(
                  options: EmbeddedPhotoPickerOptions(
                    maxSelection: 4,
                    mimeTypes: ['image/*'],
                    preselectedUris: _selected.toList(),
                  ),
                  expanded: false,
                  onReady: (controller) {
                    _picker = controller;
                    _revealPicker();
                  },
                  onUrisGranted: (uris) =>
                      setState(() => _selected.addAll(uris)),
                  onUrisRevoked: (uris) =>
                      setState(() => _selected.removeAll(uris)),
                  onSelectionComplete: _closePicker,
                  onError: (_) => setState(() {
                    _picker = null;
                    _error = 'Photo picker unavailable';
                  }),
                  fallbackBuilder: (_) {
                    if (_showPicker && _slide.isDismissed) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _revealPicker(),
                      );
                    }
                    return const Center(child: Text('Picker unavailable'));
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
