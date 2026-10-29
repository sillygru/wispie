# Agent Documentation - wispie Music Player

Local-first Flutter music player (plus a YouTube Music front end). Riverpod 3, `just_audio`, two SQLite files, MVVM/Repository.

## Critical Rules

- **No git write commands.** NEVER run `git checkout`, `git reset`, `git revert`, `git clean`, or any file/branch-discarding operation. Parallel agents work on different files at the same time and destructive git ops destroy their work. Read-only git (`git status`, `git diff`, `git log`) is fine.
- **No building.** Do not run `flutter build` or `flutter run` unless explicitly requested.
- **No emojis** in code, comments, or messages.
- **No hardcoded user-facing strings.** Every string shown to the user (labels, titles, tooltips, messages, dialogs, semantics labels) must be added to `lib/l10n/app_en.arb` and read through the generated localizations, never inlined in widgets or services. This applies to every new feature and any UI change you touch.
- **English ARB only.** Add and edit strings in `lib/l10n/app_en.arb` only (the `template-arb-file` in `l10n.yaml`). Leave every other `lib/l10n/app_*.arb` file alone unless the user asks for that locale. Enumerate the current ARB files instead of assuming a fixed locale list.
- **Write in the user's language.** If the user is writing in a non-English language, also add the new keys to that language's ARB file, translated into it. If no file for it exists yet, that is the one deliberate case for adding a locale: start `lib/l10n/app_<tag>.arb` from `app_en.arb` with matching keys plus its own `languageNativeName` (nothing else needs wiring; the generated locale list picks it up). Keys stay identical to the template and the template stays English. Only do this for languages the user actually speaks or asks for.
- **`filename` is the primary key for all user data.** Never change this (see Architecture).
- **Comments**: minimal, explain _why_ not _what_. No "// added this" style comments. Keep them short and concise: one or two lines, never a wall of text or a paragraph restating the code.
- **Before finishing any code change:** `dart format .` then `flutter analyze --no-pub`, both clean.

## Testing Policy

NEVER write unit tests after you write code.

- Highly prefer E2E tests as the sole testing mechanism. Use them to verify complex features work. At the end of E2E tests, produce a verifiable and repeatable artifact.
- If you must test a system in isolation, FIRST write all the ways it could fail, THEN write the code.

There are no unit tests in this repo. Do not add `test/` files, `*_test.dart`, or Go `_test.go` files. Verify by running the app end to end and leaving a repeatable artifact.

The artifacts that exist today are the probes in `tool/` (`search_probe.dart`, `taste_probe.dart`, `lyrics_probe.dart`, `lyrics_activity_probe.dart`, `batch_replace_probe.dart`, `panel_probe.dart`, `youtube_probe.dart`, `youtube_account_probe.dart`, `youtube_music_probe.dart`). Each runs with `dart run tool/<name>.dart`, prints one line per check, writes its result under `build/`, and exits non-zero on regression. Extend the nearest probe instead of adding a test file.

## Verification

CI (`.github/workflows/flutter_tests.yml`; `.github/workflows/server_tests.yml` runs the Go server's checks) gates on, in this order:

```bash
dart format --set-exit-if-changed .   # runs on third_party/ too (~400 files incl. build/)
flutter analyze                       # analysis_options.yaml excludes third_party + platform dirs
```

Note the local Flutter is 3.47.2 while the analyze workflow pins 3.44.2 and the build workflow pins 3.47.2.

`dart format .` walks `build/` (gitignored) and can warn about package resolution there; harmless. `build_runner` is a dev dependency but no `.g.dart` files exist and nothing invokes it. Don't run it.

Editing an ARB file is only half the change: run `flutter gen-l10n` afterwards. The generated `lib/l10n/app_localizations*.dart` are committed, so the ARB plus its regenerated files belong in the same commit, and `flutter analyze` fails on a key that was added but never generated.

## Architecture

### Two generations of layout (mid-migration)

Legacy: `lib/models/`, `lib/services/`, `lib/providers/`, `lib/theme/`. Newer: `lib/data/`, `lib/domain/`, `lib/presentation/`. Prefer the newer layers for new code, but don't bulk-relocate existing files as a side effect of unrelated work. `lib/domain/services/` holds the pure, Flutter-free logic the `tool/` probes can exercise without a UI.

### `filename` is the primary key for user data

Every user-data table (`favorite`, `suggestless`, `hidden`, `playlist_song`, `merged_song`, `recommendation_*`, `cover_miss`) keys on the song's **filename**, not a path or synthetic id. Renaming a file outside the app orphans its stats. Merged songs map several filenames to one group id (`AudioPlayerManager._getMergedSiblings`).

### Databases

`DatabaseService` (`lib/services/database_service.dart`, `.instance`) owns `wispie_stats.db` (play sessions/events) and `wispie_data.db` (library, playlists, favorites, merged groups, queue snapshots).

Schema is canonical in `lib/data/migrations.dart` only: `_userDataTableStmts` / `_createUserDataIndexes` for fresh creates, plus explicit `upgradeUserDataFromNToM` steps wired into `DatabaseService._initAsync`'s `onUpgrade`. Versions are `kStatsDbVersion` / `kUserDataDbVersion`. Adding a table or column means touching both the create path and the upgrade path.

### Playback

`AudioPlayerManager` (~3900 lines) wraps `just_audio` + `just_audio_background`, owns queue/shuffle/crossfade/volume/stats. Hot-path state is exposed via `ValueNotifier`s rather than Riverpod, deliberately, to keep rebuilds narrow — don't convert those to providers. Queue mutations serialize through `_queueMutationChain`; keep new queue mutations on that chain.

Linux/Windows swap in `just_audio_media_kit` + `sqflite_common_ffi` (see the `isMediaKitDesktop` branch in `main.dart`); they have no `audio_session`/`audio_service` implementation.

### Shuffle

`lib/domain/services/shuffle_selector.dart` — pure `scoreCandidate(...)`; `smart_weights.dart` turns the smart model into `ShuffleWeights` that apply as multiplicative penalties/boosts. Smart is the only mode: the personality picker and its legacy options are gone, and `ShuffleConfig.fromJson` simply ignores their saved keys. The Familiar to Discover slider (`ShuffleConfig.discoveryLevel`) is the only user-facing knob.

### State management

Riverpod 3 `Notifier`/`AsyncNotifier`. `lib/providers/providers.dart` (~2200 lines) is the hub. Derived data belongs in a `Provider` over `songsProvider` + `userDataProvider`, not a duplicated cache.

### Library scanning

`ScannerService` runs in isolates (`Isolate.spawn` / `Isolate.run`), lazy: a fast scan writes minimal rows, then metadata enrichment and cover extraction in throttled batches. `lib/domain/services/media_formats.dart` is the one list of playable extensions — the scanner, the storage probe and the folder reader all ask it. Video thumbnails go through `FFmpegService`, which is platform-channel and main-thread only. `MediaDecodePriority` (`lib/services/media_decode_gate.dart`) serializes full-file decodes — waveform and beat analysis must not run concurrently on one file.

### Networking

`SharedHttpClient.instance` is the one pooled `HttpClient` for outbound requests. Don't construct per-request clients; that's the regression its comment describes. Secrets arrive via `--dart-define`: `TELEMETRY_SECRET` (plus `WISPIE_MUSIC_UTILS_BASE_URL` for the music API).

The YouTube account has no OAuth client and no API quota: it signs InnerTube requests with the user's own web-session cookies (`SAPISIDHASH` over `SAPISID`, `lib/domain/services/youtube_session.dart`). Sign-in is a WebView on Google's own page (`flutter_inappwebview`), which reads the HttpOnly cookies from the platform store that no JavaScript could see. Google blocks its login form in embedded browsers on some platforms — on macOS it answers "this browser or app may not be secure" almost every time — and Linux has no WebView plugin, so importing a `Cookie` header, `cookies.txt` or cookie JSON is the path that always works; the screen detects the block page and offers the import directly. The WebView UA must match its engine (Safari UA on Apple platforms, Chrome-family on Chromium), because a Chrome UA over WebKit is itself a block signal. `flutter_inappwebview` is CocoaPods-only on macOS, so that platform runs Flutter's mixed mode: `macos/Podfile` stays committed next to the Swift Packages, and `.github/workflows/build.yml` installs the pods before building. Cookies live in secure storage, never in settings, and are dropped on sign-out along with the WebView jar. Response shape is parsed by walking the JSON, not by hardcoding containers, because YouTube reshuffles them; `tool/youtube_account_probe.dart` exercises all of it.

The same client also reads the **catalogue**, not just the account: `musicSearchAll` keeps the album, playlist and artist rows a search page returns (browse ids starting `MPRE`, `VL`, `UC`), `album()` and `artist()` browse one of them, and an artist page's own sort chips (`parseMusicSortOptions`, which matches any `*sortFilterButton*` node and keeps its label) are sent back as `params`, so most-popular and release-date ordering come from YouTube instead of being guessed out of bylines. `OnlineMusicService` maps all of it to `OnlineTrack` / `OnlineCollection`, which is what the online tab, `youtube_collection_screen.dart` and `youtube_artist_screen.dart` draw. `tool/youtube_music_probe.dart` covers the container, artist and album parsing.

Data policy that is easy to regress: catalogue rows ask for a 320-wide still (`upscaleThumbnailUrl(url, size: 320)`), and `CoverPath.renditionUrl` then picks the rendition the drawing box actually needs in *both* directions — a 52dp tile never downloads a 480px or 1280px still, a full-size cover still upgrades. Don't reintroduce a 720 default in a parser. `PassiveArtFetcherService` caps a passive art sweep at 80 keys per launch (an explicit fetch stays uncapped), so a first open over a large library is not hundreds of image downloads. Streamed audio fills `OnlineAudioCache` once, so replaying a track costs no network.

## Settings invariants

Adding a settings key means editing `StorageService._settingsKeys` **and** claiming it in `importableSettingsKeys` or `identitySettingsKeys`. Adding a searchable settings row means a `SettingsDestination` in `lib/presentation/screens/settings_registry.dart` plus a matching `searchId:` in the screen.

## UI / Design Standard

- Vibrant color blocking; high-contrast solid fills in large blocks.
- No borders or outlines for separation. Use color blocking, whitespace, layout geometry.
- No gradients for chrome, fills, or text. Gradients are allowed only for cover-art-derived backdrops, legibility scrims, and edge fades (`lib/presentation/cover_gradient/`, `app_screen_header`'s scroll scrim, `components/progressive_edge_fade.dart`).
- Design tokens first: never hardcode hex or pixel sizes. `lib/presentation/tokens/player_tokens.dart` is the source of truth for spacing/radii/motion; `app_tokens.dart` aliases it and adds foreground/status colors; `app_icons.dart` holds icons. Reach for the shared components in `lib/presentation/components/` (`app_surface`, `app_list_row`, `app_chip`, `app_dialog`, `app_sheet`, `app_feedback`) instead of hand-rolling a row or dialog.
- Motion: deliberate, token-driven durations and curves (`AppTokens.cStandard`, `dFast`, …). `MotionPolicy.of(context)` is the one read for reduced motion; duration tokens live in `PlayerTokens`/`MotionTokens`.
- Feedback and scroll chrome are shared, not per screen: `appSnack(...)`/`AppToasts` is the only snackbar path, and `MotionScrollBehavior` (`lib/presentation/motion/motion_physics.dart`) wraps every scrollable in `AppScrollbar`. Don't hand-roll a `showSnackBar` or a `Scrollbar`.
- Semantic widgets (`ListTile`, `IconButton`), proper labels, managed focus.
- `UnifiedPlayerScreen` is a shell around three panes (`lib/presentation/screens/player/`: lyrics / now-playing / queue). Keep chrome out of the panes.

Before returning UI code: no borders used for separation, no gradients outside the allowed cases, all styling from tokens, animations deliberate.

## Release

`git tag v2.4.0-release && git push origin v2.4.0-release` (the version in `pubspec.yaml`) triggers `release-draft.yml`, which reuses a successful `ci-builds.yml` run for the tagged commit when possible and otherwise builds all eight release assets (Android arm64 + armv7, Linux x86_64 AppImage, unsigned iOS IPA, macOS arm64 + x64, Windows portable + setup), then creates a **private draft** release for manual review. Artifact names and order in the workflows are load-bearing; the comments say so. macOS builds require `packaging/macos/patch_darwin_headers.sh` and `prepare_spm_artifacts.sh` to run first.

## Quick Reference

| Concern | File |
| --- | --- |
| Playback | `lib/services/audio_player_manager.dart` |
| Library state | `lib/providers/providers.dart` -> `songsProvider` |
| User data | `lib/providers/user_data_provider.dart` |
| Schema + migrations | `lib/data/migrations.dart` |
| Database access | `lib/services/database_service.dart` |
| Search | `lib/domain/services/search_service.dart` |
| Library logic | `lib/services/library_logic.dart` |
| Scanning | `lib/services/scanner_service.dart` |
| Shuffle | `lib/domain/services/shuffle_selector.dart` |
| Player UI shell | `lib/presentation/screens/unified_player_screen.dart` |
| YouTube catalogue (search, album, artist) | `lib/domain/services/youtube_library.dart` |
| YouTube playback resolution | `lib/services/youtube_service.dart` |
| Online catalogue -> UI models | `lib/services/online_music_service.dart` |
| Online tab | `lib/presentation/screens/online_screen.dart` |
| Album / playlist / artist screens | `lib/presentation/screens/youtube_collection_screen.dart`, `youtube_artist_screen.dart` |
| Settings registry | `lib/presentation/screens/settings_registry.dart` |
| Repeatable probes | `tool/*_probe.dart` |
| Shared components | `lib/presentation/components/` |
| Design tokens | `lib/presentation/tokens/` |

### Structure

```
lib/
├── main.dart        # entrypoint, platform branch, service init order
├── services/        # legacy layer + platform channels, FFmpeg, scanning
├── providers/       # Riverpod state
├── models/          # core entities (song, playlist, queue item)
├── domain/          # pure logic + value objects (filename)
├── data/            # schema/migrations + repository implementations
└── presentation/    # screens/ (player/ subdir), widgets/, components/, tokens/, routes/
server/              # self-hostable Go sync server (stores opaque encrypted blobs)
tool/                # repeatable probes + icon generator
third_party/         # vendored deps, wired via dependency_overrides
```
