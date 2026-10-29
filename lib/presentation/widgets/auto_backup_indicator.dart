import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/providers.dart';
import '../../services/auto_backup_service.dart';
import '../components/app_feedback.dart';
import '../tokens/app_icons.dart';

/// Auto backup reports through the app's one feedback column. It used to carry
/// two near-identical hand-built cards with their own colours, dismiss
/// direction and layout; the shared pill already has all of that.
class AutoBackupIndicator extends ConsumerStatefulWidget {
  const AutoBackupIndicator({super.key});

  @override
  ConsumerState<AutoBackupIndicator> createState() =>
      _AutoBackupIndicatorState();
}

class _AutoBackupIndicatorState extends ConsumerState<AutoBackupIndicator> {
  Timer? _autoDismiss;
  AutoBackupResult? _scheduledResult;

  @override
  void dispose() {
    _autoDismiss?.cancel();
    super.dispose();
  }

  void _dismiss() {
    _autoDismiss?.cancel();
    ref.read(autoBackupProvider.notifier).clearLastError();
  }

  void _scheduleAutoDismiss() {
    _autoDismiss?.cancel();
    _autoDismiss = Timer(const Duration(seconds: 4), () {
      if (mounted) _dismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AutoBackupState>(autoBackupProvider, (previous, next) {
      if (next.lastResult != null &&
          !next.isRunning &&
          next.lastResult != _scheduledResult) {
        _scheduledResult = next.lastResult;
        _scheduleAutoDismiss();
      } else if (next.lastResult == null && !next.hasPermissionError) {
        _autoDismiss?.cancel();
        _scheduledResult = null;
      }
    });

    final state = ref.watch(autoBackupProvider);
    final l10n = context.l10n;
    final result = state.lastResult;

    final AppStatusBanner banner;
    if (state.isRunning) {
      banner = AppStatusBanner(
        message: l10n.autoBackupRunningSubtitle,
        tone: AppTone.info,
        icon: AppIcons.cloudUpload,
        busy: true,
      );
    } else if (state.hasPermissionError ||
        (result?.permissionDenied ?? false)) {
      banner = AppStatusBanner(
        message: l10n.autoBackupPermissionSubtitle,
        tone: AppTone.warning,
        icon: AppIcons.warning,
        actionLabel: l10n.autoBackupGrant,
        onAction: () =>
            ref.read(autoBackupProvider.notifier).requestPermission(),
        onDismiss: _dismiss,
        maxLines: 2,
      );
    } else if (result != null && result.success) {
      banner = AppStatusBanner(
        message: l10n.autoBackupCompleteTitle,
        tone: AppTone.success,
        icon: AppIcons.checkCircle,
      );
    } else if (result != null) {
      banner = AppStatusBanner(
        message: result.errorMessage ?? l10n.autoBackupFailedTitle,
        tone: AppTone.danger,
        icon: AppIcons.error,
        maxLines: 2,
      );
    } else {
      return const AppPopupSlot(child: null);
    }

    return AppPopupSlot(
      child: AppBannerDismiss(
        // A run in progress stays up; finished ones clear themselves.
        hold: Duration.zero,
        onDismiss: _dismiss,
        child: banner,
      ),
    );
  }
}
