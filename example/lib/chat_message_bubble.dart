import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.text,
    required this.outgoing,
    this.images = const [],
    super.key,
  });

  final String text;
  final bool outgoing;
  final List<Uint8List> images;

  @override
  Widget build(BuildContext context) => Align(
    alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment: outgoing
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              outgoing ? 'Me' : 'Ahmed',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            DecoratedBox(
              decoration: BoxDecoration(
                color: outgoing
                    ? const Color(0xFFA5EFF5)
                    : const Color(0xFFE3E6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final bytes in images)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Image.memory(
                          bytes,
                          width: 240,
                          height: 160,
                          fit: BoxFit.contain,
                          semanticLabel: 'Sent photo',
                          errorBuilder: (_, _, _) => const SizedBox(
                            height: 80,
                            child: Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    if (text.isNotEmpty) Text(text),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
