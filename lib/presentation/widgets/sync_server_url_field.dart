import 'package:flutter/material.dart';

import '../../services/sync/account_service.dart';
import '../../services/sync/api_client.dart';
import '../tokens/app_tokens.dart';

typedef ServerProbe = Future<SyncServerInfo> Function(String url);

/// Server URL input that validates through `GET /v1/info`.
class SyncServerUrlField extends StatefulWidget {
  final TextEditingController controller;
  final ServerProbe probe;
  final bool enabled;

  const SyncServerUrlField({
    super.key,
    required this.controller,
    required this.probe,
    this.enabled = true,
  });

  @override
  State<SyncServerUrlField> createState() => _SyncServerUrlFieldState();
}

class _SyncServerUrlFieldState extends State<SyncServerUrlField> {
  String? _result;
  bool _ok = false;
  bool _checking = false;

  Future<void> _check() async {
    final url = widget.controller.text.trim();
    setState(() {
      _checking = true;
      _result = null;
    });
    String msg;
    var ok = false;
    try {
      final info = await widget.probe(url);
      ok = true;
      msg = '${info.name} - API v${info.apiVersion}'
          '${info.registrationOpen ? '' : ' - registration closed'}';
    } on SyncApiException catch (e) {
      msg = e.message;
    } catch (e) {
      msg = 'Could not reach the server';
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _ok = ok;
      _result = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final insecure = SyncApiClient.isInsecure(widget.controller.text);
    final helper = _result ??
        (insecure ? 'Plain http: only use on a trusted private network' : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('sync_server_url'),
          controller: widget.controller,
          enabled: widget.enabled,
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: (_) => setState(() => _result = null),
          decoration: InputDecoration(
            labelText: 'Server URL',
            helperText: helper,
            helperStyle: TextStyle(
              color: _result == null
                  ? AppTokens.fgSecondary
                  : (_ok ? AppTokens.success : AppTokens.danger),
            ),
          ),
        ),
        const SizedBox(height: AppTokens.s2),
        Row(
          children: [
            TextButton(
              onPressed: widget.enabled && !_checking ? _check : null,
              child: Text(_checking ? 'Checking...' : 'Check server'),
            ),
            TextButton(
              onPressed: widget.enabled
                  ? () => setState(() {
                        widget.controller.text =
                            AccountService.defaultServerUrl;
                        _result = null;
                      })
                  : null,
              child: const Text('Reset to default'),
            ),
          ],
        ),
      ],
    );
  }
}
