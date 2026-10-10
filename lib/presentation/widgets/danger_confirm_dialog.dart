import 'dart:async';

import 'package:flutter/material.dart';

import '../components/app_dialog.dart';
import '../tokens/app_tokens.dart';

/// Confirmation for destructive sync actions. The confirm button stays
/// disabled until the countdown ends and every requirement is satisfied.
class DangerConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final int countdownSeconds;
  final String? requireTypedText;
  final bool requirePassword;
  final String? checkboxLabel;

  const DangerConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.countdownSeconds = 5,
    this.requireTypedText,
    this.requirePassword = false,
    this.checkboxLabel,
  });

  @override
  State<DangerConfirmDialog> createState() => _DangerConfirmDialogState();
}

class _DangerConfirmDialogState extends State<DangerConfirmDialog> {
  late int _remaining = widget.countdownSeconds;
  Timer? _timer;
  bool _checked = false;
  final _typed = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_remaining > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _remaining--);
        if (_remaining <= 0) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _typed.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _ready =>
      _remaining <= 0 &&
      (widget.checkboxLabel == null || _checked) &&
      (widget.requireTypedText == null ||
          _typed.text.trim() == widget.requireTypedText) &&
      (!widget.requirePassword || _password.text.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final label = _remaining > 0
        ? '${widget.confirmLabel} ($_remaining)'
        : widget.confirmLabel;
    return AppDialog(
      title: widget.title,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message, style: AppTokens.rowSubtitle(context)),
            if (widget.requireTypedText != null) ...[
              const SizedBox(height: AppTokens.s3),
              TextField(
                controller: _typed,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Type "${widget.requireTypedText}" to confirm',
                ),
              ),
            ],
            if (widget.requirePassword) ...[
              const SizedBox(height: AppTokens.s3),
              TextField(
                controller: _password,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
            if (widget.checkboxLabel != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _checked,
                onChanged: (v) => setState(() => _checked = v ?? false),
                title: Text(widget.checkboxLabel!),
              ),
          ],
        ),
      ),
      actions: [
        AppDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          label: label,
          isPrimary: true,
          isDanger: true,
          onPressed:
              _ready ? () => Navigator.of(context).pop(_password.text) : null,
        ),
      ],
    );
  }
}

/// Returns the entered password ('' when not required) or null if cancelled.
Future<String?> showDangerConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  int countdownSeconds = 5,
  String? requireTypedText,
  bool requirePassword = false,
  String? checkboxLabel,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => DangerConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        countdownSeconds: countdownSeconds,
        requireTypedText: requireTypedText,
        requirePassword: requirePassword,
        checkboxLabel: checkboxLabel,
      ),
    );
