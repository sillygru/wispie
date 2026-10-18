import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/app_screen_header.dart';
import '../routes/app_page_route.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../../l10n/l10n.dart';

/// Full-screen file system directory picker for choosing music folders.
class InAppFolderPicker extends StatefulWidget {
  final String? initialPath;

  const InAppFolderPicker({
    super.key,
    this.initialPath,
  });

  @override
  State<InAppFolderPicker> createState() => _InAppFolderPickerState();
}

class _InAppFolderPickerState extends State<InAppFolderPicker> {
  String _currentPath = '';
  List<FileSystemEntity> _subfolders = [];
  bool _isLoading = true;
  String? _accessError;
  final List<Map<String, String>> _shortcuts = [];

  @override
  void initState() {
    super.initState();
    _currentPath =
        widget.initialPath ?? (Platform.isAndroid ? '/storage/emulated/0' : '');
    _initStartingDirectory();
  }

  Future<void> _initStartingDirectory() async {
    String pathCandidate = widget.initialPath ?? '';
    if (pathCandidate.isNotEmpty && Directory(pathCandidate).existsSync()) {
      _currentPath = pathCandidate;
    } else if (Platform.isAndroid) {
      const primaryStorage = '/storage/emulated/0';
      if (Directory(primaryStorage).existsSync()) {
        _currentPath = primaryStorage;
      } else {
        _currentPath = '/storage';
      }
    } else {
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null && Directory(home).existsSync()) {
        _currentPath = home;
      } else {
        final docs = await getApplicationDocumentsDirectory();
        _currentPath = docs.path;
      }
    }

    await _loadShortcuts();
    await _loadSubfolders();
  }

  Future<void> _loadShortcuts() async {
    final l10n = context.l10n;
    final list = <Map<String, String>>[];

    if (Platform.isAndroid) {
      const primary = '/storage/emulated/0';
      if (Directory(primary).existsSync()) {
        list.add(
            {'label': l10n.foldersShortcutInternalStorage, 'path': primary});
        final music = p.join(primary, 'Music');
        if (Directory(music).existsSync()) {
          list.add({'label': l10n.foldersShortcutMusic, 'path': music});
        }
        final download = p.join(primary, 'Download');
        if (Directory(download).existsSync()) {
          list.add({'label': l10n.foldersShortcutDownload, 'path': download});
        }
      }
      if (Directory('/storage').existsSync()) {
        list.add(
            {'label': l10n.foldersShortcutStorageRoot, 'path': '/storage'});
      }
    } else {
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null && Directory(home).existsSync()) {
        list.add({'label': l10n.shellNavHome, 'path': home});
        final music = p.join(home, 'Music');
        if (Directory(music).existsSync()) {
          list.add({'label': l10n.foldersShortcutMusic, 'path': music});
        }
        final download = p.join(home, 'Downloads');
        if (Directory(download).existsSync()) {
          list.add({'label': l10n.foldersShortcutDownloads, 'path': download});
        }
      }
    }

    try {
      final docs = await getApplicationDocumentsDirectory();
      if (Directory(docs.path).existsSync()) {
        list.add({'label': l10n.foldersShortcutDocuments, 'path': docs.path});
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _shortcuts.clear();
        _shortcuts.addAll(list);
      });
    }
  }

  Future<void> _loadSubfolders() async {
    final l10n = context.l10n;
    setState(() {
      _isLoading = true;
      _accessError = null;
    });

    final targetDir = Directory(_currentPath);
    try {
      if (!await targetDir.exists()) {
        setState(() {
          _subfolders = [];
          _isLoading = false;
          _accessError = l10n.foldersDoesNotExist;
        });
        return;
      }

      final List<FileSystemEntity> dirs = [];
      await for (final entity
          in targetDir.list(followLinks: false).handleError((e) {
        debugPrint('Directory listing error: $e');
      })) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          if (!name.startsWith('.')) {
            dirs.add(entity);
          }
        }
      }

      dirs.sort((a, b) => p
          .basename(a.path)
          .toLowerCase()
          .compareTo(p.basename(b.path).toLowerCase()));

      if (mounted) {
        setState(() {
          _subfolders = dirs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _subfolders = [];
          _isLoading = false;
          _accessError = l10n.foldersPermissionError;
        });
      }
    }
  }

  void _navigateTo(String path) {
    if (_currentPath == path) return;
    setState(() {
      _currentPath = path;
    });
    _loadSubfolders();
  }

  void _navigateUp() {
    final parent = p.dirname(_currentPath);
    if (parent != _currentPath) {
      _navigateTo(parent);
    }
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
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.actionCreate),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoUp = p.dirname(_currentPath) != _currentPath;

    return AmbientScaffold(
      appBar: AppTopBar(
        title: context.l10n.homeSelectFolder,
        actions: [
          IconButton(
            icon: const AppIcon(AppIcons.folderAdd),
            tooltip: context.l10n.foldersNewFolderTitle,
            onPressed: () async {
              final name = await _showNewFolderDialog(context);
              if (name != null && name.isNotEmpty) {
                try {
                  final newFolderPath = p.join(_currentPath, name);
                  final newDir = Directory(newFolderPath);
                  if (!await newDir.exists()) {
                    await newDir.create(recursive: true);
                  }
                  _navigateTo(newFolderPath);
                } catch (e) {
                  if (context.mounted) {
                    appSnack(context, context.l10n.foldersCreateError('$e'));
                  }
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_shortcuts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s4,
                vertical: AppTokens.s2,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _shortcuts.map((sc) {
                    final isSelected = sc['path'] == _currentPath;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppTokens.s2),
                      child: ActionChip(
                        label: Text(
                          sc['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainer,
                        onPressed: () => _navigateTo(sc['path']!),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s4,
              vertical: AppTokens.s2,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s3,
                vertical: AppTokens.s3,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: AppTokens.brSm,
              ),
              child: Text(
                _currentPath,
                style: AppTokens.meta(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (canGoUp)
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: AppTokens.s4),
              leading: const AppIcon(AppIcons.arrowUp),
              title: Text(context.l10n.foldersGoUp),
              onTap: _navigateUp,
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _accessError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTokens.s4),
                          child: Text(
                            _accessError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      )
                    : _subfolders.isEmpty
                        ? Center(
                            child: Text(
                              context.l10n.foldersNoSubfolders,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTokens.s2),
                            itemCount: _subfolders.length,
                            itemBuilder: (context, index) {
                              final folder = _subfolders[index];
                              final name = p.basename(folder.path);

                              return ListTile(
                                leading: const AppIcon(AppIcons.folder),
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const AppIcon(AppIcons.chevronRight),
                                onTap: () => _navigateTo(folder.path),
                              );
                            },
                          ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.s4),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context, {
                      'path': _currentPath,
                      'platform': Platform.operatingSystem,
                    });
                  },
                  icon: const AppIcon(AppIcons.tick),
                  label: Text(context.l10n.foldersSelectThisFolder),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Utility function to display the full-screen in-app folder picker.
Future<Map<String, String>?> showInAppFolderPicker(
  BuildContext context, {
  String? initialPath,
}) {
  return Navigator.push<Map<String, String>>(
    context,
    AppPageRoute<Map<String, String>>(
      builder: (context) => InAppFolderPicker(initialPath: initialPath),
    ),
  );
}
