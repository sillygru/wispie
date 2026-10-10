import 'package:flutter/material.dart';

import '../../services/sync_service.dart';
import '../components/app_surface.dart';
import '../tokens/app_tokens.dart';

String syncPhaseLabel(SyncPhase p) => switch (p) {
      SyncPhase.derivingKeys => 'Securing your account...',
      SyncPhase.authenticating => 'Signing in...',
      SyncPhase.checking => 'Checking cloud...',
      SyncPhase.downloadingSnapshot => 'Downloading backup...',
      SyncPhase.applyingSnapshot => 'Applying backup...',
      SyncPhase.downloadingChanges => 'Downloading changes...',
      SyncPhase.merging => 'Merging...',
      SyncPhase.preparingUpload => 'Preparing upload...',
      SyncPhase.encrypting => 'Encrypting...',
      SyncPhase.uploading => 'Uploading...',
      SyncPhase.finalizing => 'Finishing up...',
      SyncPhase.done => 'Done',
      SyncPhase.error => 'Sync failed',
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
        ? 'Syncing...'
        : (p.message.isNotEmpty ? p.message : syncPhaseLabel(p.phase));
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
