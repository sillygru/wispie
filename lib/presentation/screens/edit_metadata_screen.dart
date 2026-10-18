import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../../domain/models/online_search_result.dart';
import '../../domain/services/song_replacement_rules.dart';
import '../../l10n/app_localizations.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../services/online_metadata_service.dart';
import '../../services/scanner_service.dart';
import '../components/ambient_scaffold.dart';
import '../widgets/album_art_image.dart';
import '../tokens/app_tokens.dart';
import '../components/app_feedback.dart';
import '../dialogs/lyrics_search_sheet.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';

class EditMetadataScreen extends ConsumerStatefulWidget {
  final Song song;

  const EditMetadataScreen({super.key, required this.song});

  @override
  ConsumerState<EditMetadataScreen> createState() => _EditMetadataScreenState();
}

class _EditMetadataScreenState extends ConsumerState<EditMetadataScreen> {
  late TextEditingController _filenameController;
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  late String _activeFilename;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _activeFilename = widget.song.filename;
    _filenameController = TextEditingController(
        text: p.basenameWithoutExtension(widget.song.filename));
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist);
    _albumController = TextEditingController(text: widget.song.album);
  }

  @override
  void dispose() {
    _filenameController.dispose();
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Song currentSong) async {
    final l10n = AppLocalizations.of(context);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.image,
      );

      final pickedPath = picked?.path;
      if (pickedPath != null) {
        setState(() => _isSaving = true);
        await ref
            .read(songsProvider.notifier)
            .updateSongCover(currentSong, pickedPath);

        if (mounted) {
          appSnack(context, l10n.metadataCoverUpdated);
        }
      }
    } catch (e) {
      if (mounted) {
        appSnack(context, l10n.metadataPickImageError(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeImage(Song currentSong) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.metadataRemoveCoverTitle),
        content: Text(l10n.metadataRemoveCoverBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.backupCancelUpper)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.metadataRemoveUpper)),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await ref
            .read(songsProvider.notifier)
            .updateSongCover(currentSong, null);
        if (mounted) {
          appSnack(context, l10n.metadataCoverRemoved);
        }
      } catch (e) {
        if (mounted) {
          appSnack(context, l10n.metadataRemoveCoverError(e));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _fixThumbnail(Song currentSong) async {
    if (currentSong.coverUrl == null) return;
    final l10n = AppLocalizations.of(context);

    try {
      setState(() => _isSaving = true);

      final fixedOptions = await ref
          .read(fileManagerServiceProvider)
          .getFixedCoverOptions(currentSong);

      if (!mounted) return;

      // Show comparison dialog
      final resultBytes = await showDialog<Uint8List>(
        context: context,
        builder: (context) {
          int selectedIndex = 0;
          bool showAlternatives = false;

          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(l10n.metadataFixResultTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.metadataFixReviewBody),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(l10n.metadataFixOriginal,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: AppTokens.brSm,
                                child: Container(
                                  color: Colors
                                      .black12, // Subtle background to see borders
                                  child: Image.file(
                                    File(currentSong.coverUrl!),
                                    height: 100,
                                    width: 100,
                                    fit: BoxFit
                                        .contain, // Changed from cover to contain to show full image including borders
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: AppIcon(AppIcons.arrowForward),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                  fixedOptions.length > 1
                                      ? l10n.metadataFixNewOption(
                                          selectedIndex + 1)
                                      : l10n.metadataFixNew,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: AppTokens.brSm,
                                child: Container(
                                  color: Colors.black12,
                                  child: Image.memory(
                                    fixedOptions[selectedIndex],
                                    height: 100,
                                    width: 100,
                                    fit: BoxFit.contain, // Consistent scaling
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (fixedOptions.length > 1) ...[
                      const SizedBox(height: 16),
                      if (!showAlternatives)
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => showAlternatives = true),
                          icon: const AppIcon(AppIcons.gridView),
                          label: Text(l10n.metadataFixSeeAlternatives),
                        )
                      else
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: fixedOptions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => selectedIndex = index),
                                child: Container(
                                  padding: const EdgeInsets.all(AppTokens.s1),
                                  decoration: BoxDecoration(
                                    color: index == selectedIndex
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.28)
                                        : Colors.transparent,
                                    borderRadius: AppTokens.brSm,
                                  ),
                                  child: Image.memory(
                                    fixedOptions[index],
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text(l10n.actionCancel),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, fixedOptions[selectedIndex]),
                    child: Text(l10n.metadataFixApply),
                  ),
                ],
              );
            },
          );
        },
      );

      if (resultBytes != null) {
        // We need to save the bytes to a temp file to pass to updateSongCover
        // (Since updateSongCover expects a file path)
        final tempDir = await Directory.systemTemp.createTemp();
        final tempFile = File(p.join(tempDir.path, 'fixed_cover.jpg'));
        await tempFile.writeAsBytes(resultBytes);

        await ref
            .read(songsProvider.notifier)
            .updateSongCover(currentSong, tempFile.path);

        // Clean up temp file
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}

        if (mounted) {
          appSnack(context, l10n.metadataFixSuccess);
        }
      }
    } catch (e) {
      if (mounted) {
        appSnack(context, l10n.metadataFixError(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showFixHelp() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const AppIcon(AppIcons.autoFix),
            const SizedBox(width: 8),
            Text(l10n.metadataFixThumbnail),
          ],
        ),
        content: Text(l10n.metadataFixHelpBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.metadataGotIt),
          ),
        ],
      ),
    );
  }

  Future<void> _exportImage(Song currentSong) async {
    if (currentSong.coverUrl == null) return;
    final l10n = AppLocalizations.of(context);

    try {
      setState(() => _isSaving = true);

      // Get bytes first to satisfy file_picker requirement on Android/iOS
      final bytes = await ref
          .read(fileManagerServiceProvider)
          .getCoverExportBytes(currentSong);

      final savedUri = await FilePicker.saveFile(
        dialogTitle: l10n.metadataExportCover,
        fileName:
            '${p.basenameWithoutExtension(currentSong.filename)}_cover.jpg',
        type: FileType.image,
        bytes: bytes,
      );

      if (savedUri != null) {
        // file_picker persists [bytes] itself on every platform.
        if (mounted) {
          appSnack(context, l10n.metadataExportSuccess(savedUri));
        }
      }
    } catch (e) {
      if (mounted) {
        appSnack(context, l10n.metadataExportError(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showReplaceHelp() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const AppIcon(AppIcons.swapHoriz),
            const SizedBox(width: 8),
            Text(l10n.metadataReplaceSong),
          ],
        ),
        content: Text(l10n.metadataReplaceHelpBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.metadataGotIt),
          ),
        ],
      ),
    );
  }

  Future<void> _replaceSong(Song currentSong) async {
    final l10n = AppLocalizations.of(context);
    final picked = await FilePicker.pickFile();
    final pickedPath = picked?.path;
    if (pickedPath == null || pickedPath.isEmpty || !mounted) return;

    final check = await _checkReplacement(currentSong, pickedPath);
    if (!mounted) return;

    final ReplacementAccepted accepted;
    switch (check) {
      case ReplacementRejected rejected:
        appSnack(context, rejected.reason, tone: AppTone.warning);
        return;
      case ReplacementAccepted ok:
        accepted = ok;
    }

    final disposition = await _askOriginalDisposition(currentSong, accepted);
    if (disposition == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final replaced = await ref.read(songsProvider.notifier).replaceSongFile(
            currentSong,
            accepted,
            disposition: disposition,
          );

      if (!mounted) return;
      // The screen resolves its song by filename, so it has to follow the
      // replacement to its new identity — along with the fields showing what
      // the new file turned out to say about itself.
      setState(() {
        _activeFilename = replaced.filename;
        _filenameController.text =
            p.basenameWithoutExtension(replaced.filename);
        _titleController.text = replaced.title;
        _artistController.text = replaced.artist;
        _albumController.text = replaced.album;
      });

      appSnack(context, l10n.metadataReplaced(replaced.filename),
          tone: AppTone.success);
    } catch (e) {
      // A UI boundary, so this reports anything rather than letting a
      // filesystem or database failure escape as a crash.
      if (mounted) {
        appSnack(context, l10n.metadataReplaceError(e), tone: AppTone.danger);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<ReplacementCheck> _checkReplacement(
      Song song, String sourcePath) async {
    final folders = await ref.read(storageServiceProvider).getMusicFolders();
    final library = ref.read(songsProvider).asData?.value ?? const <Song>[];

    return SongReplacementRules.check(
      original: song,
      sourcePath: sourcePath,
      isSupportedMediaFile: ScannerService.isSupportedMediaPath(sourcePath),
      trackedFolders: folders.map((folder) => folder['path'] ?? ''),
      libraryFilenames: library.map((s) => s.filename),
      destinationExists:
          File(SongReplacementRules.destinationFor(song, sourcePath))
              .existsSync(),
    );
  }

  Future<OriginalFileDisposition?> _askOriginalDisposition(
      Song song, ReplacementAccepted accepted) {
    final l10n = AppLocalizations.of(context);
    return showDialog<OriginalFileDisposition>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.metadataReplaceSong),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.metadataReplaceFilesBody(
                song.filename, accepted.newFilename)),
            const SizedBox(height: 24),
            Text(l10n.metadataReplaceOriginalQuestion),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.backupCancelUpper),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, OriginalFileDisposition.hide),
            child: Text(l10n.metadataKeepHideUpper),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, OriginalFileDisposition.delete),
            style: TextButton.styleFrom(foregroundColor: AppTokens.danger),
            child: Text(l10n.metadataDeleteItUpper),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isSaving = true);

    try {
      final newFilename = _filenameController.text.trim();
      final newTitle = _titleController.text.trim();
      final newArtist = _artistController.text.trim();
      final newAlbum = _albumController.text.trim();

      // 1. Handle Filename Rename if changed. The renamed song is carried
      //    forward: the metadata write below addresses the file by path, and
      //    the old one no longer exists.
      final songsList = ref.read(songsProvider).asData?.value ?? [];
      var song = songsList.firstWhere(
        (s) => s.filename == _activeFilename,
        orElse: () => widget.song,
      );
      if (newFilename != p.basenameWithoutExtension(song.filename)) {
        song = await ref.read(songsProvider.notifier).renameSong(
              song,
              newFilename,
            );
        if (mounted) {
          setState(() {
            _activeFilename = song.filename;
          });
        }
      }

      // 2. Handle Metadata update
      if (newTitle != song.title ||
          newArtist != song.artist ||
          newAlbum != song.album) {
        await ref
            .read(songsProvider.notifier)
            .updateSongMetadata(song, newTitle, newArtist, newAlbum);
      }

      if (mounted) {
        Navigator.pop(context);
        appSnack(context, l10n.metadataSaved);
      }
    } catch (e) {
      if (mounted) {
        appSnack(context, l10n.metadataSaveError(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _fetchCoverOnline(Song currentSong) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isSaving = true);
    try {
      final results =
          await OnlineMetadataService.instance.searchParallelForSong(
        currentSong,
        titleOverride: _titleController.text,
        artistOverride: _artistController.text,
      );

      final coverResults = results
          .where((r) => r.coverUrl != null && r.coverUrl!.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (coverResults.isEmpty) {
        appSnack(context, l10n.metadataNoOnlineCover);
        return;
      }

      final chosen = await showDialog<OnlineSearchResult>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.metadataSelectCoverTitle),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: ListView.builder(
              itemCount: coverResults.length,
              itemBuilder: (context, index) {
                final item = coverResults[index];
                return ListTile(
                  leading: Image.network(
                    item.coverUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const AppIcon(AppIcons.image),
                  ),
                  title: Text(
                      l10n.metadataResultTitleArtist(item.title, item.artist)),
                  subtitle: Text(l10n.metadataSourceLabel(item.source)),
                  onTap: () => Navigator.pop(dialogContext, item),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: Text(l10n.actionCancel),
            ),
          ],
        ),
      );

      if (chosen == null || chosen.coverUrl == null) return;

      setState(() => _isSaving = true);
      final localPath =
          await OnlineMetadataService.instance.downloadAndCacheCover(
        chosen.coverUrl!,
        currentSong.filename,
      );
      if (localPath != null && mounted) {
        await ref
            .read(songsProvider.notifier)
            .updateSongCover(currentSong, localPath);
        if (mounted) {
          appSnack(context, l10n.metadataCoverUpdatedFrom(chosen.source));
        }
      }
    } catch (e) {
      if (mounted) appSnack(context, l10n.coverFetchError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _fetchMetadataOnline(Song currentSong) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isSaving = true);
    try {
      final results =
          await OnlineMetadataService.instance.searchParallelForSong(
        currentSong,
        titleOverride: _titleController.text,
        artistOverride: _artistController.text,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (results.isEmpty) {
        appSnack(context, l10n.metadataNoOnlineMatch);
        return;
      }

      final chosen = await showDialog<OnlineSearchResult>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.metadataSelectMatchTitle),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final item = results[index];
                return ListTile(
                  leading: item.coverUrl != null
                      ? Image.network(
                          item.coverUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const AppIcon(AppIcons.musicNote),
                        )
                      : const AppIcon(AppIcons.musicNote),
                  title: Text(item.title),
                  subtitle: Text(l10n.metadataResultDetail(
                      item.artist, item.album, item.source)),
                  onTap: () => Navigator.pop(dialogContext, item),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: Text(l10n.actionCancel),
            ),
          ],
        ),
      );

      if (chosen == null) return;

      setState(() {
        _titleController.text = chosen.title;
        _artistController.text = chosen.artist;
        _albumController.text = chosen.album;
      });

      if (chosen.coverUrl != null && chosen.coverUrl!.isNotEmpty) {
        setState(() => _isSaving = true);
        final localPath =
            await OnlineMetadataService.instance.downloadAndCacheCover(
          chosen.coverUrl!,
          currentSong.filename,
        );
        if (localPath != null && mounted) {
          await ref
              .read(songsProvider.notifier)
              .updateSongCover(currentSong, localPath);
        }
      }

      if (mounted) {
        appSnack(context, l10n.metadataLoadedFrom(chosen.source));
      }
    } catch (e) {
      if (mounted) {
        appSnack(context, l10n.metadataFetchError(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Watch for updates to the song
    final songs = ref.watch(songsProvider).asData?.value ?? [];
    final currentSong = songs.firstWhere(
      (s) => s.filename == _activeFilename,
      orElse: () => widget.song,
    );

    return AmbientScaffold(
      appBar: AppBar(
        title: Text(l10n.songMenuEditMetadata),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(l10n.metadataSaveUpper,
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.metadataSectionCover),
            const SizedBox(height: 16),
            Row(
              children: [
                ClipRRect(
                  borderRadius: AppTokens.brSm,
                  child: AlbumArtImage(
                    url: currentSong.coverUrl ?? '',
                    cacheVersion: currentSong.mtime,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _pickImage(currentSong),
                        icon: const AppIcon(AppIcons.image),
                        label: Text(l10n.metadataChangeCover),
                        style: AppTokens.tonalButton,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => _fetchCoverOnline(currentSong),
                        icon: const AppIcon(AppIcons.travelExplore),
                        label: Text(l10n.songListFetchCover),
                        style: AppTokens.tonalButton,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: currentSong.coverUrl == null
                                  ? null
                                  : () => _fixThumbnail(currentSong),
                              icon: const AppIcon(AppIcons.autoFix),
                              label: Text(l10n.metadataFixThumbnail),
                              style: AppTokens.tonalButton,
                            ),
                          ),
                          IconButton(
                            onPressed: _showFixHelp,
                            icon: const AppIcon(AppIcons.help),
                            tooltip: l10n.metadataWhatDoesThisDo,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: currentSong.coverUrl == null
                                  ? null
                                  : () => _exportImage(currentSong),
                              icon: const AppIcon(AppIcons.download),
                              label: Text(l10n.metadataExport),
                              style: AppTokens.tonalButton,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: currentSong.coverUrl == null
                                  ? null
                                  : () => _removeImage(currentSong),
                              icon: const AppIcon(AppIcons.delete),
                              label: Text(l10n.queueActionRemove),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTokens.surface(2),
                                foregroundColor: AppTokens.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(l10n.metadataSectionFile),
            const SizedBox(height: 8),
            TextField(
              controller: _filenameController,
              decoration: InputDecoration(
                labelText: l10n.metadataFilenameLabel,
                border: const OutlineInputBorder(),
                helperText: l10n.metadataFilenameHelper,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _isSaving ? null : () => _replaceSong(currentSong),
                    icon: const AppIcon(AppIcons.swapHoriz),
                    label: Text(l10n.metadataReplaceSong),
                    style: AppTokens.tonalButton,
                  ),
                ),
                IconButton(
                  onPressed: _showReplaceHelp,
                  icon: const AppIcon(AppIcons.help),
                  tooltip: l10n.metadataWhatDoesThisDo,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle(l10n.metadataSectionSong),
                TextButton.icon(
                  onPressed: () => _fetchMetadataOnline(currentSong),
                  icon: const AppIcon(AppIcons.travelExplore, size: 16),
                  label: Text(l10n.metadataFetchOnline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.metadataTitleLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _artistController,
              decoration: InputDecoration(
                labelText: l10n.metadataArtistLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _albumController,
              decoration: InputDecoration(
                labelText: l10n.metadataAlbumLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle(l10n.metadataSectionExtra),
            const SizedBox(height: 8),
            ListTile(
              leading: const AppIcon(AppIcons.lyrics),
              title: Text(l10n.metadataEditLyrics),
              subtitle: Text(l10n.metadataEditLyricsSubtitle),
              trailing: const AppIcon(AppIcons.chevronRight),
              shape: RoundedRectangleBorder(
                borderRadius: AppTokens.brSm,
                side: BorderSide(color: AppTokens.fgTertiary),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LyricsEditorScreen(song: widget.song),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.2,
      ),
    );
  }
}

class LyricsEditorScreen extends ConsumerStatefulWidget {
  final Song song;

  const LyricsEditorScreen({super.key, required this.song});

  @override
  ConsumerState<LyricsEditorScreen> createState() => _LyricsEditorScreenState();
}

class _LyricsEditorScreenState extends ConsumerState<LyricsEditorScreen> {
  late TextEditingController _controller;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadLyrics();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    try {
      final repo = ref.read(songRepositoryProvider);
      final songs = ref.read(songsProvider).asData?.value ?? const <Song>[];
      final currentSong = songs.firstWhere(
        (s) => s.filename == widget.song.filename,
        orElse: () => widget.song,
      );
      final content = await repo.getLyrics(currentSong);
      if (mounted) {
        setState(() {
          _controller.text = content ?? "";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        appSnack(
            context, AppLocalizations.of(context).metadataLyricsLoadError(e));
      }
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isSaving = true);
    try {
      final songs = ref.read(songsProvider).asData?.value ?? const <Song>[];
      final currentSong = songs.firstWhere(
        (s) => s.filename == widget.song.filename,
        orElse: () => widget.song,
      );
      await ref
          .read(songsProvider.notifier)
          .updateLyrics(currentSong, _controller.text);
      if (mounted) {
        Navigator.pop(context);
        appSnack(context, l10n.metadataLyricsSaved);
      }
    } catch (e) {
      if (mounted) {
        appSnack(context, l10n.metadataLyricsSaveError(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Drops a lyrics sheet from LRCLIB into the editor without saving, so it can
  /// be corrected or retimed before it touches the file.
  Future<void> _searchOnline() async {
    final chosen = await showLyricsSearchSheet(context, song: widget.song);
    if (chosen == null || !mounted) return;

    setState(() => _controller.text = chosen);
    appSnack(context, AppLocalizations.of(context).metadataLyricsLoaded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AmbientScaffold(
      appBar: AppBar(
        title: Text(l10n.metadataEditLyrics),
        actions: [
          IconButton(
            icon: const AppIcon(AppIcons.travelExplore),
            tooltip: l10n.metadataSearchOnline,
            onPressed: _isSaving ? null : _searchOnline,
          ),
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(l10n.metadataSaveUpper,
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    l10n.metadataLyricsHint,
                    style: const TextStyle(
                        fontSize: 12, color: AppTokens.fgTertiary),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: l10n.metadataLyricsFieldHint,
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
