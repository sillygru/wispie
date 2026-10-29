import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../components/app_feedback.dart';
import '../tokens/app_icons.dart';

/// Metadata saves report through the app's one feedback column: a spinner while
/// writing, then the same pill turning into the result.
class MetadataSaveIndicator extends ConsumerWidget {
  const MetadataSaveIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadataState = ref.watch(metadataSaveProvider);

    if (metadataState.status == MetadataSaveStatus.idle) {
      return const AppPopupSlot(child: null);
    }

    final (String text, AppTone tone, AppIconData icon, bool busy) =
        switch (metadataState.status) {
      MetadataSaveStatus.saving => (
          metadataState.message,
          AppTone.warning,
          AppIcons.edit,
          true,
        ),
      MetadataSaveStatus.success => (
          metadataState.message,
          AppTone.success,
          AppIcons.checkCircle,
          false,
        ),
      _ => (
          metadataState.message,
          AppTone.danger,
          AppIcons.error,
          false,
        ),
    };

    return AppPopupSlot(
      child: AppStatusBanner(
        message: text,
        tone: tone,
        icon: icon,
        busy: busy,
      ),
    );
  }
}
