import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../domain/services/song_folder_reader.dart';
import '../../domain/services/song_match_planner.dart';
import '../../domain/services/song_replacement_rules.dart';
import '../../l10n/l10n.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../services/storage_service.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_dialog.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/app_list_row.dart';
import '../components/app_screen_header.dart';
import '../components/app_settings.dart';
import '../components/app_sheet.dart';
import '../components/app_surface.dart';
import '../components/batch_progress_overlay.dart';
import '../components/replacement_labels.dart';
import '../motion/motion_physics.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';

/// What each piece of agreement is called when the plan explains itself.
String _signalLabel(AppLocalizations l10n, MatchSignal signal) =>
    switch (signal) {
      MatchSignal.title => l10n.batchReplaceSignalTitle,
      MatchSignal.filename => l10n.batchReplaceSignalFilename,
      MatchSignal.artist => l10n.batchReplaceSignalArtist,
      MatchSignal.album => l10n.batchReplaceSignalAlbum,
      MatchSignal.duration => l10n.batchReplaceSignalDuration,
    };

/// Replaces library songs with better copies of themselves, found by comparing
/// the library against another folder.
///
/// The same substitution the single-song replace offers, done for a whole
/// folder at once — which is the case that actually comes up: a library built
/// from lossy rips, and a folder of lossless releases that supersede them. The
/// comparison proposes, the user disposes: nothing is touched until a specific
/// set of rows is confirmed.
class BatchReplaceScreen extends ConsumerStatefulWidget {
  const BatchReplaceScreen({super.key});

  @override
  ConsumerState<BatchReplaceScreen> createState() => _BatchReplaceScreenState();
}

class _BatchReplaceScreenState extends ConsumerState<BatchReplaceScreen> {
  /// The folder being compared against the library.
  String? _folderPath;

  /// Whether subfolders of [_folderPath] are read too. Release folders are
  /// usually nested under album or artist folders, so this defaults on.
  bool _recursive = true;

  SongMatchPlan? _plan;

  /// The library as it was when the current plan was built, so a row can show
  /// the song it belongs to without re-reading the provider per rebuild.
  Map<String, Song> _librarySongs = const {};

  /// Candidate paths the user has left checked.
  Set<String> _selected = const {};

  /// The comparison itself: listing, then reading tags.
  bool _comparing = false;
  String _comparePhase = '';
  int _comparedDone = 0;
  int _comparedTotal = 0;

  /// The library is only re-read on demand, but a rescan or a rename elsewhere
  /// in the app makes it stale. Re-planning is cheap next to proposing a
  /// replacement for a song that has moved.
  bool _libraryDirty = false;

  bool _running = false;
  bool _cancelRequested = false;
  int _runningDone = 0;
  int _runningTotal = 0;

  /// What the next run does with the files coming in and the files going out.
  /// Remembered between runs, because a user replacing one folder of releases
  /// is going to want the same answer for the next one.
  ReplacementTransport _transport = ReplacementTransport.copy;
  OriginalFileDisposition _disposition = OriginalFileDisposition.hide;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<List<Song>>>(songsProvider, (previous, next) {
      if (previous?.value == next.value) return;
      _libraryDirty = true;
      // Rebuilt so the plan can offer to be re-run: the rows on screen were
      // paired against a library that no longer exists.
      if (mounted && _plan != null) setState(() {});
    });
  }

  List<LibrarySongRef> _libraryRefs() => [
        for (final song in _readLibrary())
          LibrarySongRef(
            filename: song.filename,
            title: song.title,
            artist: song.artist,
            album: song.album,
            duration: song.duration,
          ),
      ];

  List<Song> _readLibrary() => (ref.read(songsProvider).value ?? const <Song>[])
      .where((song) => song.isLocal)
      .toList();

  Map<String, Song> _readLibraryByFilename() => {
        for (final song in _readLibrary()) song.filename: song,
      };

  /// The replacements the current selection describes.
  ///
  /// Resolved against the library as it is *now*, not as it was when the plan
  /// was built, because every replacement re-keys the row the next one runs
  /// against.
  List<ReplacementRequest> _requests() {
    final plan = _plan;
    if (plan == null) return const [];
    final library = _readLibraryByFilename();
    return [
      for (final proposal in plan.proposals)
        if (_selected.contains(proposal.candidate.path))
          if (library[proposal.filename] case final song?)
            ReplacementRequest(song: song, sourcePath: proposal.candidate.path),
    ];
  }

  Future<void> _chooseFolder() async {
    final l10n = context.l10n;
    final Map<String, String>? selection;
    try {
      selection =
          await ref.read(storageServiceProvider).pickMusicFolder(context);
    } on FolderPickerUnavailable catch (e) {
      if (mounted) appSnack(context, e.userFacingHint, tone: AppTone.danger);
      return;
    }
    // Null is a cancel, not a failure.
    if (selection == null || !mounted) return;

    final path = selection['path'] ?? '';
    if (path.isEmpty) return;

    final tracked = await ref.read(storageServiceProvider).getMusicFolders();
    if (!mounted) return;

    // A folder the library already scans holds songs, not replacements for
    // them: the comparison would find every file there twice, and the rules
    // refuse a source from inside the library anyway.
    final insideLibrary = tracked.any((folder) {
      final root = folder['path'] ?? '';
      return root.isNotEmpty &&
          (p.equals(root, path) || p.isWithin(root, path));
    });
    if (insideLibrary) {
      appSnack(context, l10n.batchReplaceInsideLibrary, tone: AppTone.warning);
      return;
    }

    setState(() {
      _folderPath = path;
      _plan = null;
      _selected = const {};
      _libraryDirty = false;
    });
    await _compare();
  }

  /// Lists the folder, reads what each file says about itself, and pairs that
  /// against the library.
  Future<void> _compare() async {
    final folderPath = _folderPath;
    if (folderPath == null || _comparing) return;
    final l10n = context.l10n;

    setState(() {
      _comparing = true;
      _comparePhase = l10n.batchReplacePhaseListing;
      _comparedDone = 0;
      _comparedTotal = 0;
    });

    try {
      final files = await SongFolderReader.listMediaFiles(
        folderPath,
        recursive: _recursive,
      );
      if (!mounted) return;

      setState(() {
        _comparePhase = l10n.batchReplacePhaseReading;
        _comparedTotal = files.length;
      });

      // Progress arrives as plain integers over a port: the reading runs on
      // another isolate and widget state may only be touched from this one.
      final port = ReceivePort();
      final subscription = port.listen((message) {
        if (!mounted) return;
        setState(() => _comparedDone = message as int);
      });

      final List<FolderSongRef> candidates;
      try {
        candidates = await SongFolderReader.readFacts(
          files,
          progress: port.sendPort,
        );
      } finally {
        await subscription.cancel();
        port.close();
      }
      if (!mounted) return;

      final plan = SongMatchPlanner.plan(
        library: _libraryRefs(),
        candidates: candidates,
      );

      setState(() {
        _librarySongs = _readLibraryByFilename();
        _plan = plan;
        // Every proposal starts checked: the plan has already applied the
        // confidence bar, so the interesting decision is what to *un*check.
        _selected = {for (final row in plan.proposals) row.candidate.path};
        _comparing = false;
        _libraryDirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _comparing = false);
      appSnack(context, l10n.batchReplaceCompareError('$e'),
          tone: AppTone.danger);
    }
  }

  void _toggle(String path) {
    setState(() {
      _selected = _selected.contains(path)
          ? ({..._selected}..remove(path))
          : {..._selected, path};
    });
  }

  void _setAll(bool selected) {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      _selected = selected
          ? {for (final row in plan.proposals) row.candidate.path}
          : const {};
    });
  }

  Future<void> _confirm() async {
    final l10n = context.l10n;
    final requests = _requests();
    if (requests.isEmpty) {
      appSnack(context, l10n.batchReplaceNothingSelected);
      return;
    }

    // One sheet for both policies, because they are one decision: what comes in
    // and what goes out. It ends in a button that says how many songs it is
    // about to rewrite.
    final options = await showAppSheet<
        ({
          ReplacementTransport transport,
          OriginalFileDisposition disposition
        })>(
      context,
      title: l10n.batchReplaceOptionsTitle,
      builder: (sheetContext) => _ReplaceOptionsSheet(
        count: requests.length,
        transport: _transport,
        disposition: _disposition,
        onConfirm: (transport, disposition) => Navigator.pop(
          sheetContext,
          (transport: transport, disposition: disposition),
        ),
      ),
    );
    if (options == null || !mounted) return;

    setState(() {
      _transport = options.transport;
      _disposition = options.disposition;
    });

    // The one irreversible combination: the old files are gone from disk, not
    // hidden from the library.
    if (options.disposition == OriginalFileDisposition.delete) {
      final confirmed = await showAppConfirm(
        context,
        title: l10n.batchReplaceDeleteTitle,
        message: l10n.batchReplaceDeleteMessage(requests.length),
        confirmLabel: l10n.batchReplaceDeleteConfirm,
        isDanger: true,
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _running = true;
      _cancelRequested = false;
      _runningDone = 0;
      _runningTotal = requests.length;
    });

    final outcome = await ref.read(songsProvider.notifier).replaceSongsInBatch(
          requests,
          transport: options.transport,
          disposition: options.disposition,
          isCancelled: () => _cancelRequested,
          onProgress: (done, total) {
            if (mounted) {
              setState(() {
                _runningDone = done;
                _runningTotal = total;
              });
            }
          },
        );

    if (!mounted) return;
    setState(() {
      _running = false;
      // The library has been re-keyed underneath the plan, so the rows it is
      // showing no longer describe anything real.
      _plan = null;
      _selected = const {};
    });
    await _showOutcome(outcome);
  }

  /// A failure is either a rule that said no, or an operation that threw, and
  /// the two speak differently: one has wording the rules own, the other has
  /// whatever the filesystem said.
  String _failureDetail(ReplacementFailure failure, AppLocalizations l10n) {
    final rejection = failure.rejection;
    if (rejection == null) {
      return l10n.batchReplaceFailureError('${failure.error}');
    }
    return rejection.label(
      l10n,
      filename: p.basename(failure.request.sourcePath),
    );
  }

  Future<void> _showOutcome(ReplacementOutcome outcome) async {
    final l10n = context.l10n;
    final replaced = outcome.replaced.length;
    final failures = outcome.failures;
    final message = switch ((outcome.stoppedEarly, failures.isEmpty)) {
      (true, true) => l10n.batchReplaceOutcomeStopped(replaced),
      (true, false) =>
        l10n.batchReplaceOutcomeStoppedFailed(replaced, failures.length),
      (false, true) => l10n.batchReplaceOutcomeDone(replaced),
      (false, false) =>
        l10n.batchReplaceOutcomeDoneFailed(replaced, failures.length),
    };

    if (failures.isEmpty) {
      appSnack(context, message,
          tone: outcome.stoppedEarly ? AppTone.warning : AppTone.success);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: l10n.batchReplaceOutcomeTitle,
        message: message,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: failures.length,
            itemBuilder: (context, index) {
              final failure = failures[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.s2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      failure.filename,
                      style: AppTokens.rowTitle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _failureDetail(failure, l10n),
                      style: AppTokens.rowSubtitle(context)
                          .copyWith(color: AppTokens.danger),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          AppDialogAction(
            label: l10n.actionDone,
            isPrimary: true,
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = _plan;

    return PopScope(
      canPop: !_running,
      child: AmbientScaffold(
        appBar: AppTopBar(title: l10n.batchReplaceTitle),
        body: WideContentCenter(
          maxWidth: WideLayout.maxNarrowWidth,
          child: Stack(
            children: [
              ListView(
                physics: const MotionScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.s4,
                  AppTokens.s2,
                  AppTokens.s4,
                  AppTokens.s6,
                ),
                children: [
                  _FolderCard(
                    folderPath: _folderPath,
                    recursive: _recursive,
                    isBusy: _comparing,
                    onChooseFolder: _chooseFolder,
                    onRecursiveChanged: (value) {
                      setState(() => _recursive = value);
                      // The file set changed, so whatever is on screen no longer
                      // describes what would be compared.
                      if (_folderPath != null) _compare();
                    },
                  ),
                  if (_comparing) ...[
                    const SizedBox(height: AppTokens.s4),
                    _CompareProgress(
                      phase: _comparePhase,
                      done: _comparedDone,
                      total: _comparedTotal,
                    ),
                  ] else if (plan != null) ...[
                    const SizedBox(height: AppTokens.s4),
                    if (plan.proposals.isEmpty)
                      AppEmptyState(
                        icon: AppIcons.searchOff,
                        title: l10n.batchReplaceNoMatchesTitle,
                        message: l10n.batchReplaceNoMatchesMessage(
                          plan.candidatesCompared,
                        ),
                      )
                    else ...[
                      _PlanSummary(
                        plan: plan,
                        selectedCount: _selected.length,
                        onSelectAll: () => _setAll(true),
                        onSelectNone: () => _setAll(false),
                      ),
                      const SizedBox(height: AppTokens.s2),
                      AppSurfaceGroup(
                        children: [
                          for (final proposal in plan.proposals)
                            _ProposalRow(
                              proposal: proposal,
                              song: _librarySongs[proposal.filename],
                              isSelected:
                                  _selected.contains(proposal.candidate.path),
                              onTap: () => _toggle(proposal.candidate.path),
                            ),
                        ],
                      ),
                      if (plan.unmatched.isNotEmpty) ...[
                        const SizedBox(height: AppTokens.s4),
                        _UnmatchedSection(
                          candidates: plan.unmatched,
                          onCompareAgain: _libraryDirty ? _compare : null,
                        ),
                      ],
                      const SizedBox(height: AppTokens.s4),
                      FilledButton(
                        onPressed:
                            _selected.isEmpty || _running ? null : _confirm,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: AppTokens.onAccent(
                            Theme.of(context).colorScheme.primary,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTokens.s3,
                          ),
                        ),
                        child: Text(l10n.batchReplaceRun(_selected.length)),
                      ),
                    ],
                  ],
                ],
              ),
              if (_running)
                BatchProgressOverlay(
                  phase: l10n.batchReplacePhaseReplacing,
                  done: _runningDone,
                  total: _runningTotal,
                  cancelRequested: _cancelRequested,
                  onCancel: () => setState(() => _cancelRequested = true),
                  stoppingLabel: l10n.batchReplaceStopping,
                  waitingLabel: l10n.bulkRenamePleaseWait,
                  cancelLabel: l10n.bulkRenameStop,
                  counterLabel: l10n.bulkRenameProgressCount,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The folder being compared, and the way to point somewhere else.
class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folderPath,
    required this.recursive,
    required this.isBusy,
    required this.onChooseFolder,
    required this.onRecursiveChanged,
  });

  final String? folderPath;
  final bool recursive;
  final bool isBusy;
  final VoidCallback onChooseFolder;
  final ValueChanged<bool> onRecursiveChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppSurface(
      padding: const EdgeInsets.all(AppTokens.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.batchReplaceIntro, style: AppTokens.rowSubtitle(context)),
          const SizedBox(height: AppTokens.s4),
          Text(
            l10n.batchReplaceFolderLabel,
            style: AppTokens.sectionLabel(context),
          ),
          const SizedBox(height: AppTokens.s2),
          Row(
            children: [
              Expanded(
                child: Text(
                  folderPath ?? l10n.batchReplaceNoFolder,
                  style: folderPath == null
                      ? AppTokens.rowSubtitle(context)
                      : AppTokens.rowTitle(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppTokens.s3),
              TextButton(
                onPressed: isBusy ? null : onChooseFolder,
                child: Text(folderPath == null
                    ? l10n.batchReplaceChooseFolder
                    : l10n.batchReplaceChangeFolder),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s2),
          AppSettingsSwitch(
            icon: AppIcons.folderZip,
            title: l10n.batchReplaceSubfolders,
            value: recursive,
            onChanged: isBusy ? null : onRecursiveChanged,
          ),
        ],
      ),
    );
  }
}

/// How far the comparison has got.
class _CompareProgress extends StatelessWidget {
  const _CompareProgress({
    required this.phase,
    required this.done,
    required this.total,
  });

  final String phase;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppTokens.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(phase, style: AppTokens.rowTitle(context)),
              const Spacer(),
              // Reading a folder has no count until it has been listed, so a
              // "0" here would be a verdict the screen cannot make yet.
              if (total > 0)
                Text(
                  context.l10n.bulkRenameProgressCount(done, total),
                  style: AppTokens.rowSubtitle(context),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.s3),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.rPill),
            child: LinearProgressIndicator(
              value: total == 0 ? null : done / total,
              minHeight: 6,
              backgroundColor: AppTokens.wellFill,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the comparison found, and the way to narrow it.
class _PlanSummary extends StatelessWidget {
  const _PlanSummary({
    required this.plan,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onSelectNone,
  });

  final SongMatchPlan plan;
  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectNone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppSurface(
      padding: const EdgeInsets.all(AppTokens.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.batchReplaceMatched(plan.proposals.length),
            style: AppTokens.rowTitle(context),
          ),
          const SizedBox(height: AppTokens.s1),
          Text(
            l10n.batchReplaceCompared(
              plan.candidatesCompared,
              plan.libraryCompared,
            ),
            style: AppTokens.rowSubtitle(context),
          ),
          const SizedBox(height: AppTokens.s3),
          Row(
            children: [
              TextButton(
                onPressed:
                    selectedCount == plan.proposals.length ? null : onSelectAll,
                child: Text(l10n.batchReplaceSelectAll),
              ),
              TextButton(
                onPressed: selectedCount == 0 ? null : onSelectNone,
                child: Text(l10n.batchReplaceSelectNone),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One pairing: the song, the file proposed to replace it with, and why.
class _ProposalRow extends StatelessWidget {
  const _ProposalRow({
    required this.proposal,
    required this.song,
    required this.isSelected,
    required this.onTap,
  });

  final SongMatchProposal proposal;
  final Song? song;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final signals =
        proposal.signals.map((s) => _signalLabel(l10n, s)).join(', ');

    return AppListRow(
      tall: true,
      isActive: isSelected,
      leading: AppRowIcon(
        icon: isSelected ? AppIcons.checkCircle : AppIcons.circle,
        active: isSelected,
      ),
      title: song?.title.isEmpty ?? true
          ? p.basenameWithoutExtension(proposal.filename)
          : song!.title,
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            proposal.filename,
            style: AppTokens.rowSubtitle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            p.basename(proposal.candidate.path),
            style: AppTokens.rowSubtitle(context)
                .copyWith(color: AppTokens.fgSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            [
              signals,
              if (proposal.lengthDiffers) l10n.batchReplaceLengthDiffers,
            ].join(' · '),
            style: AppTokens.rowSubtitle(context).copyWith(
              color: proposal.lengthDiffers
                  ? AppTokens.warning
                  : AppTokens.fgTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Text(
        l10n.batchReplaceConfidence(proposal.confidencePercent),
        style: AppTokens.rowSubtitle(context).copyWith(
          color: AppTokens.fgSecondary,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// The files in the folder that nothing in the library claimed.
class _UnmatchedSection extends StatelessWidget {
  const _UnmatchedSection({
    required this.candidates,
    required this.onCompareAgain,
  });

  final List<FolderSongRef> candidates;
  final VoidCallback? onCompareAgain;

  /// Would be a wall of names on a folder full of new music, and the ones the
  /// user needs to see are the ones they expected to match.
  static const int _shown = 8;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hidden = candidates.length - _shown;

    return AppSurface(
      padding: const EdgeInsets.all(AppTokens.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.batchReplaceUnmatched(candidates.length),
            style: AppTokens.rowTitle(context),
          ),
          const SizedBox(height: AppTokens.s2),
          for (final candidate in candidates.take(_shown))
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.s1),
              child: Text(
                p.basename(candidate.path),
                style: AppTokens.rowSubtitle(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (hidden > 0)
            Text(
              l10n.batchReplaceAndMore(hidden),
              style: AppTokens.rowSubtitle(context),
            ),
          if (onCompareAgain != null) ...[
            const SizedBox(height: AppTokens.s2),
            TextButton(
              onPressed: onCompareAgain,
              child: Text(l10n.batchReplaceCompareAgain),
            ),
          ],
        ],
      ),
    );
  }
}

/// What comes in and what goes out, chosen in one place.
class _ReplaceOptionsSheet extends StatefulWidget {
  const _ReplaceOptionsSheet({
    required this.count,
    required this.transport,
    required this.disposition,
    required this.onConfirm,
  });

  final int count;
  final ReplacementTransport transport;
  final OriginalFileDisposition disposition;
  final void Function(
    ReplacementTransport transport,
    OriginalFileDisposition disposition,
  ) onConfirm;

  @override
  State<_ReplaceOptionsSheet> createState() => _ReplaceOptionsSheetState();
}

class _ReplaceOptionsSheetState extends State<_ReplaceOptionsSheet> {
  late ReplacementTransport _transport = widget.transport;
  late OriginalFileDisposition _disposition = widget.disposition;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // The shell (handle, title, corners) comes from [showAppSheet].
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTokens.s5, 0, AppTokens.s5, AppTokens.s2),
          child: Text(
            l10n.batchReplaceTransportSection,
            style: AppTokens.sectionLabel(context),
          ),
        ),
        AppSheetAction(
          icon: AppIcons.copy,
          label: l10n.batchReplaceTransportCopy,
          description: l10n.batchReplaceTransportCopyHint,
          trailing: _check(_transport == ReplacementTransport.copy),
          onTap: () => setState(() => _transport = ReplacementTransport.copy),
        ),
        AppSheetAction(
          icon: AppIcons.folderMove,
          label: l10n.batchReplaceTransportMove,
          description: l10n.batchReplaceTransportMoveHint,
          trailing: _check(_transport == ReplacementTransport.move),
          onTap: () => setState(() => _transport = ReplacementTransport.move),
        ),
        const SizedBox(height: AppTokens.s4),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTokens.s5, 0, AppTokens.s5, AppTokens.s2),
          child: Text(
            l10n.batchReplaceOriginalSection,
            style: AppTokens.sectionLabel(context),
          ),
        ),
        AppSheetAction(
          icon: AppIcons.visibilityOff,
          label: l10n.batchReplaceOriginalHide,
          description: l10n.batchReplaceOriginalHideHint,
          trailing: _check(_disposition == OriginalFileDisposition.hide),
          onTap: () =>
              setState(() => _disposition = OriginalFileDisposition.hide),
        ),
        AppSheetAction(
          icon: AppIcons.deleteSweep,
          label: l10n.batchReplaceOriginalDelete,
          description: l10n.batchReplaceOriginalDeleteHint,
          isDanger: _disposition == OriginalFileDisposition.delete,
          trailing: _check(_disposition == OriginalFileDisposition.delete),
          onTap: () =>
              setState(() => _disposition = OriginalFileDisposition.delete),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTokens.s5, AppTokens.s4, AppTokens.s5, AppTokens.s6),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onConfirm(_transport, _disposition),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: AppTokens.onAccent(
                  Theme.of(context).colorScheme.primary,
                ),
                padding: const EdgeInsets.symmetric(vertical: AppTokens.s3),
              ),
              child: Text(l10n.batchReplaceRun(widget.count)),
            ),
          ),
        ),
      ],
    );
  }

  /// Selection is a glyph, not a border — the sheet's own affordances carry the
  /// rest.
  Widget _check(bool selected) => selected
      ? const AppIcon(AppIcons.checkCircle, size: 20)
      : const SizedBox(width: 20);
}
