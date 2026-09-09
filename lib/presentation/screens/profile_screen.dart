import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../providers/user_data_provider.dart';
import '../../services/audio_player_manager.dart';
import '../../models/shuffle_config.dart';
import '../widgets/fun_stats_view.dart';
import '../components/app_dialog.dart';
import '../components/app_feedback.dart';
import '../components/app_list_row.dart';
import '../components/app_screen_header.dart';
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
    final name = await showAppTextPrompt(
      context,
      title: 'Change Display Name',
      initialValue: current,
      hintText: 'New name',
      confirmLabel: 'Update',
    );
    if (name == null || !mounted) return;

    try {
      await ref.read(authProvider.notifier).setDisplayName(name);
      if (mounted) {
        appSnack(context, 'Name updated', tone: AppTone.success);
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
                AppSliverHeader(title: 'Profile', isScrolled: isScrolled),

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
                            (authState.username ?? 'U')
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
                                authState.username ?? 'User',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTokens.screenTitle(context),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Wispie v$_appVersion',
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
                            label: 'Favorites',
                            value: '${userData.favorites.length}',
                          ),
                          AppStatTile(
                            label: 'Playlists',
                            value:
                                '${userData.playlists.where((p) => !p.isRecommendation).length}',
                          ),
                          AppStatTile(
                            label: 'Hidden',
                            value: '${userData.hidden.length}',
                          ),
                          AppStatTile(
                            label: 'Suggest-less',
                            value: '${userData.suggestLess.length}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Fun stats
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.s4,
                      AppTokens.s4,
                      AppTokens.s4,
                      0,
                    ),
                    child: AppSurface(
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: AppTokens.brMd,
                        child: ExpansionTile(
                          leading: AppIcon(AppIcons.analytics, color: accent),
                          title: const Text('Fun Stats'),
                          subtitle:
                              const Text('Your listening habits analyzed'),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          children: const [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                AppTokens.s4,
                                0,
                                AppTokens.s4,
                                AppTokens.s4,
                              ),
                              child: FunStatsView(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Shuffle personality
                const SliverToBoxAdapter(
                  child: AppSectionHeader(label: 'Shuffle Personality'),
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
                                child: const Column(
                                  children: [
                                    _PersonalityTile(
                                      title: 'Default',
                                      subtitle: 'Balanced mix with anti-repeat',
                                      value: ShufflePersonality.defaultMode,
                                    ),
                                    _PersonalityTile(
                                      title: 'Explorer',
                                      subtitle: 'Prioritizes new & rare songs',
                                      value: ShufflePersonality.explorer,
                                    ),
                                    _PersonalityTile(
                                      title: 'Consistent',
                                      subtitle: 'Favorites heavy',
                                      value: ShufflePersonality.consistent,
                                    ),
                                    _PersonalityTile(
                                      title: 'Custom',
                                      subtitle: 'Configure your own shuffle',
                                      value: ShufflePersonality.custom,
                                    ),
                                  ],
                                ),
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
                                          'Applies to the next queue',
                                          style: AppTokens.meta(context)
                                              .copyWith(color: accent),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => setState(() {
                                          _pendingPersonality = null;
                                          _hasPersonalityChanges = false;
                                        }),
                                        child: const Text('Cancel'),
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
                                          appSnack(context, 'Personality saved',
                                              tone: AppTone.success);
                                        },
                                        child: const Text('Apply'),
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
                              title: 'Configure Custom Shuffle',
                              subtitle: 'Adjust shuffle behavior settings',
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
                const SliverToBoxAdapter(
                  child: AppSectionHeader(label: 'Profile'),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppTokens.s4),
                    child: AppSurfaceGroup(
                      children: [
                        _navRow(
                          icon: AppIcons.person,
                          title: 'Change Display Name',
                          subtitle: 'Current: ${authState.username}',
                          accent: accent,
                          onTap: () =>
                              _showChangeUsernameDialog(authState.username),
                        ),
                        _navRow(
                          icon: AppIcons.cloudUpload,
                          title: 'Manage Backups',
                          subtitle: 'Create, restore, and manage app backups',
                          accent: accent,
                          onTap: () =>
                              context.pushApp(const BackupManagementScreen()),
                        ),
                        _navRow(
                          icon: AppIcons.settings,
                          title: 'Settings',
                          subtitle: 'Theme & storage',
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
                AppSliverHeader(title: 'Profile', isScrolled: isScrolled),
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
                                        (authState.username ?? 'U')
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
                                      authState.username ?? 'User',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: AppTokens.screenTitle(context)
                                          .copyWith(fontSize: 22),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Wispie v$_appVersion',
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
                                            label: 'Favorites',
                                            value:
                                                '${userData.favorites.length}',
                                          ),
                                        ),
                                        Expanded(
                                          child: AppStatTile(
                                            label: 'Playlists',
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
                                            label: 'Hidden',
                                            value: '${userData.hidden.length}',
                                          ),
                                        ),
                                        Expanded(
                                          child: AppStatTile(
                                            label: 'Suggest-less',
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
                                    title: 'Change Display Name',
                                    subtitle: 'Current: ${authState.username}',
                                    accent: accent,
                                    onTap: () => _showChangeUsernameDialog(
                                      authState.username,
                                    ),
                                  ),
                                  _navRow(
                                    icon: AppIcons.cloudUpload,
                                    title: 'Manage Backups',
                                    subtitle:
                                        'Create, restore, and manage app backups',
                                    accent: accent,
                                    onTap: () => context.pushApp(
                                      const BackupManagementScreen(),
                                    ),
                                  ),
                                  _navRow(
                                    icon: AppIcons.settings,
                                    title: 'Settings',
                                    subtitle: 'Theme & storage',
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
                                child: ClipRRect(
                                  borderRadius: AppTokens.brMd,
                                  child: ExpansionTile(
                                    initiallyExpanded: true,
                                    leading: AppIcon(
                                      AppIcons.analytics,
                                      color: accent,
                                    ),
                                    title: const Text('Fun Stats'),
                                    subtitle: const Text(
                                      'Your listening habits analyzed',
                                    ),
                                    shape: const Border(),
                                    collapsedShape: const Border(),
                                    children: const [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          AppTokens.s4,
                                          0,
                                          AppTokens.s4,
                                          AppTokens.s4,
                                        ),
                                        child: FunStatsView(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const AppSectionHeader(
                                label: 'Shuffle Personality',
                              ),
                              ValueListenableBuilder<ShuffleState>(
                                valueListenable:
                                    audioManager.shuffleStateNotifier,
                                builder: (context, shuffleState, child) {
                                  final current =
                                      shuffleState.config.personality;
                                  final selectedValue =
                                      _pendingPersonality ?? current;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      GridView.count(
                                        crossAxisCount: 2,
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        crossAxisSpacing: AppTokens.s3,
                                        mainAxisSpacing: AppTokens.s3,
                                        childAspectRatio: 2.2,
                                        children: [
                                          _PersonalityCard(
                                            title: 'Default',
                                            subtitle:
                                                'Balanced mix with anti-repeat',
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
                                            title: 'Explorer',
                                            subtitle:
                                                'Prioritizes new & rare songs',
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
                                            title: 'Consistent',
                                            subtitle: 'Favorites heavy',
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
                                            title: 'Custom',
                                            subtitle:
                                                'Configure your own shuffle',
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
                                                    'Applies to the next queue',
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
                                                  child: const Text('Cancel'),
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
                                                      'Personality saved',
                                                      tone: AppTone.success,
                                                    );
                                                  },
                                                  child: const Text('Apply'),
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
                                                title:
                                                    'Configure Custom Shuffle',
                                                subtitle:
                                                    'Adjust shuffle behavior settings',
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
