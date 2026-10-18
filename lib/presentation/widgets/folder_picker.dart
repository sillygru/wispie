import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../providers/providers.dart';
import '../../services/library_logic.dart';
import 'collection_cover.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';
import '../../l10n/l10n.dart';

class FolderPicker extends ConsumerStatefulWidget {
  final String rootPath;
  final String? currentRelativePath;

  const FolderPicker({
    super.key,
    required this.rootPath,
    this.currentRelativePath,
  });

  @override
  ConsumerState<FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends ConsumerState<FolderPicker> {
  late String _currentRelativePath;

  @override
  void initState() {
    super.initState();
    _currentRelativePath = widget.currentRelativePath ?? '';
  }

  Future<String?> _showNewFolderDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.foldersNewFolderTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.foldersFolderNameLabel,
            hintText: context.l10n.foldersFolderNameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.actionCreate),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _getMergedFolders(
      String path, List<String> songFolders) async {
    final Set<String> allFolders = {...songFolders};
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        final entities = await dir.list().toList();
        for (var entity in entities) {
          if (entity is Directory) {
            allFolders.add(p.basename(entity.path));
          }
        }
      }
    } catch (e) {
      debugPrint("Error listing directory: $e");
    }
    return allFolders.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsyncValue = ref.watch(songsProvider);

    return AlertDialog(
      title: Text(context.l10n.foldersSelectDestination),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: songsAsyncValue.when(
          data: (allSongs) {
            final currentFullPath = _currentRelativePath.isEmpty
                ? widget.rootPath
                : p.join(widget.rootPath, _currentRelativePath);

            final content = LibraryLogic.getFolderContent(
              allSongs: allSongs,
              currentFullPath: currentFullPath,
            );

            return FutureBuilder<List<String>>(
              future: _getMergedFolders(currentFullPath, content.subFolders),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sortedSubFolders = snapshot.data!;

                return Column(
                  children: [
                    Row(
                      children: [
                        if (_currentRelativePath.isNotEmpty)
                          Expanded(
                            child: ListTile(
                              leading: const AppIcon(AppIcons.arrowBack),
                              title: Text(context.l10n.foldersGoBack),
                              onTap: () {
                                setState(() {
                                  final parts = p.split(_currentRelativePath);
                                  if (parts.length <= 1) {
                                    _currentRelativePath = '';
                                  } else {
                                    _currentRelativePath = p.joinAll(
                                        parts.sublist(0, parts.length - 1));
                                  }
                                });
                              },
                            ),
                          ),
                        IconButton(
                          icon: const AppIcon(AppIcons.folderAdd),
                          tooltip: context.l10n.foldersNewFolderTitle,
                          onPressed: () async {
                            final name = await _showNewFolderDialog(context);
                            if (name != null && name.isNotEmpty) {
                              try {
                                final newFolderPath =
                                    _currentRelativePath.isEmpty
                                        ? p.join(widget.rootPath, name)
                                        : p.join(widget.rootPath,
                                            _currentRelativePath, name);

                                final newDir = Directory(newFolderPath);
                                if (!await newDir.exists()) {
                                  await newDir.create(recursive: true);
                                }

                                // Keep state in sync for scanner refresh.
                                await ref
                                    .read(songsProvider.notifier)
                                    .refresh();

                                setState(() {
                                  _currentRelativePath =
                                      _currentRelativePath.isEmpty
                                          ? name
                                          : p.join(_currentRelativePath, name);
                                });
                              } catch (e) {
                                if (context.mounted) {
                                  appSnack(context,
                                      context.l10n.foldersCreateError('$e'));
                                }
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    Expanded(
                      child: sortedSubFolders.isEmpty
                          ? Center(child: Text(context.l10n.foldersEmptyFolder))
                          : ListView.builder(
                              itemCount: sortedSubFolders.length,
                              itemBuilder: (context, index) {
                                final folderName = sortedSubFolders[index];
                                final folderSongs =
                                    content.subFolderSongs[folderName] ?? [];
                                return ListTile(
                                  leading: CollectionCover(
                                      songs: folderSongs, size: 40),
                                  title: Text(folderName),
                                  onTap: () {
                                    setState(() {
                                      _currentRelativePath =
                                          _currentRelativePath.isEmpty
                                              ? folderName
                                              : p.join(_currentRelativePath,
                                                  folderName);
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        context.l10n.foldersSelected(
                            _currentRelativePath.isEmpty
                                ? context.l10n.foldersRoot
                                : _currentRelativePath),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) =>
              Center(child: Text(context.l10n.songListMergeError('$e'))),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final targetPath = _currentRelativePath.isEmpty
                ? widget.rootPath
                : p.join(widget.rootPath, _currentRelativePath);
            Navigator.pop(context, targetPath);
          },
          child: Text(context.l10n.foldersSelectThisFolder),
        ),
      ],
    );
  }
}

Future<String?> showFolderPicker(BuildContext context, String rootPath,
    {String? currentRelativePath}) {
  return showDialog<String>(
    context: context,
    builder: (context) => FolderPicker(
        rootPath: rootPath, currentRelativePath: currentRelativePath),
  );
}
