import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/sync_service.dart';
import '../components/app_surface.dart';
import '../tokens/app_tokens.dart';

String syncPhaseLabel(AppLocalizations l10n, SyncPhase p) => switch (p) {
      SyncPhase.derivingKeys => l10n.syncSecuringAccount,
      SyncPhase.authenticating => l10n.syncPhaseSigningIn,
      SyncPhase.checking => l10n.syncPhaseCheckingCloud,
      SyncPhase.downloadingSnapshot => l10n.syncPhaseDownloadingBackup,
      SyncPhase.applyingSnapshot => l10n.syncPhaseApplyingBackup,
      SyncPhase.downloadingChanges => l10n.syncPhaseDownloadingChanges,
      SyncPhase.merging => l10n.syncPhaseMerging,
      SyncPhase.preparingUpload => l10n.syncPhasePreparingUpload,
      SyncPhase.encrypting => l10n.syncPhaseEncrypting,
      SyncPhase.uploading => l10n.syncPhaseUploading,
      SyncPhase.finalizing => l10n.syncPhaseFinishing,
      SyncPhase.done => l10n.actionDone,
      SyncPhase.error => l10n.syncPhaseError,
    };

/// Phase label plus a determinate bar when bytes/items are known.
class SyncProgressCard extends StatelessWidget {
  final SyncProgress? progress;
  const SyncProgressCard({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final theme = Theme.of(context);
    final label = p == null
        ? context.l10n.syncSyncing
        : (p.message.isNotEmpty
            ? p.message
            : syncPhaseLabel(context.l10n, p.phase));
    return AppSurface(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTokens.s4,
        vertical: AppTokens.s2,
      ),
      padding: const EdgeInsets.all(AppTokens.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: AppTokens.s2),
          LinearProgressIndicator(
            value: p?.fraction,
            borderRadius: AppTokens.brPill,
          ),
        ],
      ),
    );
  }
}
