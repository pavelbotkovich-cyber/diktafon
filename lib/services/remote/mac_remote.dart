import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Configuration for the "send to Mac" feature.
///
/// Values live in the app's key-value settings; the token is never logged.
class MacRemoteConfig {
  const MacRemoteConfig({
    required this.baseUrl,
    required this.token,
    this.pinSha256 = '',
  });

  final String baseUrl;
  final String token;

  /// Lower-case hex SHA-256 of the server certificate DER. Empty = accept any
  /// certificate (only for a first local test).
  final String pinSha256;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty && token.trim().isNotEmpty;
}

class MacRemoteException implements Exception {
  MacRemoteException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MacRemoteResult {
  const MacRemoteResult({
    required this.title,
    required this.status,
    this.transcript,
    this.error,
    this.words,
  });

  final String title;
  final String status;
  final String? transcript;
  final String? error;
  final int? words;

  bool get isDone => status == 'done';
}

/// Minimal client for the Mac dictaphone service.
///
/// Upload uses a raw octet-stream body: no multipart parsing on either side.
class MacRemoteClient {
  MacRemoteClient(this.config);

  final MacRemoteConfig config;

  static const _pollInterval = Duration(seconds: 3);
  static const _pollTimeout = Duration(minutes: 15);

  String get _base => config.baseUrl.replaceAll(RegExp(r'/+$'), '');

  HttpClient _client() {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    final pin = config.pinSha256.replaceAll(':', '').trim().toLowerCase();
    if (pin.isNotEmpty) {
      client.badCertificateCallback = (cert, host, port) =>
          sha256.convert(cert.der).toString().toLowerCase() == pin;
    }
    return client;
  }

  Future<String> upload(File file, {required String title}) async {
    final client = _client();
    try {
      final request = await client.postUrl(Uri.parse('$_base/v1/recordings'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${config.token}');
      request.headers.set('X-Filename', file.uri.pathSegments.last);
      request.headers.set('X-Title', title);
      request.headers.contentType = ContentType.binary;
      request.contentLength = await file.length();
      await request.addStream(file.openRead());
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 202) {
        throw MacRemoteException('HTTP ${response.statusCode}: $body');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['id'] as String;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> status(String id) async {
    final client = _client();
    try {
      final request = await client.getUrl(Uri.parse('$_base/v1/recordings/$id'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${config.token}');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw MacRemoteException('HTTP ${response.statusCode}: $body');
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  /// Uploads every memo and waits until each job finishes.
  Future<List<MacRemoteResult>> sendAll(
    List<({File file, String title})> items, {
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <MacRemoteResult>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      try {
        final id = await upload(item.file, title: item.title);
        final data = await _wait(id);
        results.add(MacRemoteResult(
          title: item.title,
          status: (data['status'] as String?) ?? 'error',
          transcript: data['transcript'] as String?,
          error: data['error'] as String?,
          words: data['words'] as int?,
        ));
      } on MacRemoteException catch (e) {
        results.add(MacRemoteResult(
            title: item.title, status: 'error', error: e.message));
      } on SocketException catch (e) {
        results.add(MacRemoteResult(
            title: item.title, status: 'error', error: 'нет связи: ${e.message}'));
      }
      onProgress?.call(i + 1, items.length);
    }
    return results;
  }

  Future<Map<String, dynamic>> _wait(String id) async {
    final deadline = DateTime.now().add(_pollTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final data = await status(id);
      final state = data['status'] as String?;
      if (state == 'done' || state == 'error') return data;
      await Future<void>.delayed(_pollInterval);
    }
    return const {'status': 'error', 'error': 'истекло время ожидания'};
  }
}
