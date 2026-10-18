import 'package:flutter/material.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/l10n.dart';
import '../../models/shuffle_config.dart';
import '../../providers/providers.dart';
import '../components/app_surface.dart';
import '../components/app_screen_header.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';

class CustomShuffleSettingsScreen extends ConsumerStatefulWidget {
  const CustomShuffleSettingsScreen({super.key});

  @override
  ConsumerState<CustomShuffleSettingsScreen> createState() =>
      _CustomShuffleSettingsScreenState();
}

class _CustomShuffleSettingsScreenState
    extends ConsumerState<CustomShuffleSettingsScreen> {
  bool _showAdvanced = false;
  late ShuffleConfig _localConfig;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final audioManager = ref.read(audioPlayerManagerProvider);
    _localConfig = audioManager.shuffleStateNotifier.value.config;
  }

  void _updateConfig(ShuffleConfig newConfig) {
    setState(() {
      _localConfig = newConfig;
      _hasChanges = true;
    });
  }

  void _resetToDefaults() {
    setState(() {
      _localConfig = _localConfig.copyWith(
        avoidRepeatingSongs: true,
        avoidRepeatingArtists: true,
        avoidRepeatingAlbums: true,
        leastPlayedWeight: 0,
        mostPlayedWeight: 0,
        favoritesWeight: 0,
        suggestLessWeight: 0,
        playlistSongsWeight: 0,
      );
      _hasChanges = true;
    });
    appSnack(context, context.l10n.shuffleResetDone);
  }

  void _saveSettings() {
    final audioManager = ref.read(audioPlayerManagerProvider);
    audioManager.updateShuffleConfig(
      _localConfig,
      applyToCurrentQueue: false,
    );
    setState(() {
      _hasChanges = false;
    });
    appSnack(context, context.l10n.shuffleSaved);
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.shuffleUnsavedTitle),
        content: Text(context.l10n.shuffleUnsavedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.shuffleDiscard),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.backupSave),
          ),
        ],
      ),
    );

    if (result == true) {
      _saveSettings();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final config = _localConfig;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: AmbientScaffold(
        appBar: AppTopBar(
          title: context.l10n.shuffleTitle,
          actions: [
            TextButton.icon(
              onPressed: _resetToDefaults,
              icon: const AppIcon(AppIcons.refresh, size: 20),
              label: Text(context.l10n.shuffleReset),
            ),
            if (_hasChanges)
              TextButton.icon(
                onPressed: _saveSettings,
                icon: const AppIcon(AppIcons.save, size: 20),
                label: Text(context.l10n.backupSave),
              ),
          ],
        ),
        body: WideContentCenter(
          maxWidth: WideLayout.maxNarrowWidth,
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.s4),
            children: [
              if (_hasChanges)
                AppSurface(
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        AppIcon(
                          AppIcons.info,
                          size: 20,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.l10n.shuffleNextQueueNote,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_hasChanges) const SizedBox(height: 16),
              _buildSectionTitle(context.l10n.shuffleBasicSettings),
              AppSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(context.l10n.shuffleAvoidSongsTitle),
                      subtitle: Text(context.l10n.shuffleAvoidSongsSubtitle),
                      value: config.avoidRepeatingSongs,
                      onChanged: (value) {
                        _updateConfig(
                            config.copyWith(avoidRepeatingSongs: value));
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(context.l10n.shuffleAvoidArtistsTitle),
                      subtitle: Text(context.l10n.shuffleAvoidArtistsSubtitle),
                      value: config.avoidRepeatingArtists,
                      onChanged: (value) {
                        _updateConfig(
                            config.copyWith(avoidRepeatingArtists: value));
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(context.l10n.shuffleAvoidAlbumsTitle),
                      subtitle: Text(context.l10n.shuffleAvoidAlbumsSubtitle),
                      value: config.avoidRepeatingAlbums,
                      onChanged: (value) {
                        _updateConfig(
                            config.copyWith(avoidRepeatingAlbums: value));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                title: Text(
                  context.l10n.shuffleAdvancedTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(context.l10n.shuffleAdvancedSubtitle),
                trailing: AppIcon(
                  _showAdvanced ? AppIcons.arrowUp : AppIcons.arrowDown,
                ),
                onTap: () {
                  setState(() {
                    _showAdvanced = !_showAdvanced;
                  });
                },
              ),
              if (_showAdvanced) ...[
                const SizedBox(height: 8),
                AppSurface(
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.shuffleWeightValuesTitle,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.shuffleWeightValuesHint,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildAdvancedSlider(
                          label: context.l10n.shuffleWeightLeastPlayed,
                          value: config.leastPlayedWeight,
                          onChanged: (value) {
                            _updateConfig(
                                config.copyWith(leastPlayedWeight: value));
                          },
                        ),
                        _buildAdvancedSlider(
                          label: context.l10n.shuffleWeightMostPlayed,
                          value: config.mostPlayedWeight,
                          onChanged: (value) {
                            _updateConfig(
                                config.copyWith(mostPlayedWeight: value));
                          },
                        ),
                        _buildAdvancedSlider(
                          label: context.l10n.libraryFavorites,
                          value: config.favoritesWeight,
                          onChanged: (value) {
                            _updateConfig(
                                config.copyWith(favoritesWeight: value));
                          },
                        ),
                        _buildAdvancedSlider(
                          label: context.l10n.shuffleWeightSuggestLess,
                          value: config.suggestLessWeight,
                          onChanged: (value) {
                            _updateConfig(
                                config.copyWith(suggestLessWeight: value));
                          },
                        ),
                        _buildAdvancedSlider(
                          label: context.l10n.shuffleWeightPlaylistSongs,
                          value: config.playlistSongsWeight,
                          onChanged: (value) {
                            _updateConfig(
                                config.copyWith(playlistSongsWeight: value));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildAdvancedSlider({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: value == 0
                    ? AppTokens.fgTertiary.withValues(alpha: 0.2)
                    : value > 0
                        ? AppTokens.success.withValues(alpha: 0.2)
                        : AppTokens.danger.withValues(alpha: 0.2),
                borderRadius: AppTokens.brSm,
              ),
              child: Text(
                value > 0 ? '+$value' : '$value',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: value == 0
                      ? AppTokens.fgTertiary
                      : value > 0
                          ? AppTokens.success
                          : AppTokens.danger,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: -99,
          max: 99,
          divisions: 198,
          onChanged: (newValue) {
            onChanged(newValue.round());
          },
          activeColor: value == 0
              ? AppTokens.fgTertiary
              : value > 0
                  ? AppTokens.success
                  : AppTokens.danger,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
