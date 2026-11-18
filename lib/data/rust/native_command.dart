import 'dart:convert';

import 'wispie_core.dart';

/// Runs one one-shot command and returns its JSON reply.
///
/// The core answers a one-shot request with a single items event, and reports a
/// rejection as an error event plus a non-zero return code.
Map<String, dynamic> runCoreCommand(
  String command,
  Map<String, Object?> request,
) {
  Map<String, dynamic>? reply;
  String? error;
  final code = WispieCore.run(
    {'command': command, ...request},
    onEvent: (kind, payload) {
      if (kind == WispieCore.eventItems) {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) reply = decoded;
      } else if (kind == WispieCore.eventError) {
        error =
            (jsonDecode(payload) as Map<String, dynamic>)['message'] as String?;
      }
    },
  );
  if (code != 0 || reply == null) {
    throw StateError('$command request failed: ${error ?? 'code $code'}');
  }
  return reply!;
}
