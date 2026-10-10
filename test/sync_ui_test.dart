import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/presentation/screens/sync_settings_screen.dart';
import 'package:wispie/presentation/widgets/danger_confirm_dialog.dart';
import 'package:wispie/presentation/widgets/sync_onboarding.dart';
import 'package:wispie/presentation/widgets/sync_server_url_field.dart';
import 'package:wispie/services/sync/api_client.dart';
import 'package:wispie/services/sync_service.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  testWidgets('countdown dialog gates confirm until 0 and text matches',
      (t) async {
    await t.pumpWidget(_wrap(const DangerConfirmDialog(
      title: 'Delete',
      message: 'm',
      confirmLabel: 'Delete',
      countdownSeconds: 3,
      requireTypedText: 'bob',
      requirePassword: true,
      checkboxLabel: 'ok',
    )));
    Finder btn() => find.widgetWithText(FilledButton, 'Delete (3)');
    expect(btn(), findsOneWidget);
    await t.enterText(find.byType(TextField).at(0), 'bob');
    await t.enterText(find.byType(TextField).at(1), 'pw');
    await t.tap(find.byType(Checkbox));
    await t.pump();
    expect(t.widget<FilledButton>(btn()).onPressed, isNull);
    await t.pump(const Duration(seconds: 3));
    final done = find.widgetWithText(FilledButton, 'Delete');
    expect(t.widget<FilledButton>(done).onPressed, isNotNull);
    await t.enterText(find.byType(TextField).at(0), 'bobby');
    await t.pump();
    expect(t.widget<FilledButton>(done).onPressed, isNull);
  });

  test('auto-sync unavailable before initial sync', () {
    expect(autoSyncAvailable(SyncStatus.loggedOut), isFalse);
    expect(autoSyncAvailable(SyncStatus.needsInitialChoice), isFalse);
    expect(autoSyncAvailable(SyncStatus.pausedEpochChanged), isFalse);
    expect(autoSyncAvailable(SyncStatus.ready), isTrue);
    expect(syncStageFor(SyncStatus.syncing), SyncStage.main);
  });

  testWidgets('recovery key continue gated on checkbox', (t) async {
    var done = false;
    await t.pumpWidget(_wrap(RecoveryKeyReveal(
      recoveryKey: 'ABCDE',
      onContinue: () => done = true,
    )));
    await t.tap(find.text('Continue'));
    expect(done, isFalse);
    await t.tap(find.byType(Checkbox));
    await t.pump();
    await t.tap(find.text('Continue'));
    expect(done, isTrue);
  });

  testWidgets('fresh account only offers Sync everything now', (t) async {
    await t.pumpWidget(_wrap(SyncInitialChoice(
      freshAccount: true,
      busy: false,
      onSyncEverything: () {},
      onMerge: () {},
      onNewDevice: () {},
    )));
    expect(find.text('Sync everything now'), findsOneWidget);
    expect(find.text('Set up as new device'), findsNothing);
  });

  testWidgets('server URL validation shows result and reset works', (t) async {
    final c = TextEditingController(text: 'https://example.org');
    await t.pumpWidget(_wrap(SyncServerUrlField(
      controller: c,
      probe: (u) async {
        if (u.contains('bad')) {
          throw const SyncApiException(
              0, 'not_wispie', 'Not a Wispie sync server');
        }
        return const SyncServerInfo(
          registrationOpen: true,
          powBits: 1,
          maxDeltaBytes: 1,
          chunkBytes: 1,
          quotaBytes: 1,
        );
      },
    )));
    await t.tap(find.text('Check server'));
    await t.pumpAndSettle();
    expect(find.textContaining('wispie-sync - API v1'), findsOneWidget);
    c.text = 'https://bad.example';
    await t.tap(find.text('Check server'));
    await t.pumpAndSettle();
    expect(find.text('Not a Wispie sync server'), findsOneWidget);
    await t.tap(find.text('Reset to default'));
    expect(c.text, 'https://wispie-api.gru0.dev');
  });
}
