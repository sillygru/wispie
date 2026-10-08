import 'package:flutter/material.dart';

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
        title: 'Older version detected',
        message: 'Wispie was last opened on $previousVersion, but this is '
            '$currentVersion. Your data may have been changed by a newer '
            'version and could break or be lost on this one.',
        actions: [
          AppDialogAction(
            label: 'Quit',
            onPressed: () => Navigator.pop(ctx, DowngradeChoice.quit),
          ),
          AppDialogAction(
            label: 'Risk it',
            isDanger: true,
            onPressed: () => Navigator.pop(ctx, DowngradeChoice.risk),
          ),
          AppDialogAction(
            label: 'Update',
            isPrimary: true,
            onPressed: () => Navigator.pop(ctx, DowngradeChoice.update),
          ),
        ],
      ),
    ),
  );
}
