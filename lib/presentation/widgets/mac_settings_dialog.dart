import 'package:flutter/material.dart';

import '../../data/repositories/settings_repository.dart';

/// Editor for the "send to Mac" endpoint: URL, bearer token, certificate pin.
class MacSettingsDialog extends StatefulWidget {
  const MacSettingsDialog({super.key, required this.repository, required this.settings});

  final SettingsRepository repository;
  final AppSettings settings;

  @override
  State<MacSettingsDialog> createState() => _MacSettingsDialogState();
}

class _MacSettingsDialogState extends State<MacSettingsDialog> {
  late final TextEditingController _url =
      TextEditingController(text: widget.settings.macUrl);
  late final TextEditingController _token =
      TextEditingController(text: widget.settings.macToken);
  late final TextEditingController _pin =
      TextEditingController(text: widget.settings.macPin);

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Отправка на Mac'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Адрес',
                hintText: 'https://153.56.176.100:8443',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _token,
              autocorrect: false,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Токен'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Отпечаток сертификата (необязательно)',
                hintText: 'sha256 в hex',
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              await widget.repository.setMacUrl(_url.text);
              await widget.repository.setMacToken(_token.text);
              await widget.repository.setMacPin(_pin.text);
              if (context.mounted) Navigator.of(context).pop(true);
            },
            child: const Text('Сохранить'),
          ),
        ],
      );
}
