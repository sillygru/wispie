// SPDX-License-Identifier: GPL-3.0-only
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/youtube_session.dart';
import '../../l10n/l10n.dart';
import '../../providers/youtube_account_provider.dart';
import '../components/app_screen_header.dart';
import '../components/app_surface.dart';
import '../tokens/app_tokens.dart';
import '../utils/youtube_account_error_message.dart';

/// Pastes or imports a cookie jar instead of signing in through a WebView.
///
/// This is the reliable path: Google refuses its login form inside embedded
/// browsers on some platforms (macOS especially), and Linux has no WebView at
/// all. Accepts the three shapes people actually have: the `Cookie` header from
/// a youtube.com request, a Netscape `cookies.txt`, or a JSON export.
///
/// The jar is checked against a real request here, so a stale or wrong paste
/// reports next to the field instead of closing the screen and failing later.
class YouTubeCookieImportScreen extends ConsumerStatefulWidget {
  const YouTubeCookieImportScreen({super.key});

  @override
  ConsumerState<YouTubeCookieImportScreen> createState() =>
      _YouTubeCookieImportScreenState();
}

class _YouTubeCookieImportScreenState
    extends ConsumerState<YouTubeCookieImportScreen> {
  final TextEditingController _input = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final cookies = YouTubeCookieParser.parse(_input.text);
    if (cookies.isEmpty) {
      setState(() => _error = l10n.youtubeAccountCookiesEmpty);
      return;
    }
    if (YouTubeWebSession.fromCookies(cookies) == null) {
      setState(() => _error = l10n.youtubeAccountErrorUnauthorized);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(youtubeAccountProvider.notifier).signIn(cookies);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = YouTubeAccountErrorMessage.forError(error, l10n);
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickFile() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await FilePicker.pickFile(type: FileType.any);
      final path = picked?.path;
      if (path == null) return;
      final text = await File(path).readAsString();
      if (!mounted) return;
      setState(() => _input.text = text);
    } on Object catch (error) {
      debugPrint('YouTube: could not read the cookie file: $error');
      if (mounted) {
        setState(() => _error = l10n.youtubeAccountCookiesUnreadable);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppTopBar(title: l10n.youtubeAccountCookiesTitle),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.s4,
          AppTokens.s2,
          AppTokens.s4,
          AppTokens.scrollBottomInset,
        ),
        children: [
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.youtubeAccountCookiesBody,
                  style: AppTokens.rowSubtitle(context),
                ),
                const SizedBox(height: AppTokens.s3),
                AppSurface(
                  depth: AppDepth.well,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.s3,
                    vertical: AppTokens.s2,
                  ),
                  child: TextField(
                    controller: _input,
                    minLines: 6,
                    maxLines: 12,
                    autocorrect: false,
                    style: AppTokens.rowSubtitle(context),
                    decoration: InputDecoration(
                      hintText: l10n.youtubeAccountCookiesHint,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppTokens.s2),
                  Text(
                    _error!,
                    style: AppTokens.rowSubtitle(context).copyWith(
                      color: AppTokens.danger,
                    ),
                  ),
                ],
                const SizedBox(height: AppTokens.s3),
                if (_busy)
                  const Center(
                    child: SizedBox(
                      width: AppTokens.iconMd,
                      height: AppTokens.iconMd,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  FilledButton(
                    onPressed: _submit,
                    child: Text(l10n.youtubeAccountCookiesImport),
                  ),
                  const SizedBox(height: AppTokens.s1),
                  TextButton(
                    onPressed: _pickFile,
                    child: Text(l10n.youtubeAccountCookiesFile),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
