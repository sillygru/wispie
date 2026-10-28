import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/open_files_provider.dart';
import '../components/app_feedback.dart';
import '../tokens/app_icons.dart';

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

    final notifier = ref.read(openFilesProvider.notifier);
    final canImport = state.hasPending &&
        state.error == null &&
        state.pendingImport.any((file) => !file.isRemote);

    return AppBannerDismiss(
      hold: Duration.zero,
      onDismiss: () =>
          state.error != null ? notifier.clearError() : notifier.dismiss(),
      child: AppStatusBanner(
        message: state.error ?? state.bannerLabel,
        tone: state.error != null ? AppTone.danger : AppTone.info,
        icon: state.error != null ? AppIcons.error : AppIcons.musicNote,
        busy: state.isImporting,
        maxLines: 2,
        actionLabel: canImport && !state.isImporting
            ? context.l10n.externalOpenAddToLibrary
            : null,
        onAction: notifier.importToLibrary,
        onDismiss: () =>
            state.error != null ? notifier.clearError() : notifier.dismiss(),
      ),
    );
  }
}
