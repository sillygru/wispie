import 'package:flutter/material.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/l10n.dart';
import '../../models/quick_action_config.dart';
import '../../providers/settings_provider.dart';
import '../components/app_surface.dart';
import '../components/app_screen_header.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';

class QuickActionsSettingsScreen extends ConsumerStatefulWidget {
  const QuickActionsSettingsScreen({super.key});

  @override
  ConsumerState<QuickActionsSettingsScreen> createState() =>
      _QuickActionsSettingsScreenState();
}

class _QuickActionsSettingsScreenState
    extends ConsumerState<QuickActionsSettingsScreen> {
  late List<QuickAction> _orderedActions;
  late Set<QuickAction> _enabledActions;

  @override
  void initState() {
    super.initState();
    final config = ref.read(settingsProvider).quickActionConfig;
    _orderedActions = List.from(config.actionOrder);
    _enabledActions = Set.from(config.enabledActions);
  }

  void _saveConfig() {
    final enabledOrder = _orderedActions
        .where((action) => _enabledActions.contains(action))
        .toList();
    final config = QuickActionConfig(
      enabledActions: enabledOrder,
      actionOrder: _orderedActions,
    );
    ref.read(settingsProvider.notifier).setQuickActionConfig(config);
  }

  String _getActionLabel(QuickAction action, AppLocalizations l10n) {
    switch (action) {
      case QuickAction.playNext:
        return l10n.quickActionsPlayNext;
      case QuickAction.goToAlbum:
        return l10n.quickActionsGoToAlbum;
      case QuickAction.goToArtist:
        return l10n.quickActionsGoToArtist;
      case QuickAction.moveToFolder:
        return l10n.quickActionsMoveToFolder;
      case QuickAction.addToPlaylist:
        return l10n.quickActionsAddToPlaylist;
      case QuickAction.share:
        return l10n.quickActionsShare;
      case QuickAction.addToNewPlaylist:
        return l10n.quickActionsAddToNewPlaylist;
      case QuickAction.editMetadata:
        return l10n.quickActionsEditMetadata;
      case QuickAction.toggleFavorite:
        return l10n.quickActionsFavorite;
      case QuickAction.toggleSuggestLess:
        return l10n.quickActionsSuggestLess;
      case QuickAction.delete:
        return l10n.quickActionsDelete;
      case QuickAction.hide:
        return l10n.quickActionsHide;
    }
  }

  Widget _getActionIcon(QuickAction action, bool enabled) {
    final color = enabled
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return AppIcon(_getIconData(action), color: color);
  }

  AppIconData _getIconData(QuickAction action) {
    switch (action) {
      case QuickAction.playNext:
        return AppIcons.queue;
      case QuickAction.goToAlbum:
        return AppIcons.album;
      case QuickAction.goToArtist:
        return AppIcons.person;
      case QuickAction.moveToFolder:
        return AppIcons.folderMove;
      case QuickAction.addToPlaylist:
        return AppIcons.playlistAdd;
      case QuickAction.share:
        return AppIcons.share;
      case QuickAction.addToNewPlaylist:
        return AppIcons.playlistAdd;
      case QuickAction.editMetadata:
        return AppIcons.edit;
      case QuickAction.toggleFavorite:
        return AppIcons.favorite;
      case QuickAction.toggleSuggestLess:
        return AppIcons.heartBroken;
      case QuickAction.delete:
        return AppIcons.delete;
      case QuickAction.hide:
        return AppIcons.visibilityOff;
    }
  }

  void _resetToDefaults() {
    setState(() {
      _orderedActions = List.from(QuickActionConfig.defaultOrder);
      _enabledActions = Set.from(QuickActionConfig.defaultEnabled);
    });
    _saveConfig();
    appSnack(context, context.l10n.quickActionsResetDone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabledActions = _orderedActions
        .where((action) => _enabledActions.contains(action))
        .toList();
    final disabledActions = _orderedActions
        .where((action) => !_enabledActions.contains(action))
        .toList();

    return AmbientScaffold(
      appBar: AppTopBar(
        title: l10n.quickActionsTitle,
        actions: [
          TextButton(
            onPressed: _resetToDefaults,
            child: Text(l10n.quickActionsReset),
          ),
        ],
      ),
      body: WideContentCenter(
        maxWidth: WideLayout.maxNarrowWidth,
        child: CustomScrollView(
          slivers: [
            if (enabledActions.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.s4,
                    AppTokens.s4,
                    AppTokens.s4,
                    8,
                  ),
                  child: Row(
                    children: [
                      AppIcon(
                        AppIcons.checkCircle,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.quickActionsEnabledHeader(enabledActions.length),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.s4),
                sliver: SliverReorderableList(
                  itemCount: enabledActions.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = enabledActions.removeAt(oldIndex);
                      enabledActions.insert(newIndex, item);
                      _orderedActions = [
                        ...enabledActions,
                        ...disabledActions,
                      ];
                    });
                    _saveConfig();
                  },
                  itemBuilder: (context, index) {
                    final action = enabledActions[index];
                    return _buildActionTile(
                      key: ValueKey(action),
                      action: action,
                      enabled: true,
                      index: index,
                    );
                  },
                ),
              ),
            ],
            if (disabledActions.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.s4,
                    AppTokens.s4,
                    AppTokens.s4,
                    8,
                  ),
                  child: Row(
                    children: [
                      AppIcon(
                        AppIcons.close,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.quickActionsDisabledHeader(disabledActions.length),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.s4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final action = disabledActions[index];
                      return _buildActionTile(
                        key: ValueKey(action),
                        action: action,
                        enabled: false,
                        index: index,
                      );
                    },
                    childCount: disabledActions.length,
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required Key key,
    required QuickAction action,
    required bool enabled,
    required int index,
  }) {
    return AppSurface(
      padding: EdgeInsets.zero,
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _getActionIcon(action, enabled),
        title: Text(
          _getActionLabel(action, context.l10n),
          style: TextStyle(
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: enabled,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _enabledActions.add(action);
                  } else {
                    _enabledActions.remove(action);
                  }
                });
                _saveConfig();
              },
            ),
            if (enabled)
              ReorderableDragStartListener(
                index: index,
                child: const AppIcon(AppIcons.dragHandle),
              ),
          ],
        ),
      ),
    );
  }
}
