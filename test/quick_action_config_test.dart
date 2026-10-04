import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/models/quick_action_config.dart';

/// `QuickAction` is written to preferences as a list of enum *indices*, which
/// makes the declaration order part of the on-disk format.
///
/// Nothing at the type level stops the next person from inserting a new action
/// in the middle of the enum to keep related things together. It would compile,
/// pass every other test, and quietly re-point every quick action a returning
/// user had already arranged: their play-next button becomes a delete button,
/// with no error anywhere. These tests are the only thing standing between that
/// edit and a bad day for everyone who saved a layout.
///
/// The mirror-image hazard is removal. Bulk rename used to be the last action
/// and is now a settings page, so index 12 is live in every layout saved while
/// it shipped — one past the end of the enum.
void main() {
  /// The declaration order as it stood before bulk rename was removed.
  const legacyOrder = <String>[
    'playNext',
    'goToAlbum',
    'goToArtist',
    'moveToFolder',
    'addToPlaylist',
    'share',
    'addToNewPlaylist',
    'editMetadata',
    'toggleFavorite',
    'toggleSuggestLess',
    'delete',
    'hide',
    'bulkRename',
  ];

  test('the surviving actions keep the indices older builds saved them under',
      () {
    final current = QuickAction.values.map((a) => a.name).toList();

    // Bulk rename is gone; everything below it is untouched. Appending is safe,
    // removing from the end is safe, inserting is not.
    expect(current, legacyOrder.sublist(0, current.length));
  });

  test('a config saved while bulk rename existed decodes without losing it all',
      () {
    // The literal payload a previous build wrote: index 12 is bulk rename, which
    // no longer resolves.
    final decoded = QuickActionConfig.fromJsonString(
      '{"enabledActions":[8,0,4,5,10,12],"actionOrder":[8,0,4,5,10,11,1,2,3,6,7,9,12]}',
    );

    expect(
      decoded.enabledActions.map((a) => a.name),
      ['toggleFavorite', 'playNext', 'addToPlaylist', 'share', 'delete'],
      reason: 'the removed action is dropped, the saved choices are kept',
    );
    expect(
      decoded.actionOrder.map((a) => a.name).toSet(),
      legacyOrder.sublist(0, 12).toSet(),
    );
  });

  test('a config that is only retired actions falls back to the defaults', () {
    // Otherwise the bar would come up with nothing on it.
    final decoded = QuickActionConfig.fromJsonString(
      '{"enabledActions":[12],"actionOrder":[12]}',
    );

    expect(decoded.enabledActions, QuickActionConfig.defaultEnabled);
    expect(decoded.actionOrder, QuickActionConfig.defaultOrder);
  });

  test('a config survives a save and reload intact', () {
    final config = const QuickActionConfig(
      enabledActions: [QuickAction.share, QuickAction.hide],
      actionOrder: [QuickAction.hide, QuickAction.share],
    );

    final decoded = QuickActionConfig.fromJsonString(config.toJsonString());

    expect(decoded.enabledActions, config.enabledActions);
    expect(decoded.actionOrder, config.actionOrder);
  });

  test('every action is reachable in the default order', () {
    // The settings screen orders and toggles from defaultOrder. An action
    // missing from it is one the user can never configure.
    expect(
      QuickActionConfig.defaultOrder.toSet(),
      QuickAction.values.toSet(),
    );
    expect(
      QuickActionConfig.defaultOrder.length,
      QuickAction.values.length,
      reason: 'listed twice, so the screen would render it twice',
    );
  });

  test('nothing that needs a selection ships enabled by default', () {
    // An action that acts on exactly one song is not a thing this surface can
    // do, so it must not be in the default bar.
    expect(QuickActionConfig.defaultEnabled, isNotEmpty);
    expect(
      QuickActionConfig.defaultEnabled.toSet().difference(
            QuickActionConfig.defaultOrder.toSet(),
          ),
      isEmpty,
    );
  });
}
