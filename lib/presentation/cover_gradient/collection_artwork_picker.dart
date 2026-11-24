import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../components/app_dialog.dart';
import '../components/app_list_row.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../widgets/album_art_image.dart';

class CollectionArtworkPicker extends StatefulWidget {
  final String name;
  final List<Map<String, String>> songCovers;
  final Future<List<Map<String, String>>> Function()? searchOnline;

  const CollectionArtworkPicker({
    super.key,
    required this.name,
    required this.songCovers,
    this.searchOnline,
  });

  @override
  State<CollectionArtworkPicker> createState() =>
      _CollectionArtworkPickerState();
}

class _CollectionArtworkPickerState extends State<CollectionArtworkPicker> {
  late final Future<List<Map<String, String>>>? _onlineCovers;

  @override
  void initState() {
    super.initState();
    final search = widget.searchOnline;
    _onlineCovers = search == null ? null : Future.sync(search);
  }

  Widget _coverRow(Map<String, String> candidate, {required bool online}) {
    final url = candidate['url']!;
    return AppListRow(
      key: ValueKey((online, url)),
      leading: AppRowArt(
        child: AlbumArtImage(
          url: url,
          width: AppTokens.artSize,
          height: AppTokens.artSize,
          errorWidget: const AppRowIcon(icon: AppIcons.image),
        ),
      ),
      title: context.l10n.songListArtworkFrom(candidate['source']!),
      titleMaxLines: 2,
      onTap: () => Navigator.pop(context, url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: l10n.songListSelectArtwork(widget.name),
      scrollable: true,
      content: SizedBox(
        width: AppTokens.popupMaxWidth,
        child: FutureBuilder<List<Map<String, String>>>(
          future: _onlineCovers,
          builder: (context, snapshot) {
            final onlineCovers = snapshot.data ?? const [];
            final status = switch (snapshot.connectionState) {
              ConnectionState.waiting =>
                l10n.songListSearchingArtwork(widget.name),
              ConnectionState.done when onlineCovers.isEmpty =>
                l10n.songListNoOnlineArtwork,
              _ => null,
            };
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.all(AppTokens.s3),
                    child: Semantics(
                      liveRegion: true,
                      child:
                          Text(status, style: AppTokens.rowSubtitle(context)),
                    ),
                  ),
                for (final candidate in onlineCovers)
                  _coverRow(candidate, online: true),
                for (final candidate in widget.songCovers)
                  _coverRow(candidate, online: false),
                AppListRow(
                  leading: const AppRowIcon(
                    icon: AppIcons.musicNote,
                    size: AppTokens.artSize,
                  ),
                  title: l10n.songListUseDefaultArtwork,
                  subtitle: l10n.songListRemoveCustomArtwork,
                  onTap: () => Navigator.pop(context, 'reset'),
                ),
                AppListRow(
                  leading: const AppRowIcon(
                    icon: AppIcons.image,
                    size: AppTokens.artSize,
                  ),
                  title: l10n.songListChooseCustomImage,
                  subtitle: l10n.songListSelectFromDevice,
                  onTap: () => Navigator.pop(context, 'custom'),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        AppDialogAction(
          label: l10n.actionCancel,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
