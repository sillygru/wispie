import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/open_files_provider.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';

/// Banner shown while files opened via Android Open-with / Share play
/// transiently. Offers a permanent import into the library folder.
class ExternalOpenBanner extends ConsumerWidget {
  const ExternalOpenBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(openFilesProvider);
    if (!state.hasPending && state.error == null) {
      return const SizedBox.shrink();
    }

    final tone = state.error != null ? AppTone.danger : AppTone.info;
    final accent = tone.color(context);
    final message = state.error ?? state.bannerLabel;
    final canImport = state.hasPending &&
        state.error == null &&
        state.pendingImport.any((f) => !f.isRemote);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: AppTokens.s2),
        child: Center(
          child: AnimatedContainer(
            duration: AppTokens.dFast,
            curve: AppTokens.cEmphasized,
            margin: const EdgeInsets.symmetric(horizontal: AppTokens.s4),
            padding: const EdgeInsets.only(
              left: AppTokens.s4,
              right: AppTokens.s2,
              top: AppTokens.s2,
              bottom: AppTokens.s2,
            ),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                accent.withValues(alpha: 0.16),
                Colors.black.withValues(alpha: 0.72),
              ),
              borderRadius: AppTokens.brLg,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.isImporting)
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                else
                  AppIcon(
                    state.error != null ? AppIcons.error : AppIcons.musicNote,
                    size: 15,
                    color: accent,
                  ),
                const SizedBox(width: AppTokens.s2),
                Flexible(
                  child: Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.meta(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (canImport && !state.isImporting) ...[
                  const SizedBox(width: AppTokens.s2),
                  TextButton(
                    onPressed: () =>
                        ref.read(openFilesProvider.notifier).importToLibrary(),
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.s3,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Add to library'),
                  ),
                ],
                IconButton(
                  onPressed: () {
                    final notifier = ref.read(openFilesProvider.notifier);
                    if (state.error != null) {
                      notifier.clearError();
                    } else {
                      notifier.dismiss();
                    }
                  },
                  icon: AppIcon(AppIcons.close, size: 15, color: accent),
                  padding: const EdgeInsets.all(AppTokens.s2),
                  constraints: const BoxConstraints(),
                  tooltip: 'Dismiss',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
