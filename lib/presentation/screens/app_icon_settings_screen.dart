import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/l10n.dart';
import '../../providers/settings_provider.dart';
import '../../services/app_icon_service.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_screen_header.dart';
import '../components/app_surface.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';

class AppIconSettingsScreen extends ConsumerWidget {
  const AppIconSettingsScreen({super.key});

  static const double _tileWidth = 148;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(settingsProvider.select((s) => s.appIconStyle));
    final notifier = ref.read(settingsProvider.notifier);
    final accent = AppTokens.accentOf(context, ref);
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return AmbientScaffold(
      appBar: AppTopBar(title: l10n.appearanceAppIcon),
      body: WideContentCenter(
        maxWidth: WideLayout.maxNarrowWidth,
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.s4),
          children: [
            Wrap(
              spacing: AppTokens.s3,
              runSpacing: AppTokens.s3,
              children: [
                for (final style in AppIconStyle.values)
                  SizedBox(
                    width: _tileWidth,
                    child: AppSurface(
                      level: style == selected ? 2 : 1,
                      accentTint: style == selected ? accent : null,
                      onTap: () => notifier.setAppIconStyle(style),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: AppTokens.brMd,
                            child: Image.asset(
                              style.previewAsset,
                              width: _tileWidth,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: AppTokens.s3),
                          Text(style.label, style: textTheme.titleSmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.s5),
            Center(
              child: Text(
                l10n.appIconMoreSoon,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppTokens.fg(AppTokens.aSecondary),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.s3),
            Text(
              l10n.appIconDesktopNote,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: AppTokens.fg(AppTokens.aSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
