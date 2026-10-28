import 'dart:io';

import 'package:diktafon/services/remote/mac_remote.dart';

/// Smoke test for the "send to Mac" client: real HTTPS request, real pin.
///
/// Usage:
///   dart run tool/remote_smoke.dart <audio-file> <token-file> [pin] [base-url]
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/remote_smoke.dart <audio> <token-file> [pin] [base-url]');
    exit(64);
  }
  final audio = File(args[0]);
  final token = File(args[1]).readAsStringSync().trim();
  final pin = args.length > 2 ? args[2] : '';
  final base = args.length > 3 ? args[3] : 'https://127.0.0.1:8444';
  final client = MacRemoteClient(MacRemoteConfig(
    baseUrl: base,
    token: token,
    pinSha256: pin,
  ));
  final results = await client.sendAll([
    (file: audio, title: 'smoke ${DateTime.now().toIso8601String()}'),
  ]);
  for (final r in results) {
    print('status=${r.status} words=${r.words}');
    if (r.error != null) print('error=${r.error}');
    print((r.transcript ?? '').split('\n').take(3).join('\n'));
  }
  exit(results.first.isDone ? 0 : 1);
}
