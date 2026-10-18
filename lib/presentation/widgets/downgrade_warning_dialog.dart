import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../components/app_dialog.dart';

enum DowngradeChoice { update, quit, risk }

Future<DowngradeChoice?> showDowngradeWarningDialog(
  BuildContext context, {
  required String previousVersion,
  required String currentVersion,
}) {
  return showDialog<DowngradeChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AppDialog(
        title: ctx.l10n.downgradeTitle,
        message: ctx.l10n.downgradeMessage(previousVersion, currentVersion),
        actions: [
          AppDialogAction(
            label: ctx.l10n.downgradeQuit,
            onPressed: () => Navigator.pop(ctx, DowngradeChoice.quit),
          ),
          AppDialogAction(
            label: ctx.l10n.downgradeRiskIt,
            isDanger: true,
            onPressed: () => Navigator.pop(ctx, DowngradeChoice.risk),
          ),
          AppDialogAction(
            label: ctx.l10n.downgradeUpdate,
            isPrimary: true,
            onPressed: () => Navigator.pop(ctx, DowngradeChoice.update),
          ),
        ],
      ),
    ),
  );
}
