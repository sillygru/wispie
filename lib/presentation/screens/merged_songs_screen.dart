import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/song_merge_finder.dart';
import '../../l10n/l10n.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../providers/user_data_provider.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/app_screen_header.dart';
import '../components/app_segmented_tabs.dart';
import '../components/app_surface.dart';
import '../routes/app_page_route.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../widgets/album_art_image.dart';
import 'select_songs_screen.dart';

class MergedSongsScreen extends ConsumerStatefulWidget {
  const MergedSongsScreen({super.key});

  @override
  ConsumerState<MergedSongsScreen> createState() => _MergedSongsScreenState();
}

class _MergedSongsScreenState extends ConsumerState<MergedSongsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);
    final songsAsync = ref.watch(songsProvider);

    return AmbientScaffold(
      body: songsAsync.when(
        data: (allSongs) => _buildContent(context, userData, allSongs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(context.l10n.mergedLoadError('$e'))),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    UserDataState userData,
    List<Song> allSongs,
  ) {
    final candidateGroups = SongMergeFinder.findCandidates(
      allSongs,
      userData.mergedGroups,
    );

    final mergedCount = userData.mergedGroups.length;
    final candidateCount = candidateGroups.length;

    const topBarHeight = kToolbarHeight + 52;
    return Column(
      children: [
        // AppBar needs a bounded height, which a Column does not provide.
        SizedBox(
          height: topBarHeight + MediaQuery.paddingOf(context).top,
          child: AppTopBar(
            title: context.l10n.mergedTitle,
            actions: [
              IconButton(
                icon: const AppIcon(AppIcons.add),
                tooltip: context.l10n.mergedCreateGroupTooltip,
                onPressed: () => _openSelectSongsScreen(context, allSongs),
              ),
            ],
            bottom: AppSegmentedTabs(
              controller: _tabController,
              labels: [
                context.l10n.mergedGroupsTab(mergedCount),
                context.l10n.mergedAutoFindTab(candidateCount),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildActiveGroupsTab(context, userData, allSongs),
              _buildAutoFindTab(context, userData, candidateGroups),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openSelectSongsScreen(
      BuildContext context, List<Song> allSongs) async {
    final result = await context.pushApp<Map<String, dynamic>>(
      SelectSongsScreen(
        songs: allSongs,
        title: context.l10n.mergedSelectSongsTitle,
      ),
    );
    if (result != null && context.mounted) {
      final selected = result['filenames'] as List<String>;
      final priority = result['priority'] as String?;
      if (selected.length >= 2) {
        try {
          await ref.read(userDataProvider.notifier).createMergedGroup(
                selected,
                priorityFilename: priority,
              );
          if (context.mounted) {
            appSnack(
              context,
              context.l10n.mergedCreatedSnack(selected.length),
              tone: AppTone.success,
            );
          }
        } catch (e) {
          if (context.mounted) {
            appSnack(context, '$e', tone: AppTone.danger);
          }
        }
      }
    }
  }

  // --- Tab 1: Active Groups ---
  Widget _buildActiveGroupsTab(
    BuildContext context,
    UserDataState userData,
    List<Song> allSongs,
  ) {
    if (userData.mergedGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                AppIcons.merge,
                size: 56,
                color: AppTokens.fg(AppTokens.aTertiary),
              ),
              const SizedBox(height: AppTokens.s4),
              Text(
                context.l10n.mergedEmptyTitle,
                style: AppTokens.paneTitle(context),
              ),
              const SizedBox(height: AppTokens.s2),
              Text(
                context.l10n.mergedEmptyBody,
                textAlign: TextAlign.center,
                style: AppTokens.rowSubtitle(context),
              ),
              const SizedBox(height: AppTokens.s5),
              FilledButton.icon(
                onPressed: () => _openSelectSongsScreen(context, allSongs),
                icon: const AppIcon(AppIcons.add, size: 18),
                label: Text(context.l10n.mergedCreateGroupButton),
              ),
            ],
          ),
        ),
      );
    }

    final songMap = {for (var s in allSongs) s.filename: s};

    return ListView.builder(
      padding: const EdgeInsets.all(AppTokens.s4),
      itemCount: userData.mergedGroups.length,
      itemBuilder: (context, index) {
        final entry = userData.mergedGroups.entries.elementAt(index);
        final groupId = entry.key;
        final filenames = entry.value;
        final groupSongs =
            filenames.map((f) => songMap[f]).whereType<Song>().toList();

        if (groupSongs.length < 2) return const SizedBox.shrink();

        final priorityFilename = userData.getMergedGroupPriority(groupId);

        return _MergeGroupCard(
          groupId: groupId,
          songs: groupSongs,
          priorityFilename: priorityFilename,
          onSetPriority: (filename) async {
            final newPriority = priorityFilename == filename ? null : filename;
            await ref
                .read(userDataProvider.notifier)
                .setMergedGroupPriority(groupId, newPriority);
            if (context.mounted) {
              final songTitle =
                  groupSongs.firstWhere((s) => s.filename == filename).title;
              appSnack(
                context,
                newPriority != null
                    ? context.l10n.mergedPrioritySet(songTitle)
                    : context.l10n.mergedPriorityCleared,
                tone: AppTone.info,
              );
            }
          },
          onUnmergeSong: (song) => _showUnmergeDialog(context, song),
          onDeleteGroup: () => _showDeleteGroupDialog(context, groupId),
        );
      },
    );
  }

  // --- Tab 2: Auto-Find Suggestions ---
  Widget _buildAutoFindTab(
    BuildContext context,
    UserDataState userData,
    List<MergeCandidateGroup> candidateGroups,
  ) {
    if (candidateGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                AppIcons.autoAwesome,
                size: 56,
                color: AppTokens.fg(AppTokens.aTertiary),
              ),
              const SizedBox(height: AppTokens.s4),
              Text(
                context.l10n.mergedNoCandidatesTitle,
                style: AppTokens.paneTitle(context),
              ),
              const SizedBox(height: AppTokens.s2),
              Text(
                context.l10n.mergedNoCandidatesBody,
                textAlign: TextAlign.center,
                style: AppTokens.rowSubtitle(context),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.s4,
            AppTokens.s2,
            AppTokens.s4,
            AppTokens.s2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.mergedFoundGroups(candidateGroups.length),
                  style: AppTokens.rowSubtitle(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _mergeAllCandidates(context, candidateGroups),
                icon: const AppIcon(AppIcons.merge, size: 16),
                label: Text(context.l10n.mergedMergeAll),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.s4),
            itemCount: candidateGroups.length,
            itemBuilder: (context, index) {
              final candidate = candidateGroups[index];
              return _CandidateGroupCard(
                candidate: candidate,
                onMerge: (selectedFilenames) async {
                  if (selectedFilenames.length < 2) return;
                  await ref
                      .read(userDataProvider.notifier)
                      .createMergedGroup(selectedFilenames);
                  if (context.mounted) {
                    appSnack(
                      context,
                      context.l10n.mergedCreatedSnack(selectedFilenames.length),
                      tone: AppTone.success,
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _mergeAllCandidates(
    BuildContext context,
    List<MergeCandidateGroup> candidateGroups,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.mergedMergeAllTitle),
        content:
            Text(context.l10n.mergedMergeAllConfirm(candidateGroups.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.mergedMergeAll),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      int count = 0;
      for (final candidate in candidateGroups) {
        final filenames = candidate.songs.map((s) => s.filename).toList();
        if (filenames.length >= 2) {
          await ref
              .read(userDataProvider.notifier)
              .createMergedGroup(filenames);
          count++;
        }
      }
      if (context.mounted) {
        appSnack(
          context,
          context.l10n.mergedCreatedGroupsSnack(count),
          tone: AppTone.success,
        );
      }
    }
  }

  Future<void> _showUnmergeDialog(BuildContext context, Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.mergedUnmergeTitle),
        content: Text(context.l10n.mergedUnmergeConfirm(song.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.mergedUnmergeAction),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(userDataProvider.notifier).unmergeSong(song.filename);
      if (context.mounted) {
        appSnack(
          context,
          context.l10n.mergedUnmergedSnack(song.title),
          tone: AppTone.info,
        );
      }
    }
  }

  Future<void> _showDeleteGroupDialog(
      BuildContext context, String groupId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.mergedDeleteGroupTitle),
        content: Text(context.l10n.mergedDeleteGroupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.mergedUnmergeAllAction),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(userDataProvider.notifier).deleteMergedGroup(groupId);
      if (context.mounted) {
        appSnack(context, context.l10n.mergedGroupDeleted, tone: AppTone.info);
      }
    }
  }
}

class _MergeGroupCard extends ConsumerWidget {
  final String groupId;
  final List<Song> songs;
  final String? priorityFilename;
  final ValueChanged<String> onSetPriority;
  final Function(Song) onUnmergeSong;
  final VoidCallback onDeleteGroup;

  const _MergeGroupCard({
    required this.groupId,
    required this.songs,
    required this.priorityFilename,
    required this.onSetPriority,
    required this.onUnmergeSong,
    required this.onDeleteGroup,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = AppTokens.accentOf(context, ref);

    return AppSurface(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: AppTokens.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s4,
              vertical: AppTokens.s3,
            ),
            decoration: BoxDecoration(
              color: AppTokens.surface(2),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTokens.rMd),
              ),
            ),
            child: Row(
              children: [
                AppIcon(AppIcons.merge, size: 20, color: accent),
                const SizedBox(width: AppTokens.s2),
                Expanded(
                  child: Text(
                    context.l10n.mergedGroupLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
                Text(
                  context.l10n.mergedVersionsCount(songs.length),
                  style: AppTokens.rowSubtitle(context),
                ),
                const SizedBox(width: AppTokens.s2),
                IconButton(
                  icon: const AppIcon(AppIcons.delete, size: 18),
                  onPressed: onDeleteGroup,
                  tooltip: context.l10n.mergedUnmergeAllTooltip,
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 1),
            itemBuilder: (context, index) {
              final song = songs[index];
              final isPriority = song.filename == priorityFilename;

              return ListTile(
                leading: ClipRRect(
                  borderRadius: AppTokens.brSm,
                  child: AlbumArtImage(
                    url: song.coverUrl ?? '',
                    filename: song.filename,
                    width: 40,
                    height: 40,
                    memCacheWidth: 80,
                    memCacheHeight: 80,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPriority) ...[
                      const SizedBox(width: AppTokens.s1),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.s2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(
                            alpha: AppTokens.accentWashAlpha,
                          ),
                          borderRadius: AppTokens.brPill,
                        ),
                        child: Text(
                          context.l10n.mergedPriorityBadge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.rowSubtitle(context),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: AppIcon(
                        AppIcons.star,
                        size: 18,
                        color: isPriority
                            ? accent
                            : AppTokens.fg(AppTokens.aTertiary),
                      ),
                      onPressed: () => onSetPriority(song.filename),
                      tooltip: isPriority
                          ? context.l10n.mergedPrioritySongTooltip
                          : context.l10n.mergedSetPriorityTooltip,
                    ),
                    IconButton(
                      icon: const AppIcon(AppIcons.linkOff, size: 18),
                      onPressed: () => onUnmergeSong(song),
                      tooltip: context.l10n.mergedUnmergeSongTooltip,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CandidateGroupCard extends StatefulWidget {
  final MergeCandidateGroup candidate;
  final ValueChanged<List<String>> onMerge;

  const _CandidateGroupCard({
    required this.candidate,
    required this.onMerge,
  });

  @override
  State<_CandidateGroupCard> createState() => _CandidateGroupCardState();
}

class _CandidateGroupCardState extends State<_CandidateGroupCard> {
  late Set<String> _selectedFilenames;

  @override
  void initState() {
    super.initState();
    _selectedFilenames = widget.candidate.songs.map((s) => s.filename).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final songs = widget.candidate.songs;
    final canMerge = _selectedFilenames.length >= 2;

    return AppSurface(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: AppTokens.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s4,
              vertical: AppTokens.s3,
            ),
            decoration: BoxDecoration(
              color: AppTokens.surface(2),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTokens.rMd),
              ),
            ),
            child: Row(
              children: [
                const AppIcon(AppIcons.autoAwesome, size: 20),
                const SizedBox(width: AppTokens.s2),
                Expanded(
                  child: Text(
                    widget.candidate.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  context.l10n.mergedSelectedCount(
                    _selectedFilenames.length,
                    songs.length,
                  ),
                  style: AppTokens.rowSubtitle(context),
                ),
                const SizedBox(width: AppTokens.s3),
                FilledButton(
                  onPressed: canMerge
                      ? () => widget.onMerge(_selectedFilenames.toList())
                      : null,
                  child: Text(context.l10n.mergedMergeAction),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final isChecked = _selectedFilenames.contains(song.filename);

              return CheckboxListTile(
                value: isChecked,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedFilenames.add(song.filename);
                    } else {
                      _selectedFilenames.remove(song.filename);
                    }
                  });
                },
                secondary: ClipRRect(
                  borderRadius: AppTokens.brSm,
                  child: AlbumArtImage(
                    url: song.coverUrl ?? '',
                    filename: song.filename,
                    width: 36,
                    height: 36,
                    memCacheWidth: 72,
                    memCacheHeight: 72,
                  ),
                ),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.rowSubtitle(context),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
