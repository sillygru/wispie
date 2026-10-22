import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/permission_service.dart';
import '../../services/storage_service.dart';
import '../components/app_feedback.dart';
import '../components/app_list_row.dart';
import '../components/app_screen_header.dart';
import '../components/app_surface.dart';
import '../tokens/app_tokens.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';
import '../../l10n/l10n.dart';

class FolderManagementScreen extends ConsumerStatefulWidget {
  const FolderManagementScreen({super.key});

  @override
  ConsumerState<FolderManagementScreen> createState() =>
      _FolderManagementScreenState();
}

class _FolderManagementScreenState extends ConsumerState<FolderManagementScreen>
    with WidgetsBindingObserver {
  List<Map<String, String>> _folders = [];
  bool _isLoading = true;

  /// Null when all-files access does not apply to this platform or API level.
  bool? _allFilesGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFolders();
    _refreshAllFilesAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAllFilesAccess();
  }

  Future<void> _refreshAllFilesAccess() async {
    final granted = await PermissionService.instance.hasAllFilesAccess();
    if (!mounted) return;
    setState(() => _allFilesGranted = granted);
  }

  Future<void> _requestAllFilesAccess() async {
    await PermissionService.instance.requestAllFilesAccess();
    await _refreshAllFilesAccess();
  }

  Widget _buildAllFilesCard(BuildContext context) {
    final l10n = context.l10n;
    final granted = _allFilesGranted == true;
    final accent = AppTokens.accentOf(context, ref);
    final tone = granted ? accent : AppTokens.warning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s5,
        0,
        AppTokens.s5,
        AppTokens.s3,
      ),
      child: AppSurface(
        accentTint: tone,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AppIcon(
                granted ? AppIcons.checkCircle : AppIcons.warning,
                color: tone,
              ),
            ),
            const SizedBox(width: AppTokens.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    granted
                        ? l10n.foldersAllFilesGrantedTitle
                        : l10n.foldersAllFilesMissingTitle,
                    style: AppTokens.rowTitle(context),
                  ),
                  const SizedBox(height: AppTokens.s1),
                  Text(
                    granted
                        ? l10n.foldersAllFilesGrantedSubtitle
                        : l10n.foldersAllFilesMissingSubtitle,
                    style: AppTokens.rowSubtitle(context),
                  ),
                  if (!granted) ...[
                    const SizedBox(height: AppTokens.s3),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _requestAllFilesAccess,
                        icon: const AppIcon(AppIcons.folder),
                        label: Text(l10n.foldersAllFilesAllowButton),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadFolders() async {
    final storage = ref.read(storageServiceProvider);
    final folders = await storage.getMusicFolders();
    setState(() {
      _folders = folders;
      _isLoading = false;
    });
  }

  Future<void> _addFolder() async {
    final storage = ref.read(storageServiceProvider);
    final Map<String, String>? selection;
    try {
      selection = await storage.pickMusicFolder(context);
    } on FolderPickerUnavailable catch (e) {
      if (mounted) appSnack(context, e.userFacingHint);
      return;
    }
    // Null means the user cancelled the native dialog — stay silent.
    if (selection == null) return;
    final selectedPath = selection['path'] ?? '';
    if (selectedPath.isEmpty) {
      if (mounted) {
        appSnack(context, context.l10n.setupUnableToAccessFolder);
      }
      return;
    }
    await storage.addMusicFolder(
      selectedPath,
      selection['treeUri'],
      iosBookmarkId: selection['iosBookmarkId'],
      platform: selection['platform'],
    );

    await _loadFolders();
    ref.invalidate(musicFoldersProvider);
    ref.invalidate(songsProvider);

    if (mounted) {
      appSnack(context, context.l10n.foldersAddedSnack);
    }
  }

  Future<void> _removeFolder(Map<String, String> folder) async {
    final storage = ref.read(storageServiceProvider);
    await storage.removeMusicFolder(
      folder['path'] ?? '',
      iosBookmarkId: folder['iosBookmarkId'],
    );

    await _loadFolders();
    ref.invalidate(musicFoldersProvider);
    ref.invalidate(songsProvider);

    if (mounted) {
      appSnack(context, context.l10n.foldersRemovedSnack);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AmbientScaffold(
      appBar: AppTopBar(title: context.l10n.settingsSearchMusicFoldersTitle),
      body: _isLoading
          ? const AppLoading()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.s5,
                    AppTokens.s3,
                    AppTokens.s5,
                    AppTokens.s3,
                  ),
                  child: Text(
                    context.l10n.foldersSubtitle,
                    style: AppTokens.rowSubtitle(context),
                  ),
                ),
                if (_allFilesGranted != null) _buildAllFilesCard(context),
                Expanded(
                  child: _folders.isEmpty
                      ? AppEmptyState(
                          icon: AppIcons.folder,
                          title: context.l10n.foldersEmptyTitle,
                          message: context.l10n.foldersEmptyMessage,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.s3,
                          ),
                          itemCount: _folders.length,
                          itemBuilder: (context, index) {
                            final folder = _folders[index];
                            final path = folder['path'] ?? '';
                            final name = p.basename(path);

                            return AppListRow(
                              leading: AppRowIcon(
                                icon: AppIcons.folder,
                                color: AppTokens.accentOf(context, ref),
                              ),
                              title: name,
                              subtitle: path,
                              trailing: IconButton(
                                icon: const AppIcon(AppIcons.delete),
                                tooltip: context.l10n.setupRemoveFolderTooltip,
                                onPressed: () => _removeFolder(folder),
                              ),
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
                        onPressed: _addFolder,
                        icon: const AppIcon(AppIcons.add),
                        label: Text(context.l10n.foldersAddButton),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
