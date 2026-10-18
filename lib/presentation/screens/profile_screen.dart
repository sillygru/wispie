import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../providers/user_data_provider.dart';
import '../../services/audio_player_manager.dart';
import '../../models/shuffle_config.dart';
import '../components/app_dialog.dart';
import '../components/app_feedback.dart';
import '../components/app_list_row.dart';
import '../components/app_screen_header.dart';
import '../components/app_settings.dart';
import '../components/scroll_chrome.dart';
import '../components/app_section_header.dart';
import '../components/app_surface.dart';
import '../routes/app_page_route.dart';
import '../tokens/app_tokens.dart';
import 'settings_screen.dart';
import 'backup_management_screen.dart';
import 'custom_shuffle_settings_screen.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';
import '../utils/wide_layout.dart';
import '../widgets/stats/insights_summary_row.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const ProfileScreen({super.key, this.scrollController});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with ScrollChromeMixin {
  String _appVersion = '';
  ShufflePersonality? _pendingPersonality;
  bool _hasPersonalityChanges = false;
  double? _discoveryDraft;

  @override
  void initState() {
    super.initState();
    _getAppVersion();
  }

  Future<void> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = packageInfo.version);
  }

  Future<void> _showChangeUsernameDialog(String? current) async {
    final l10n = AppLocalizations.of(context);
    final name = await showAppTextPrompt(
      context,
      title: l10n.profileChangeName,
      initialValue: current,
      hintText: l10n.profileNewNameHint,
      confirmLabel: l10n.profileUpdate,
    );
    if (name == null || !mounted) return;

    try {
      await ref.read(authProvider.notifier).setDisplayName(name);
      if (mounted) {
        appSnack(context, l10n.profileNameUpdated, tone: AppTone.success);
      }
    } catch (e) {
      if (mounted) appSnack(context, '$e', tone: AppTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userData = ref.watch(userDataProvider);
    final audioManager = ref.watch(audioPlayerManagerProvider);
    final accent = AppTokens.accentOf(context, ref);
    final l10n = AppLocalizations.of(context);
    if (WideLayout.isWide(context)) {
      return _buildWide(context, authState, userData, audioManager, accent);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(userDataProvider.notifier).refresh(force: true),
        child: NotificationListener<ScrollNotification>(
          onNotification: handleScrollNotification,
          child: WideContentCenter(
            maxWidth: WideLayout.maxNarrowWidth,
            child: CustomScrollView(
              controller: widget.scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                AppSliverHeader(
                    title: l10n.profileTitle, isScrolled: isScrolled),

                // Identity — a plain avatar and name, sitting on the background
                // rather than on a gradient banner.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.s5,
                      AppTokens.s2,
                      AppTokens.s5,
                      AppTokens.s5,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(
                              alpha: AppTokens.accentWashAlpha,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            (authState.username ?? l10n.profileAvatarFallback)
                                .substring(0, 1)
                                .toUpperCase(),
                            style: AppTokens.screenTitle(context)
                                .copyWith(color: accent),
                          ),
                        ),
                        const SizedBox(width: AppTokens.s4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                authState.username ?? l10n.profileDefaultName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTokens.screenTitle(context),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.profileAppVersion(_appVersion),
                                style: AppTokens.meta(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Stats
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.s4,
                    ),
                    child: AppSurface(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTokens.s4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          AppStatTile(
                            label: l10n.syncFavorites,
                            value: '${userData.favorites.length}',
                          ),
                          AppStatTile(
                            label: l10n.syncPlaylists,
                            value:
                                '${userData.playlists.where((p) => !p.isRecommendation).length}',
                          ),
                          AppStatTile(
                            label: l10n.profileHidden,
                            value: '${userData.hidden.length}',
                          ),
                          AppStatTile(
                            label: l10n.profileSuggestLess,
                            value: '${userData.suggestLess.length}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Listening insights — the entry point to the stats screen.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.s4,
                      AppTokens.s4,
                      AppTokens.s4,
                      0,
                    ),
                    child: const InsightsSummaryRow(),
                  ),
                ),

                // Shuffle personality
                SliverToBoxAdapter(
                  child: AppSectionHeader(label: l10n.profileShuffleSection),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.s4,
                    ),
                    child: ValueListenableBuilder<ShuffleState>(
                      valueListenable: audioManager.shuffleStateNotifier,
                      builder: (context, shuffleState, child) {
                        final current = shuffleState.config.personality;
                        final selectedValue = _pendingPersonality ?? current;

                        return AppSurface(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTokens.s2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RadioGroup<ShufflePersonality>(
                                groupValue: selectedValue,
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _pendingPersonality = v;
                                    _hasPersonalityChanges = v != current;
                                  });
                                },
                                child: Column(
                                  children: [
                                    _PersonalityTile(
                                      title: l10n.profileSmart,
                                      subtitle: l10n.profileSmartSubtitle,
                                      value: ShufflePersonality.smart,
                                    ),
                                    _LegacyCaption(),
                                    _PersonalityTile(
                                      title: l10n.profileDefault,
                                      subtitle: l10n.profileDefaultSubtitle,
                                      value: ShufflePersonality.defaultMode,
                                    ),
                                    _PersonalityTile(
                                      title: l10n.profileExplorer,
                                      subtitle: l10n.profileExplorerSubtitle,
                                      value: ShufflePersonality.explorer,
                                    ),
                                    _PersonalityTile(
                                      title: l10n.profileConsistent,
                                      subtitle: l10n.profileConsistentSubtitle,
                                      value: ShufflePersonality.consistent,
                                    ),
                                    _PersonalityTile(
                                      title: l10n.appearanceIntensityCustom,
                                      subtitle: l10n.profileCustomSubtitle,
                                      value: ShufflePersonality.custom,
                                    ),
                                  ],
                                ),
                              ),
                              _discoveryControl(
                                audioManager,
                                shuffleState,
                                selectedValue,
                              ),
                              if (_hasPersonalityChanges)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppTokens.s4,
                                    AppTokens.s2,
                                    AppTokens.s2,
                                    AppTokens.s1,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l10n.profileAppliesNextQueue,
                                          style: AppTokens.meta(context)
                                              .copyWith(color: accent),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => setState(() {
                                          _pendingPersonality = null;
                                          _hasPersonalityChanges = false;
                                        }),
                                        child: Text(l10n.actionCancel),
                                      ),
                                      const SizedBox(width: AppTokens.s2),
                                      FilledButton(
                                        onPressed: () {
                                          audioManager.updateShuffleConfig(
                                            shuffleState.config.copyWith(
                                              personality: _pendingPersonality!,
                                            ),
                                            applyToCurrentQueue: false,
                                          );
                                          setState(() {
                                            _pendingPersonality = null;
                                            _hasPersonalityChanges = false;
                                          });
                                          appSnack(context,
                                              l10n.profilePersonalitySaved,
                                              tone: AppTone.success);
                                        },
                                        child: Text(l10n.metadataFixApply),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ValueListenableBuilder<ShuffleState>(
                    valueListenable: audioManager.shuffleStateNotifier,
                    builder: (context, shuffleState, child) {
                      if (shuffleState.config.personality !=
                          ShufflePersonality.custom) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTokens.s4,
                          AppTokens.s3,
                          AppTokens.s4,
                          0,
                        ),
                        child: AppSurfaceGroup(
                          children: [
                            _navRow(
                              icon: AppIcons.tune,
                              title: l10n.profileConfigureCustomShuffle,
                              subtitle:
                                  l10n.profileConfigureCustomShuffleSubtitle,
                              accent: accent,
                              onTap: () => context.pushApp(
                                const CustomShuffleSettingsScreen(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Profile / Data / App
                SliverToBoxAdapter(
                  child: AppSectionHeader(label: l10n.profileTitle),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppTokens.s4),
                    child: AppSurfaceGroup(
                      children: [
                        _navRow(
                          icon: AppIcons.person,
                          title: l10n.profileChangeName,
                          subtitle:
                              l10n.profileCurrentName(authState.username ?? ''),
                          accent: accent,
                          onTap: () =>
                              _showChangeUsernameDialog(authState.username),
                        ),
                        _navRow(
                          icon: AppIcons.cloudUpload,
                          title: l10n.backupManageBackups,
                          subtitle: l10n.backupManageBackupsSubtitle,
                          accent: accent,
                          onTap: () =>
                              context.pushApp(const BackupManagementScreen()),
                        ),
                        _navRow(
                          icon: AppIcons.settings,
                          title: l10n.settingsTitle,
                          subtitle: l10n.profileThemeStorage,
                          accent: accent,
                          onTap: () => context.pushApp(const SettingsScreen()),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverPadding(
                  padding: EdgeInsets.only(bottom: AppTokens.scrollBottomInset),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Wide arrangement: identity + stats pinned left, habits and
  /// personality scroll right. Narrow keeps the single phone column.
  Widget _buildWide(
    BuildContext context,
    AuthState authState,
    UserDataState userData,
    AudioPlayerManager audioManager,
    Color accent,
  ) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(userDataProvider.notifier).refresh(force: true),
        child: NotificationListener<ScrollNotification>(
          onNotification: handleScrollNotification,
          child: WideContentCenter(
            maxWidth: WideLayout.maxContentWidth,
            child: CustomScrollView(
              controller: widget.scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                AppSliverHeader(
                    title: l10n.profileTitle, isScrolled: isScrolled),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.s4,
                      AppTokens.s2,
                      AppTokens.s4,
                      AppTokens.scrollBottomInset,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 320,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppSurface(
                                padding: const EdgeInsets.all(AppTokens.s5),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 96,
                                      height: 96,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: accent.withValues(
                                          alpha: AppTokens.accentWashAlpha,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        (authState.username ??
                                                l10n.profileAvatarFallback)
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: AppTokens.screenTitle(context)
                                            .copyWith(
                                          color: accent,
                                          fontSize: 36,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppTokens.s3),
                                    Text(
                                      authState.username ??
                                          l10n.profileDefaultName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: AppTokens.screenTitle(context)
                                          .copyWith(fontSize: 22),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.profileAppVersion(_appVersion),
                                      style: AppTokens.meta(context),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTokens.s4),
                              AppSurface(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppTokens.s4,
                                  horizontal: AppTokens.s2,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppStatTile(
                                            label: l10n.syncFavorites,
                                            value:
                                                '${userData.favorites.length}',
                                          ),
                                        ),
                                        Expanded(
                                          child: AppStatTile(
                                            label: l10n.syncPlaylists,
                                            value:
                                                '${userData.playlists.where((p) => !p.isRecommendation).length}',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppTokens.s4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppStatTile(
                                            label: l10n.profileHidden,
                                            value: '${userData.hidden.length}',
                                          ),
                                        ),
                                        Expanded(
                                          child: AppStatTile(
                                            label: l10n.profileSuggestLess,
                                            value:
                                                '${userData.suggestLess.length}',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTokens.s4),
                              AppSurfaceGroup(
                                children: [
                                  _navRow(
                                    icon: AppIcons.person,
                                    title: l10n.profileChangeName,
                                    subtitle: l10n.profileCurrentName(
                                        authState.username ?? ''),
                                    accent: accent,
                                    onTap: () => _showChangeUsernameDialog(
                                      authState.username,
                                    ),
                                  ),
                                  _navRow(
                                    icon: AppIcons.cloudUpload,
                                    title: l10n.backupManageBackups,
                                    subtitle: l10n.backupManageBackupsSubtitle,
                                    accent: accent,
                                    onTap: () => context.pushApp(
                                      const BackupManagementScreen(),
                                    ),
                                  ),
                                  _navRow(
                                    icon: AppIcons.settings,
                                    title: l10n.settingsTitle,
                                    subtitle: l10n.profileThemeStorage,
                                    accent: accent,
                                    onTap: () => context.pushApp(
                                      const SettingsScreen(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppTokens.s5),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppSurface(
                                padding: EdgeInsets.zero,
                                child: const InsightsSummaryRow(),
                              ),
                              AppSectionHeader(
                                label: l10n.profileShuffleSection,
                              ),
                              ValueListenableBuilder<ShuffleState>(
                                valueListenable:
                                    audioManager.shuffleStateNotifier,
                                builder: (context, shuffleState, child) {
                                  final current =
                                      shuffleState.config.personality;
                                  final selectedValue =
                                      _pendingPersonality ?? current;
                                  // One card per row under the compact seam:
                                  // two 155px cards leave the subtitle no room.
                                  final compact = WideLayout.isCompact(context);
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        height: 96,
                                        child: _PersonalityCard(
                                          title: l10n.profileSmart,
                                          subtitle: l10n.profileSmartSubtitle,
                                          value: ShufflePersonality.smart,
                                          groupValue: selectedValue,
                                          accent: accent,
                                          onTap: (v) => setState(() {
                                            _pendingPersonality = v;
                                            _hasPersonalityChanges =
                                                v != current;
                                          }),
                                        ),
                                      ),
                                      const SizedBox(height: AppTokens.s3),
                                      const _LegacyCaption(),
                                      GridView(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: compact ? 1 : 2,
                                          crossAxisSpacing: AppTokens.s3,
                                          mainAxisSpacing: AppTokens.s3,
                                          mainAxisExtent: 96,
                                        ),
                                        children: [
                                          _PersonalityCard(
                                            title: l10n.profileDefault,
                                            subtitle:
                                                l10n.profileDefaultSubtitle,
                                            value:
                                                ShufflePersonality.defaultMode,
                                            groupValue: selectedValue,
                                            accent: accent,
                                            onTap: (v) => setState(() {
                                              _pendingPersonality = v;
                                              _hasPersonalityChanges =
                                                  v != current;
                                            }),
                                          ),
                                          _PersonalityCard(
                                            title: l10n.profileExplorer,
                                            subtitle:
                                                l10n.profileExplorerSubtitle,
                                            value: ShufflePersonality.explorer,
                                            groupValue: selectedValue,
                                            accent: accent,
                                            onTap: (v) => setState(() {
                                              _pendingPersonality = v;
                                              _hasPersonalityChanges =
                                                  v != current;
                                            }),
                                          ),
                                          _PersonalityCard(
                                            title: l10n.profileConsistent,
                                            subtitle:
                                                l10n.profileConsistentSubtitle,
                                            value:
                                                ShufflePersonality.consistent,
                                            groupValue: selectedValue,
                                            accent: accent,
                                            onTap: (v) => setState(() {
                                              _pendingPersonality = v;
                                              _hasPersonalityChanges =
                                                  v != current;
                                            }),
                                          ),
                                          _PersonalityCard(
                                            title:
                                                l10n.appearanceIntensityCustom,
                                            subtitle:
                                                l10n.profileCustomSubtitle,
                                            value: ShufflePersonality.custom,
                                            groupValue: selectedValue,
                                            accent: accent,
                                            onTap: (v) => setState(() {
                                              _pendingPersonality = v;
                                              _hasPersonalityChanges =
                                                  v != current;
                                            }),
                                          ),
                                        ],
                                      ),
                                      _discoveryControl(
                                        audioManager,
                                        shuffleState,
                                        selectedValue,
                                      ),
                                      if (_hasPersonalityChanges)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: AppTokens.s3,
                                          ),
                                          child: AppSurface(
                                            padding: const EdgeInsets.fromLTRB(
                                              AppTokens.s4,
                                              AppTokens.s2,
                                              AppTokens.s2,
                                              AppTokens.s2,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    l10n.profileAppliesNextQueue,
                                                    style: AppTokens.meta(
                                                      context,
                                                    ).copyWith(color: accent),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () => setState(
                                                    () {
                                                      _pendingPersonality =
                                                          null;
                                                      _hasPersonalityChanges =
                                                          false;
                                                    },
                                                  ),
                                                  child:
                                                      Text(l10n.actionCancel),
                                                ),
                                                const SizedBox(
                                                  width: AppTokens.s2,
                                                ),
                                                FilledButton(
                                                  onPressed: () {
                                                    audioManager
                                                        .updateShuffleConfig(
                                                      shuffleState.config
                                                          .copyWith(
                                                        personality:
                                                            _pendingPersonality!,
                                                      ),
                                                      applyToCurrentQueue:
                                                          false,
                                                    );
                                                    setState(() {
                                                      _pendingPersonality =
                                                          null;
                                                      _hasPersonalityChanges =
                                                          false;
                                                    });
                                                    appSnack(
                                                      context,
                                                      l10n.profilePersonalitySaved,
                                                      tone: AppTone.success,
                                                    );
                                                  },
                                                  child: Text(
                                                      l10n.metadataFixApply),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      if (shuffleState.config.personality ==
                                          ShufflePersonality.custom)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: AppTokens.s3,
                                          ),
                                          child: AppSurfaceGroup(
                                            children: [
                                              _navRow(
                                                icon: AppIcons.tune,
                                                title: l10n
                                                    .profileConfigureCustomShuffle,
                                                subtitle: l10n
                                                    .profileConfigureCustomShuffleSubtitle,
                                                accent: accent,
                                                onTap: () => context.pushApp(
                                                  const CustomShuffleSettingsScreen(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _discoveryControl(
    AudioPlayerManager audioManager,
    ShuffleState shuffleState,
    ShufflePersonality selected,
  ) {
    final l10n = AppLocalizations.of(context);
    if (selected != ShufflePersonality.smart) return const SizedBox.shrink();
    final value = _discoveryDraft ?? shuffleState.config.discoveryLevel;
    final label = value < 0.34
        ? l10n.profileFamiliar
        : value > 0.66
            ? l10n.profileDiscover
            : l10n.appearanceIntensityBalanced;
    return AppSettingsSlider(
      icon: AppIcons.tune,
      title: l10n.profileFamiliarToDiscover,
      valueLabel: label,
      value: value,
      min: 0,
      max: 1,
      divisions: 10,
      onChanged: (v) => setState(() => _discoveryDraft = v),
      onChangeEnd: (v) {
        setState(() => _discoveryDraft = null);
        audioManager.updateShuffleConfig(
          shuffleState.config.copyWith(discoveryLevel: v),
          applyToCurrentQueue: false,
        );
      },
    );
  }

  Widget _navRow({
    required AppIconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return AppListRow(
      leading: AppRowIcon(icon: icon, color: accent),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: AppIcon(
        AppIcons.chevronRight,
        size: 20,
        color: AppTokens.fgTertiary,
      ),
    );
  }
}

class _PersonalityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final ShufflePersonality value;
  final ShufflePersonality groupValue;
  final Color accent;
  final ValueChanged<ShufflePersonality> onTap;

  const _PersonalityCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: AppTokens.dFast,
          curve: AppTokens.cStandard,
          padding: const EdgeInsets.all(AppTokens.s4),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: AppTokens.accentWashAlpha)
                : AppTokens.surface(1),
            borderRadius: AppTokens.brMd,
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? accent : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: selected ? 8 : 16,
                  height: selected ? 8 : 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppTokens.onAccent(accent)
                        : Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTokens.rowTitle(context).copyWith(
                        color: selected ? accent : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTokens.rowSubtitle(context).copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegacyCaption extends StatelessWidget {
  const _LegacyCaption();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s4,
        AppTokens.s3,
        AppTokens.s4,
        AppTokens.s1,
      ),
      child: Text(
        AppLocalizations.of(context).profileLegacyCaption,
        style: AppTokens.meta(context),
      ),
    );
  }
}

class _PersonalityTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final ShufflePersonality value;

  const _PersonalityTile({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ShufflePersonality>(
      value: value,
      dense: true,
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
