import 'package:flutter/material.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../../services/library_logic.dart';
import '../widgets/album_art_image.dart';
import '../tokens/app_tokens.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';
import '../../l10n/l10n.dart';

class SelectSongsScreen extends ConsumerStatefulWidget {
  final List<Song> songs;
  final List<String>? preselectedFilenames;
  final String? title;
  final bool isMerging;
  final String? actionLabel;
  final int minSelection;

  const SelectSongsScreen({
    super.key,
    required this.songs,
    this.preselectedFilenames,
    this.title,
    this.isMerging = true,
    this.actionLabel,
    this.minSelection = 2,
  });

  @override
  ConsumerState<SelectSongsScreen> createState() => _SelectSongsScreenState();
}

class _SelectSongsScreenState extends ConsumerState<SelectSongsScreen> {
  final Set<String> _selectedFilenames = {};
  String? _priorityFilename;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.preselectedFilenames != null) {
      _selectedFilenames.addAll(widget.preselectedFilenames!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortOrder = ref.watch(settingsProvider).sortOrder;
    final userData = ref.watch(userDataProvider);
    final lastPlayedAsync = ref.watch(lastPlayedTimestampsProvider);
    final lastPlayedTimestamps = lastPlayedAsync.asData?.value ?? const {};

    final sortedSongs = LibraryLogic.sortSongs(
      widget.songs,
      sortOrder,
      userData: userData,
      lastPlayedTimestamps: lastPlayedTimestamps,
    );

    final filteredSongs = _searchQuery.isEmpty
        ? sortedSongs
        : sortedSongs
            .where((s) =>
                s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                s.artist.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return AmbientScaffold(
      appBar: AppBar(
        title: Text(widget.title ?? context.l10n.selectSongsTitle),
        actions: [
          if (_selectedFilenames.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedFilenames.clear();
                });
              },
              child: Text(context.l10n.actionClear),
            ),
        ],
      ),
      body: Column(
        children: [
          // Info card explaining merge functionality (only if merging)
          if (widget.isMerging)
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: AppTokens.accentWashAlpha),
                borderRadius: AppTokens.brSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppIcon(
                        AppIcons.info,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.selectSongsWhatIsMerging,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.selectSongsMergedExplanation,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  _buildInfoBullet(
                      context, context.l10n.selectSongsBulletVersions),
                  _buildInfoBullet(
                      context, context.l10n.selectSongsBulletFavorites),
                  _buildInfoBullet(
                      context, context.l10n.selectSongsBulletStats),
                  _buildInfoBullet(
                      context, context.l10n.selectSongsBulletPriority),
                ],
              ),
            ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: context.l10n.selectSongsSearchHint,
                prefixIcon: const AppIcon(AppIcons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const AppIcon(AppIcons.close),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          // Selection info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: Row(
              children: [
                AppIcon(
                  AppIcons.checkCircle,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n
                      .selectSongsSelectedCount(_selectedFilenames.length),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const Spacer(),
                if (widget.isMerging && _selectedFilenames.length >= 2)
                  Text(
                    context.l10n.selectSongsReadyToMerge,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
              ],
            ),
          ),
          // Song list
          Expanded(
            child: filteredSongs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(AppIcons.searchOff,
                            size: 48, color: AppTokens.fgTertiary),
                        const SizedBox(height: 16),
                        Text(context.l10n.homeNoSongsTitle,
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
                      final isSelected =
                          _selectedFilenames.contains(song.filename);
                      final isPriority = _priorityFilename == song.filename;

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedFilenames.add(song.filename);
                              // Auto-set first selected as priority if none set
                              if (widget.isMerging) {
                                _priorityFilename ??= song.filename;
                              }
                            } else {
                              _selectedFilenames.remove(song.filename);
                              // Clear priority if priority song is deselected
                              if (_priorityFilename == song.filename) {
                                _priorityFilename = null;
                              }
                            }
                          });
                        },
                        secondary: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Priority star button (only show if selected AND merging)
                            if (isSelected && widget.isMerging)
                              IconButton(
                                icon: AppIcon(
                                  isPriority ? AppIcons.star : AppIcons.star,
                                  color: isPriority
                                      ? AppTokens.warning
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.4),
                                ),
                                tooltip: isPriority
                                    ? context
                                        .l10n.selectSongsPrioritySongTooltip
                                    : context
                                        .l10n.selectSongsSetPriorityTooltip,
                                onPressed: () {
                                  setState(() {
                                    _priorityFilename =
                                        isPriority ? null : song.filename;
                                  });
                                },
                              ),
                            ClipRRect(
                              borderRadius: AppTokens.brPill,
                              child: AlbumArtImage(
                                url: song.coverUrl ?? '',
                                filename: song.filename,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
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
                            if (isPriority && widget.isMerging)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTokens.warning
                                        .withValues(alpha: 0.2),
                                    borderRadius: AppTokens.brSm,
                                  ),
                                  child: Text(
                                    context.l10n.selectSongsPriorityBadge,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTokens.warning,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedFilenames.length < widget.minSelection)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    context.l10n.selectSongsMinSelection(widget.minSelection),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ),
              FilledButton(
                onPressed: _selectedFilenames.length >= widget.minSelection
                    ? () {
                        Navigator.pop(
                          context,
                          {
                            'filenames': _selectedFilenames.toList(),
                            'priority': _priorityFilename,
                          },
                        );
                      }
                    : null,
                child: Text(widget.actionLabel ??
                    (widget.isMerging
                        ? context.l10n
                            .selectSongsMergeAction(_selectedFilenames.length)
                        : context.l10n.selectSongsSelectAction(
                            _selectedFilenames.length))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
