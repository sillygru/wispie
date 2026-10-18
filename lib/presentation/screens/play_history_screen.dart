import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../services/database_service.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/app_list_row.dart';
import '../components/app_screen_header.dart';
import '../components/app_section_header.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../widgets/album_art_image.dart';

/// Every play and skip event, grouped by day with a listen/skip legend.
///
/// Split out of the drawer file so the navigation widget only navigates.
class PlayHistoryScreen extends ConsumerStatefulWidget {
  const PlayHistoryScreen({super.key});

  @override
  ConsumerState<PlayHistoryScreen> createState() => _PlayHistoryScreenState();
}

class _PlayHistoryScreenState extends ConsumerState<PlayHistoryScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      // Create a mutable copy of events
      final events = List<Map<String, dynamic>>.from(
        await DatabaseService.instance.getAllPlayEvents(),
      );

      // Sort by timestamp descending
      events.sort((a, b) {
        final aTime = (a['timestamp'] as num?)?.toDouble() ?? 0;
        final bTime = (b['timestamp'] as num?)?.toDouble() ?? 0;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);

    return Scaffold(
      appBar: AppTopBar(
        title: context.l10n.playHistoryTitle,
        actions: [
          IconButton(
            onPressed: _loadHistory,
            tooltip: context.l10n.actionRefresh,
            icon: const AppIcon(AppIcons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoading()
          : _error != null
              ? AppEmptyState(
                  icon: AppIcons.error,
                  title: context.l10n.historyLoadError,
                  message: _error,
                  tone: AppTone.danger,
                )
              : _events.isEmpty
                  ? AppEmptyState(
                      icon: AppIcons.clock,
                      title: context.l10n.playHistoryEmptyTitle,
                      message: context.l10n.playHistoryEmptyMessage,
                    )
                  : Column(
                      children: [
                        _buildLegend(context),
                        Expanded(child: _buildHistoryList(context, songsAsync)),
                      ],
                    ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.s3,
        horizontal: AppTokens.s5,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(
              AppIcons.play, AppTokens.success, context.l10n.playHistoryListen),
          const SizedBox(width: AppTokens.s5),
          _buildLegendItem(AppIcons.skipNext, AppTokens.warning,
              context.l10n.playHistorySkip),
        ],
      ),
    );
  }

  Widget _buildLegendItem(AppIconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, color: color, size: 15),
        const SizedBox(width: AppTokens.s1),
        Text(
          label.toUpperCase(),
          style: AppTokens.sectionLabel(context).copyWith(color: color),
        ),
      ],
    );
  }

  Widget _buildHistoryList(
      BuildContext context, AsyncValue<List<Song>> songsAsync) {
    final songMap = songsAsync.when(
      data: (songs) => {for (var s in songs) s.filename: s},
      loading: () => <String, Song>{},
      error: (_, __) => <String, Song>{},
    );

    // Group events by date
    final groupedEvents = <String, List<Map<String, dynamic>>>{};
    for (final event in _events) {
      final timestamp = (event['timestamp'] as num?)?.toDouble() ?? 0;
      final date =
          DateTime.fromMillisecondsSinceEpoch((timestamp * 1000).toInt());
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      groupedEvents.putIfAbsent(dateKey, () => []).add(event);
    }

    final sortedDates = groupedEvents.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          bottom: AppTokens.scrollBottomInset,
        ),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final dateKey = sortedDates[index];
          return _buildDateSection(
              context, dateKey, groupedEvents[dateKey]!, songMap);
        },
      ),
    );
  }

  Widget _buildDateSection(
    BuildContext context,
    String dateKey,
    List<Map<String, dynamic>> events,
    Map<String, Song> songMap,
  ) {
    final parts = dateKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final date = DateTime(year, month, day);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String dateLabel;
    if (date == today) {
      dateLabel = context.l10n.historyDayToday;
    } else if (date == yesterday) {
      dateLabel = context.l10n.historyDayYesterday;
    } else {
      dateLabel = _formatDate(context, date);
    }

    final totalSeconds = events.fold<int>(0, (sum, event) {
      final dur = (event['duration_played'] as num?)?.toDouble() ?? 0;
      return sum + dur.toInt();
    });
    final hours = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    String durationStr;
    if (hours > 0) {
      durationStr = context.l10n.playHistoryDurationHours(hours, mins);
    } else {
      durationStr = context.l10n.playHistoryDurationMinutes(mins);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          label: dateLabel,
          actionLabel:
              context.l10n.playHistorySummary(events.length, durationStr),
        ),
        ...events.map((event) => _buildHistoryItem(context, event, songMap)),
      ],
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    Map<String, dynamic> event,
    Map<String, Song> songMap,
  ) {
    final filename = event['song_filename'] as String? ??
        context.l10n.playHistoryUnknownSong;
    final song = songMap[filename];
    final timestamp = (event['timestamp'] as num?)?.toDouble() ?? 0;
    final date =
        DateTime.fromMillisecondsSinceEpoch((timestamp * 1000).toInt());
    final duration = (event['duration_played'] as num?)?.toDouble() ?? 0;
    final totalLength = (event['total_length'] as num?)?.toDouble() ?? 0;
    final ratio = totalLength > 0 ? duration / totalLength : 0.0;
    final isSkip = duration < 10 && ratio < 0.25;

    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final statusColor = isSkip ? AppTokens.warning : AppTokens.success;
    final statusText =
        isSkip ? context.l10n.playHistorySkip : context.l10n.playHistoryListen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s3),
      child: AppListRow(
        leading: AppRowArt(
          child: AlbumArtImage(
            url: song?.coverUrl ?? '',
            width: AppTokens.artSize,
            height: AppTokens.artSize,
          ),
        ),
        title: song?.title ?? _getFileNameWithoutExt(filename),
        subtitle: song?.artist ?? context.l10n.metaUnknownArtist,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(timeStr, style: AppTokens.meta(context)),
            const SizedBox(height: 2),
            Text(
              statusText.toUpperCase(),
              style: AppTokens.sectionLabel(context).copyWith(
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final l10n = context.l10n;
    final month = switch (date.month) {
      1 => l10n.monthShortJan,
      2 => l10n.monthShortFeb,
      3 => l10n.monthShortMar,
      4 => l10n.monthShortApr,
      5 => l10n.monthShortMay,
      6 => l10n.monthShortJun,
      7 => l10n.monthShortJul,
      8 => l10n.monthShortAug,
      9 => l10n.monthShortSep,
      10 => l10n.monthShortOct,
      11 => l10n.monthShortNov,
      _ => l10n.monthShortDec,
    };
    return l10n.playHistoryDate(month, date.day, date.year);
  }

  String _getFileNameWithoutExt(String filename) {
    final idx = filename.lastIndexOf('.');
    if (idx == -1) return filename;
    final name = filename.substring(0, idx);
    final sepIdx = name.lastIndexOf('/');
    if (sepIdx == -1) return name;
    return name.substring(sepIdx + 1);
  }
}
