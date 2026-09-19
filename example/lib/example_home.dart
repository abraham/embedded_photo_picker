import 'package:embedded_photo_picker_example/chat_example.dart';
import 'package:embedded_photo_picker_example/picker_example.dart';
import 'package:flutter/material.dart';

class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Photo picker examples')),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Compose'),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const PickerExample()),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Expanded photo picker',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat'),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const ChatExample()),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Collapsed photo picker',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
