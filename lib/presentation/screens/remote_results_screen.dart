import 'package:flutter/material.dart';

import '../../services/remote/mac_remote.dart';

/// Shows transcripts returned by the Mac after a "send" run.
class RemoteResultsScreen extends StatelessWidget {
  const RemoteResultsScreen({super.key, required this.results});

  final List<MacRemoteResult> results;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Результат с Mac')),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(height: 32),
          itemBuilder: (context, i) {
            final r = results[i];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                r.isDone
                    ? 'готово${r.words != null ? ' · ${r.words} слов' : ''}'
                    : 'ошибка: ${r.error ?? r.status}',
                style: TextStyle(
                  color: r.isDone
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              if (r.transcript != null && r.transcript!.isNotEmpty)
                SelectableText(r.transcript!),
            ]);
          },
        ),
      );
}
