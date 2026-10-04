import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/bulk_rename_planner.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_dialog.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/app_screen_header.dart';
import '../components/app_surface.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';

/// How each metadata field is named in the builder. "Current name" rather than
/// "stem" because that is the thing the user is thinking about.
const Map<BulkRenameToken, String> _tokenLabels = {
  BulkRenameToken.title: 'Title',
  BulkRenameToken.artist: 'Artist',
  BulkRenameToken.album: 'Album',
  BulkRenameToken.stem: 'Current name',
  BulkRenameToken.track: 'Number',
  BulkRenameToken.year: 'Year',
};

/// Builds the plan in a worker isolate.
///
/// Top level on purpose, and the whole hop lives here rather than in the screen.
/// The closure handed to [Isolate.run] travels with the context it was written
/// in, so one written inside the screen carries that State's fields with it —
/// the debounce [Timer], the progress [ReceivePort] — and both own native
/// resources, which makes the whole message unsendable. Written here, the
/// closure can only see its three arguments.
///
/// [progress] is sent the running count as it goes. Widget state cannot be
/// touched from the worker isolate, so the count travels as a plain integer.
Future<List<BulkRenamePlan>> _planOffThread(
  List<Song> songs,
  List<BulkRenameSegment> segments,
  SendPort? progress,
) =>
    Isolate.run(() => _planWithProgress(songs, segments, progress));

List<BulkRenamePlan> _planWithProgress(
  List<Song> songs,
  List<BulkRenameSegment> segments,
  SendPort? progress,
) =>
    BulkRenamePlanner.plan(
      songs: songs,
      segments: segments,
      onProgress: progress == null ? null : (done) => progress.send(done),
    );

/// Rebuilds the filenames of the whole library from a format.
///
/// The format is a list of segments the user drags into order, so "move the
/// artist after the title and add a suffix" is a rearrangement rather than a
/// pattern to memorise. Every rename also carries its stats and caches across,
/// and writes to the database only once the file is known to be at its new name.
class BulkRenameScreen extends ConsumerStatefulWidget {
  const BulkRenameScreen({super.key});

  @override
  ConsumerState<BulkRenameScreen> createState() => _BulkRenameScreenState();
}

class _BulkRenameScreenState extends ConsumerState<BulkRenameScreen> {
  /// Index into [BulkRenameSegment.presets], or null when the user is building
  /// their own format.
  int? _presetIndex = 0;

  List<_Segment> _segments = _segmentsFrom(BulkRenameSegment.presets.first);

  /// What each song *would* be called.
  List<BulkRenamePlan> _preview = const [];

  /// The same plans with on-disk collisions removed.
  List<BulkRenamePlan> _validated = const [];

  Timer? _previewTimer;
  StreamSubscription<Object?>? _analysisSubscription;
  bool _isRunning = false;
  bool _cancelRequested = false;

  /// Bumped whenever the format changes. Anything async still in flight carries
  /// the generation it started under, so a slow check that finishes late is
  /// discarded rather than left to overwrite the preview for a format the user
  /// has already moved on from.
  int _generation = 0;

  /// Progress of the filesystem half of the preview.
  int _checkingDone = 0;
  int _checkingTotal = 0;
  bool _cancelCheck = false;

  /// The planning half. Naming a few thousand songs is a string build and a
  /// regex apiece, and until it lands there is no count to report — so the
  /// screen says it is working rather than showing a "0" that is not a verdict.
  bool _analyzing = false;
  int _analyzedDone = 0;
  int _analyzedTotal = 0;
  int _analyzedPercent = 0;

  /// Phase label plus a step counter, because a few hundred renames is a
  /// sequence of very differently-sized steps and "340" alone says nothing about
  /// which one is running.
  String _phase = '';
  int _done = 0;
  int _total = 0;

  bool get _isChecking => _checkingTotal > 0 && _checkingDone < _checkingTotal;

  /// True while a plan is being built. Nothing downstream may be trusted until
  /// it is false: [plan] has to return before there is a count to show.
  bool get _isBusy => _analyzing || _isChecking;

  /// The whole library. A maintenance sweep with no selection to make: the user
  /// came here to fix the library, not a handful of songs they had lined up.
  List<Song> get _library => ref.read(songsProvider).value ?? const [];

  /// Set by the cancel button and read by the batch between files.
  bool _shouldCancel() => _cancelRequested;

  /// Asks the same layer the rename goes through whether a name is taken.
  ///
  /// A plain `File.exists` cannot see inside an Android document tree, so on a
  /// device holding only a SAF grant every name would look free and the rename
  /// would overwrite whatever was there.
  Future<bool> _targetTaken(String path) =>
      ref.read(fileManagerServiceProvider).fileExistsAt(path);

  @override
  void initState() {
    super.initState();
    // After the first frame: setState is illegal from initState, and the
    // library can land in either direction around it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestPreview();
    });
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _analysisSubscription?.cancel();
    for (final segment in _segments) {
      segment.dispose();
    }
    super.dispose();
  }

  /// Plans the library against the current format, then checks it against the
  /// filesystem.
  ///
  /// Debounced before the isolate hop, so holding a key down does not queue a
  /// plan per character.
  void _requestPreview() {
    _generation += 1;
    final generation = _generation;
    _previewTimer?.cancel();
    _analysisSubscription?.cancel();

    final songs = _library;
    // Nothing to plan against yet. The listener in build re-runs this the
    // moment the songs land; reporting a count here would be reporting on an
    // empty library.
    if (songs.isEmpty && ref.read(songsProvider).isLoading) {
      return;
    }

    setState(() {
      _analyzing = true;
      _analyzedDone = 0;
      _analyzedTotal = songs.length;
      _preview = const [];
      _validated = const [];
    });

    final segments = _segments.map((s) => s.toPlannerSegment()).toList();

    _previewTimer = Timer(const Duration(milliseconds: 120), () async {
      final plans = await _analyze(songs, segments, generation);
      _applyPreview(plans, generation);
    });
  }

  /// Builds the plan in an isolate, reporting how far along it is.
  ///
  /// Progress arrives as plain integers over a [ReceivePort] rather than a
  /// callback: the planning runs on another isolate, and widget state may only
  /// be touched from the one this screen lives on.
  Future<List<BulkRenamePlan>> _analyze(
    List<Song> songs,
    List<BulkRenameSegment> segments,
    int generation,
  ) async {
    final port = ReceivePort();
    final subscription = port.listen((message) {
      if (!mounted || generation != _generation) return;
      final done = message as int;
      final total = _analyzedTotal;
      // Throttled to whole percents: one rebuild per song is hundreds of them
      // to move a number that only has a hundred values.
      final percent = total == 0 ? 100 : done * 100 ~/ total;
      if (done == _analyzedDone) return;
      setState(() {
        _analyzedDone = done;
        _analyzedPercent = percent;
      });
    });
    _analysisSubscription = subscription;

    try {
      final plans = await _planOffThread(songs, segments, port.sendPort);
      // Guarded on the generation: a newer format is already analysing, and
      // clearing the flag here would report "0" for its run.
      if (mounted && generation == _generation) {
        setState(() {
          _analyzing = false;
          _analyzedPercent = 100;
        });
      }
      return plans;
    } on Object catch (error) {
      // Swallowed into a message rather than left to throw: an unhandled error
      // here would strand the screen on "Analyzing library", which is the one
      // state it must never sit in.
      if (mounted && generation == _generation) {
        setState(() => _analyzing = false);
        appSnack(context, 'Could not analyze the library: $error');
      }
      return const [];
    } finally {
      subscription.cancel();
      if (identical(_analysisSubscription, subscription)) {
        _analysisSubscription = null;
      }
      port.close();
    }
  }

  void _applyPreview(List<BulkRenamePlan> plans, int generation) {
    if (!mounted || generation != _generation) return;
    setState(() => _preview = plans);
    _validate(generation);
  }

  /// Asks the filesystem whether each proposed name is free.
  ///
  /// Never awaited by the caller. It reports progress and can be stopped, because
  /// on a large library over removable storage it runs for long enough that a
  /// silent wait would read as a frozen app.
  Future<void> _validate(int generation) async {
    final plans = _preview;
    if (plans.isEmpty) return;

    setState(() {
      _cancelCheck = false;
      _checkingDone = 0;
      _checkingTotal = plans.where((entry) => entry.willRename).length;
    });

    final checked = await BulkRenamePlanner.excludeExistingTargets(
      plans,
      exists: _targetTaken,
      isCancelled: () => _cancelCheck,
      onProgress: (done, total) => _reportChecking(done, total, generation),
    );

    if (!mounted || generation != _generation) return;
    setState(() {
      _validated = checked;
      _checkingTotal = 0;
    });
  }

  /// Throttled to whole percents. The callback fires once per batch, and at a few
  /// thousand names that is hundreds of rebuilds of a forty-row preview to move a
  /// bar that cannot show more than a hundred of them anyway.
  void _reportChecking(int done, int total, int generation) {
    if (!mounted || generation != _generation) return;
    final current = _checkingTotal == 0 ? 0.0 : _checkingDone / _checkingTotal;
    if ((done / total - current) * 100 < 1 && done < total) return;
    setState(() {
      _checkingDone = done;
      _checkingTotal = total;
    });
  }

  int get _renameCount => _validated.where((e) => e.willRename).length;

  int get _skippedCount => _validated.where((e) => !e.willRename).length;

  /// The plan as it stands right now, rebuilt off the UI thread so that
  /// confirming a format never costs a dropped frame.
  Future<List<BulkRenamePlan>> _planNow() {
    final segments = _segments.map((s) => s.toPlannerSegment()).toList();
    return _planOffThread(_library, segments, null);
  }

  void _setPreset(int index) {
    for (final segment in _segments) {
      segment.dispose();
    }
    setState(() {
      _presetIndex = index;
      _segments = _segmentsFrom(BulkRenameSegment.presets[index]);
    });
    _requestPreview();
  }

  void _editFormat() {
    for (final segment in _segments) {
      segment.dispose();
    }
    setState(() {
      _presetIndex = null;
      _segments = [_Segment.token(BulkRenameToken.title)];
    });
    _requestPreview();
  }

  Future<void> _confirm() async {
    if (_renameCount == 0 || _isRunning || _isBusy) return;

    final confirmed = await showAppConfirm(
      context,
      title: 'Rename $_renameCount songs',
      message: 'Files are renamed in place. Play stats, playlists and cached '
          'artwork move across with them, and the database is kept in step as '
          'each file lands.',
      confirmLabel: 'Rename',
    );
    if (confirmed != true || !mounted) return;

    // The preview can be a keystroke stale by now, so re-check before touching
    // anything: a target that got taken in the meantime must be reported, not
    // overwritten. This is the long one on a big library, so it runs under the
    // same visible progress rather than as a silent wait behind a dialog.
    _generation += 1;
    final generation = _generation;
    final fresh = await _planNow();
    if (!mounted || generation != _generation) return;

    setState(() {
      _preview = fresh;
      _cancelCheck = false;
      _checkingDone = 0;
      _checkingTotal = fresh.where((e) => e.willRename).length;
    });

    final plans = await BulkRenamePlanner.excludeExistingTargets(
      fresh,
      exists: _targetTaken,
      isCancelled: () => _cancelCheck,
      onProgress: (done, total) => _reportChecking(done, total, generation),
    );
    if (!mounted || generation != _generation) return;

    setState(() {
      _validated = plans;
      _checkingTotal = 0;
    });

    final actionable = plans.where((e) => e.willRename).length;
    if (actionable == 0) {
      appSnack(context, 'Nothing left to rename');
      return;
    }

    setState(() {
      _isRunning = true;
      _cancelRequested = false;
      _phase = 'Starting';
      _done = 0;
      _total = actionable;
    });

    final result = await ref.read(songsProvider.notifier).bulkRenameSongs(
      plans,
      isCancelled: _shouldCancel,
      onProgress: (label, done, total) {
        if (mounted) {
          setState(() {
            _phase = label;
            _done = done;
            _total = total;
          });
        }
      },
    );

    if (!mounted) return;
    setState(() => _isRunning = false);
    await showAppResultsSheet(context, result);
  }

  @override
  Widget build(BuildContext context) {
    // The library is loaded asynchronously, and a rescan replaces the list
    // without ever passing through an empty value. Re-plan on any change of the
    // song list rather than on one specific loading edge, or the preview is
    // built against whatever happened to be there when the screen opened.
    ref.listen<AsyncValue<List<Song>>>(songsProvider, (previous, next) {
      if (previous?.value != next.value) _requestPreview();
    });

    return PopScope(
      canPop: !_isRunning,
      child: AmbientScaffold(
        appBar: AppTopBar(title: 'Bulk Rename'),
        body: WideContentCenter(
          maxWidth: WideLayout.maxNarrowWidth,
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.s4,
                  AppTokens.s2,
                  AppTokens.s4,
                  AppTokens.s6,
                ),
                children: [
                  _FormatSection(
                    presetIndex: _presetIndex,
                    onPresetSelected: _setPreset,
                    onEdit: _editFormat,
                  ),
                  const SizedBox(height: AppTokens.s4),
                  if (_presetIndex == null) ...[
                    _SegmentBuilder(
                      segments: _segments,
                      onChanged: _requestPreview,
                      onReorderItem: _reorder,
                      onRemove: _removeAt,
                      onAddToken: _addToken,
                      onAddLiteral: _addLiteral,
                    ),
                    const SizedBox(height: AppTokens.s4),
                  ],
                  _RenamePreview(
                    plans: _validated.isEmpty ? _preview : _validated,
                    renameCount: _renameCount,
                    skippedCount: _skippedCount,
                    isAnalyzing: _analyzing,
                    analyzedDone: _analyzedDone,
                    analyzedTotal: _analyzedTotal,
                    analyzedPercent: _analyzedPercent,
                    isChecking: _isChecking,
                    checkingDone: _checkingDone,
                    checkingTotal: _checkingTotal,
                    onStopChecking: () => setState(() => _cancelCheck = true),
                    onConfirm: _confirm,
                  ),
                ],
              ),
              if (_isRunning)
                _ProgressOverlay(
                  phase: _phase,
                  done: _done,
                  total: _total,
                  cancelRequested: _cancelRequested,
                  onCancel: () => setState(() => _cancelRequested = true),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final segment = _segments.removeAt(oldIndex);
      _segments.insert(newIndex, segment);
    });
    _requestPreview();
  }

  void _removeAt(int index) {
    setState(() {
      _segments.removeAt(index).dispose();
    });
    _requestPreview();
  }

  void _addToken(BulkRenameToken token) {
    setState(() => _segments.add(_Segment.token(token)));
    _requestPreview();
  }

  void _addLiteral() {
    setState(() => _segments.add(_Segment.literal(' - ')));
    _requestPreview();
  }
}

/// A builder row: a metadata field, or literal text of the user's own.
///
/// Carries its own text controller and a key that survives reordering, so
/// dragging a row past another never scrambles what each one says.
class _Segment {
  _Segment.token(BulkRenameToken this.token)
      : id = UniqueKey(),
        controller = null;

  _Segment.literal(String text)
      : id = UniqueKey(),
        token = null,
        controller = TextEditingController(text: text);

  final UniqueKey id;
  final BulkRenameToken? token;
  final TextEditingController? controller;

  BulkRenameSegment toPlannerSegment() => token != null
      ? BulkRenameSegment.token(token!)
      : BulkRenameSegment.literal(controller?.text ?? '');

  void dispose() => controller?.dispose();
}

List<_Segment> _segmentsFrom(List<BulkRenameSegment> template) => [
      for (final segment in template)
        if (segment.isLiteral)
          _Segment.literal(segment.literal)
        else
          _Segment.token(segment.token!),
    ];

/// The four formats, as selectable blocks. Selection is a fill change, never
/// an outline.
class _FormatSection extends StatelessWidget {
  const _FormatSection({
    required this.presetIndex,
    required this.onPresetSelected,
    required this.onEdit,
  });

  final int? presetIndex;
  final ValueChanged<int> onPresetSelected;
  final VoidCallback onEdit;

  static const List<String> _labels = [
    'Title',
    'Artist - Title',
    'Artist - Album - Title',
    'Custom',
  ];

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isCustom = presetIndex == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(bottom: AppTokens.s2, left: AppTokens.s1),
          child: Text('FORMAT', style: AppTokens.sectionLabel(context)),
        ),
        for (var i = 0; i < _labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.s2),
            child: _FormatBlock(
              label: _labels[i],
              // The custom format's own shape is shown instead of a sample, so
              // the block always reads as "what you will get".
              subtitle: i == 3 && isCustom ? 'Your own arrangement' : null,
              isSelected: i == 3 ? isCustom : presetIndex == i,
              accent: accent,
              onTap: i == 3 ? onEdit : () => onPresetSelected(i),
            ),
          ),
      ],
    );
  }
}

class _FormatBlock extends StatelessWidget {
  const _FormatBlock({
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: isSelected ? 2 : 1,
      accentTint: isSelected ? accent : null,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s4,
        vertical: AppTokens.s3,
      ),
      borderRadius: BorderRadius.circular(AppTokens.rSm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTokens.rowTitle(context)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child:
                        Text(subtitle!, style: AppTokens.rowSubtitle(context)),
                  ),
              ],
            ),
          ),
          if (isSelected)
            AppIcon(AppIcons.tick, size: AppTokens.iconMd, color: accent),
        ],
      ),
    );
  }
}

/// The drag-to-arrange format editor.
class _SegmentBuilder extends StatelessWidget {
  const _SegmentBuilder({
    required this.segments,
    required this.onChanged,
    required this.onReorderItem,
    required this.onRemove,
    required this.onAddToken,
    required this.onAddLiteral,
  });

  final List<_Segment> segments;
  final VoidCallback onChanged;
  final void Function(int oldIndex, int newIndex) onReorderItem;
  final ValueChanged<int> onRemove;
  final ValueChanged<BulkRenameToken> onAddToken;
  final VoidCallback onAddLiteral;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(bottom: AppTokens.s2, left: AppTokens.s1),
          child: Text('ARRANGE', style: AppTokens.sectionLabel(context)),
        ),
        if (segments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.s2),
            child: Text(
              'Add a field below to start building a name.',
              style: AppTokens.rowSubtitle(context),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: segments.length,
            onReorderItem: onReorderItem,
            itemBuilder: (context, index) => Padding(
              key: segments[index].id,
              padding: const EdgeInsets.only(bottom: AppTokens.s2),
              child: _SegmentRow(
                index: index,
                segment: segments[index],
                tokenLabel: segments[index].token == null
                    ? null
                    : _tokenLabels[segments[index].token!]!,
                onChanged: onChanged,
                onRemove: () => onRemove(index),
              ),
            ),
          ),
        const SizedBox(height: AppTokens.s2),
        _AddRow(onAddToken: onAddToken, onAddLiteral: onAddLiteral),
      ],
    );
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({
    required this.index,
    required this.segment,
    required this.tokenLabel,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _Segment segment;
  final String? tokenLabel;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(right: AppTokens.s2),
            child: AppIcon(
              AppIcons.dragHandle,
              size: AppTokens.iconMd,
              color: AppTokens.fgTertiary,
            ),
          ),
        ),
        Expanded(
          child: tokenLabel != null
              ? _TokenBlock(label: tokenLabel!, accent: accent)
              : _LiteralField(segment: segment, onChanged: onChanged),
        ),
        IconButton(
          icon: const AppIcon(AppIcons.close, size: AppTokens.iconSm),
          tooltip: 'Remove',
          color: AppTokens.fgTertiary,
          onPressed: onRemove,
        ),
      ],
    );
  }
}

class _TokenBlock extends StatelessWidget {
  const _TokenBlock({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s3,
        vertical: AppTokens.s3,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppTokens.surface(2),
          accent.withValues(alpha: AppTokens.accentWashAlpha),
        ),
        borderRadius: BorderRadius.circular(AppTokens.rSm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTokens.rowTitle(context)
                  .copyWith(color: AppTokens.onAccent(accent)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiteralField extends StatelessWidget {
  const _LiteralField({required this.segment, required this.onChanged});

  final _Segment segment;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: segment.controller,
      onChanged: (_) => onChanged(),
      style: AppTokens.rowTitle(context),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Text, e.g. " - "',
        hintStyle: AppTokens.rowSubtitle(context),
        filled: true,
        fillColor: AppTokens.wellFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rSm),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.onAddToken, required this.onAddLiteral});

  final ValueChanged<BulkRenameToken> onAddToken;
  final VoidCallback onAddLiteral;

  static const List<BulkRenameToken> _tokens = [
    BulkRenameToken.title,
    BulkRenameToken.artist,
    BulkRenameToken.album,
    BulkRenameToken.stem,
    BulkRenameToken.track,
    BulkRenameToken.year,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.s2,
      runSpacing: AppTokens.s2,
      children: [
        for (final token in _tokens)
          ActionChip(
            avatar: const AppIcon(AppIcons.add, size: AppTokens.iconSm),
            label: Text(_tokenLabels[token]!),
            onPressed: () => onAddToken(token),
          ),
        ActionChip(
          avatar: const AppIcon(AppIcons.edit, size: AppTokens.iconSm),
          label: const Text('Text'),
          onPressed: onAddLiteral,
        ),
      ],
    );
  }
}

/// Old name to new name, with anything skipped called out and why.
class _RenamePreview extends StatelessWidget {
  const _RenamePreview({
    required this.plans,
    required this.renameCount,
    required this.skippedCount,
    required this.isAnalyzing,
    required this.analyzedDone,
    required this.analyzedTotal,
    required this.analyzedPercent,
    required this.isChecking,
    required this.checkingDone,
    required this.checkingTotal,
    required this.onStopChecking,
    required this.onConfirm,
  });

  final List<BulkRenamePlan> plans;
  final int renameCount;
  final int skippedCount;

  /// Whether the plan is still being built, and how far along it is.
  final bool isAnalyzing;
  final int analyzedDone;
  final int analyzedTotal;
  final int analyzedPercent;

  /// Whether the filesystem half is still running, and how far along it is.
  final bool isChecking;
  final int checkingDone;
  final int checkingTotal;

  final VoidCallback onStopChecking;
  final VoidCallback onConfirm;

  /// Enough to confirm the format is right without paying to build a thousand
  /// rows for a thousand songs.
  static const int _maxRows = 40;

  @override
  Widget build(BuildContext context) {
    final shown = plans.take(_maxRows).toList();
    final hidden = plans.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(bottom: AppTokens.s2, left: AppTokens.s1),
          child: Text(
            'PREVIEW',
            style: AppTokens.sectionLabel(context),
          ),
        ),
        AppSurface(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(AppTokens.rSm),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTokens.s3),
                child: isAnalyzing
                    // A count cannot be reported until the plan exists, and "0"
                    // during that window is indistinguishable from a library
                    // that genuinely has nothing to rename.
                    ? Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: AppTokens.s3),
                          Text(
                            'Analyzing library',
                            style: AppTokens.rowTitle(context),
                          ),
                          const Spacer(),
                          Text(
                            '$analyzedPercent%',
                            style: AppTokens.rowSubtitle(context),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Text(
                            '$renameCount to rename',
                            style: AppTokens.rowTitle(context),
                          ),
                          const Spacer(),
                          if (skippedCount > 0)
                            Text(
                              '$skippedCount skipped',
                              style: AppTokens.rowSubtitle(context)
                                  .copyWith(color: AppTokens.warning),
                            ),
                        ],
                      ),
              ),
              if (isAnalyzing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppTokens.s3, 0, AppTokens.s3, AppTokens.s3),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.rPill),
                    child: LinearProgressIndicator(
                      value:
                          analyzedTotal == 0 ? 1 : analyzedDone / analyzedTotal,
                      minHeight: 6,
                      backgroundColor: AppTokens.wellFill,
                    ),
                  ),
                ),
              // Between the format and the count above it. Without it the
              // numbers simply stop moving for as long as the check takes, and
              // on a big library over an SD card that is long enough to look like
              // the app has hung.
              if (isChecking)
                _CheckingBar(
                  done: checkingDone,
                  total: checkingTotal,
                  onStop: onStopChecking,
                ),
              // Held back while re-planning: these rows belong to the previous
              // format and the count above is still moving.
              if (!isAnalyzing) ...[
                for (final plan in shown) _PreviewRow(plan: plan),
                if (hidden > 0)
                  Padding(
                    padding: const EdgeInsets.all(AppTokens.s3),
                    child: Text(
                      'and $hidden more',
                      style: AppTokens.rowSubtitle(context),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTokens.s4),
        FilledButton(
          // Held down until the plan and the check land: the count above is
          // still moving, so acting on it now would act on a number the app
          // does not stand behind.
          onPressed:
              renameCount == 0 || isAnalyzing || isChecking ? null : onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: AppTokens.onAccent(
              Theme.of(context).colorScheme.primary,
            ),
            padding: const EdgeInsets.symmetric(vertical: AppTokens.s3),
          ),
          child: Text('Rename $renameCount songs'),
        ),
      ],
    );
  }
}

/// How far along the on-disk name check is, with a way out.
///
/// The check is one filesystem call per song and cannot be meaningfully
/// shortened, so the honest options are to show it moving or to let the user
/// abandon it. Both, because a bar that cannot be stopped is just a slower freeze.
class _CheckingBar extends StatelessWidget {
  const _CheckingBar({
    required this.done,
    required this.total,
    required this.onStop,
  });

  final int done;
  final int total;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTokens.s3, 0, AppTokens.s3, AppTokens.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.rPill),
            child: LinearProgressIndicator(
              value: total == 0 ? 1 : done / total,
              minHeight: 6,
              backgroundColor: AppTokens.wellFill,
            ),
          ),
          const SizedBox(height: AppTokens.s2),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Checking names — $done of $total',
                  style: AppTokens.rowSubtitle(context),
                ),
              ),
              TextButton(
                onPressed: onStop,
                style: TextButton.styleFrom(
                  foregroundColor: AppTokens.fgSecondary,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Stop'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.plan});

  final BulkRenamePlan plan;

  @override
  Widget build(BuildContext context) {
    final skipped = plan.skipReason != null;
    final newNameColor = skipped ? AppTokens.warning : AppTokens.fgSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTokens.s3, 0, AppTokens.s3, AppTokens.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.song.filename,
            style: AppTokens.rowSubtitle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          if (skipped)
            Text(
              plan.skipReason!,
              style: AppTokens.rowSubtitle(context)
                  .copyWith(color: AppTokens.warning),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            Text(
              plan.newFilename,
              style: AppTokens.rowTitle(context).copyWith(color: newNameColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _ProgressOverlay extends StatelessWidget {
  const _ProgressOverlay({
    required this.phase,
    required this.done,
    required this.total,
    required this.cancelRequested,
    required this.onCancel,
  });

  final String phase;
  final int done;
  final int total;
  final bool cancelRequested;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;

    return Positioned.fill(
      child: ColoredBox(
        color:
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.92),
        child: Center(
          child: AppSurface(
            level: 2,
            depth: AppDepth.floating,
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            padding: const EdgeInsets.all(AppTokens.s5),
            child: SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cancelRequested ? 'Stopping...' : phase,
                    style: AppTokens.rowTitle(context),
                  ),
                  const SizedBox(height: AppTokens.s3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.rPill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppTokens.wellFill,
                    ),
                  ),
                  const SizedBox(height: AppTokens.s2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          // The last phases are single steps, so a counter would
                          // only ever read "1 of 1".
                          total <= 1 ? 'Please wait' : '$done of $total',
                          style: AppTokens.rowSubtitle(context),
                        ),
                      ),
                      if (!cancelRequested)
                        TextButton(
                          onPressed: onCancel,
                          style: TextButton.styleFrom(
                            foregroundColor: AppTokens.fgSecondary,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Stop'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the batch actually did, so a partial success is visible rather than
/// silently short.
Future<void> showAppResultsSheet(
  BuildContext context,
  BulkRenameResult result,
) {
  final renamedCount = result.successCount;
  final failures = result.failures;
  final message = switch ((result.stoppedEarly, failures.isEmpty)) {
    (true, true) =>
      'Stopped after $renamedCount songs. Their stats and cached artwork moved '
          'across; the rest were left alone.',
    (true, false) =>
      'Stopped after $renamedCount songs, ${failures.length} could not be '
          'renamed.',
    (false, true) =>
      'Renamed $renamedCount songs. Stats and cached artwork moved across.',
    (false, false) =>
      'Renamed $renamedCount songs, ${failures.length} could not be renamed.',
  };

  // Nothing to report beyond the count, and nothing left on this screen to do.
  if (failures.isEmpty) {
    appSnack(context, message);
    if (context.mounted) Navigator.pop(context);
    return Future.value();
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: 'Rename finished',
      message: message,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: failures.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.s2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failures[index].filename,
                  style: AppTokens.rowTitle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  failures[index].reason,
                  style: AppTokens.rowSubtitle(context)
                      .copyWith(color: AppTokens.danger),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        AppDialogAction(
          label: 'Done',
          isPrimary: true,
          onPressed: () => Navigator.pop(dialogContext),
        ),
      ],
    ),
  );
}
