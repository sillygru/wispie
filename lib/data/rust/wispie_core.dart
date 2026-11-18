import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

/// The native core: library scan, tag reads and the cover cache.
///
/// Required for the library. A build that does not contain the library (a
/// developer who never ran `tool/rust/build.dart`, an unsupported platform)
/// reports [isAvailable] false; the scanner then fails with a clear error
/// instead of silently producing a library by a second implementation.
class WispieCore {
  WispieCore._();

  /// Must match `ABI_VERSION` in `rust/wispie_core/src/lib.rs`.
  static const int abiVersion = 7;

  /// Event kinds sent by the native core.
  static const int eventItems = 0;
  static const int eventProgress = 1;
  static const int eventDone = 2;
  static const int eventError = 3;

  /// Raw bytes instead of JSON, for payloads that must not be transcoded.
  static const int eventBytes = 4;

  static const String _processLibrary = '<process>';

  static bool? _available;
  static String? _reason;
  static _Bindings? _bindings;

  /// Whether the native core is loaded and usable.
  static bool get isAvailable => _ensureLoaded();

  /// Why the native core is unavailable, or null when it is loaded.
  static String? get unavailableReason {
    _ensureLoaded();
    return _available == true ? null : _reason;
  }

  static bool _ensureLoaded() {
    return _available ??= _load();
  }

  static bool _load() {
    if (!Platform.isAndroid &&
        !Platform.isLinux &&
        !Platform.isWindows &&
        !Platform.isMacOS &&
        !Platform.isIOS) {
      _reason = 'unsupported platform ${Platform.operatingSystem}';
      return false;
    }

    for (final candidate in _candidates()) {
      try {
        final library = candidate == _processLibrary
            ? DynamicLibrary.process()
            : DynamicLibrary.open(candidate);
        final bindings = _Bindings(library);
        final version = bindings.abiVersion();
        if (version != abiVersion) {
          _reason = '$candidate reports ABI $version, expected $abiVersion';
          continue;
        }
        _bindings = bindings;
        return true;
      } catch (error) {
        _reason = '$candidate: $error';
      }
    }
    return false;
  }

  static List<String> _candidates() {
    const compiled = String.fromEnvironment('WISPIE_CORE_LIB');
    final overrides = <String>[
      if (compiled.isNotEmpty) compiled,
      if (Platform.environment['WISPIE_CORE_LIB'] case final value?
          when value.isNotEmpty)
        value,
    ];

    final names = <String>[
      if (Platform.isAndroid) 'libwispie_core.so',
      if (Platform.isLinux) 'libwispie_core.so',
      if (Platform.isWindows) 'wispie_core.dll',
      if (Platform.isMacOS || Platform.isIOS) _processLibrary,
    ];

    return [...overrides, ...names];
  }

  /// Runs one request, invoking [onEvent] for every event before returning.
  ///
  /// Must be called on the isolate whose thread should receive the events: the
  /// call is synchronous, so callers run it inside a spawned isolate.
  static int run(
    Map<String, Object?> request, {
    required void Function(int kind, String payload) onEvent,
  }) =>
      _run(request, Uint8List(0), binaryRequest: false, onEvent: onEvent);

  /// Runs a request with a binary payload that must not be JSON-expanded.
  static int runBytes(
    Map<String, Object?> request,
    Uint8List bytes, {
    required void Function(int kind, String payload) onEvent,
    void Function(Uint8List bytes)? onBytes,
  }) =>
      _run(
        request,
        bytes,
        binaryRequest: true,
        onEvent: onEvent,
        onBytes: onBytes,
      );

  static int _run(
    Map<String, Object?> request,
    Uint8List bytes, {
    required bool binaryRequest,
    required void Function(int kind, String payload) onEvent,
    void Function(Uint8List bytes)? onBytes,
  }) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    final bindings = _bindings!;
    final encoded = utf8.encode(jsonEncode(request));
    final length = encoded.length + 1;
    final pointer = bindings.alloc(length);
    if (pointer.address == 0) {
      throw StateError('native core allocation failed');
    }
    final binary = bytes.isEmpty ? nullptr : bindings.alloc(bytes.length);
    if (bytes.isNotEmpty && binary.address == 0) {
      bindings.free(pointer, length);
      throw StateError('native core binary allocation failed');
    }

    try {
      pointer.asTypedList(length)
        ..setAll(0, encoded)
        ..[encoded.length] = 0;
      if (bytes.isNotEmpty) binary.asTypedList(bytes.length).setAll(0, bytes);

      final callable = NativeCallable<_EventNative>.isolateLocal(
        (Pointer<Void> _, int kind, Pointer<Uint8> json, int size) {
          if (kind == eventBytes && onBytes != null) {
            onBytes(Uint8List.fromList(json.asTypedList(size)));
            return;
          }
          onEvent(kind, utf8.decode(json.asTypedList(size)));
        },
      );
      try {
        return !binaryRequest
            ? bindings.run(pointer.cast(), callable.nativeFunction, nullptr)
            : bindings.runBytes(
                pointer.cast(),
                binary,
                bytes.length,
                callable.nativeFunction,
                nullptr,
              );
      } finally {
        callable.close();
      }
    } finally {
      if (bytes.isNotEmpty) bindings.free(binary, bytes.length);
      bindings.free(pointer, length);
    }
  }

  /// Asks a running scan to stop at its next chunk boundary.
  static void cancel() {
    if (_ensureLoaded()) {
      _bindings!.cancel();
    }
  }

  static void hlcObserve(int remote) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    _bindings!.hlcObserve(remote);
  }

  static void hlcSet(int last) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    _bindings!.hlcSet(last);
  }

  static int hlcNext(int wallMillis) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    return _bindings!.hlcNext(wallMillis);
  }

  static int hlcNow() {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    return _bindings!.hlcNow();
  }

  /// Runs one `helpers` request and returns its JSON reply.
  static Map<String, dynamic> helper(
    Map<String, Object?> request, {
    Uint8List? bytes,
  }) {
    Map<String, dynamic>? reply;
    runBytes(
      {...request, 'command': 'helpers'},
      bytes ?? Uint8List(0),
      onEvent: (kind, payload) {
        if (kind == eventItems) {
          reply = jsonDecode(payload) as Map<String, dynamic>;
        }
      },
    );
    if (reply == null) {
      throw StateError('native helper returned nothing: ${request['action']}');
    }
    return reply!;
  }

  static Pointer<Uint8> allocBytes(int length) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    final pointer = _bindings!.alloc(length);
    if (pointer.address == 0 && length != 0) {
      throw StateError('native core allocation failed');
    }
    return pointer;
  }

  static void freeBytes(Pointer<Uint8> pointer, int length) {
    if (pointer.address != 0) _bindings!.free(pointer, length);
  }

  static double playheadEase(double currentMs, double positionMs) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    return _bindings!.playheadEase(currentMs, positionMs);
  }

  static double playheadVisual({
    required double anchorMs,
    required double wallMs,
    required bool playing,
    required double nowMs,
    required double latencyMs,
  }) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    return _bindings!.playheadVisual(
      anchorMs,
      wallMs,
      playing ? 1 : 0,
      nowMs,
      latencyMs,
    );
  }

  static int spectrumTargets({
    required Pointer<Uint8> bands,
    required int bandLength,
    required Pointer<Int32> beats,
    required int beatCount,
    required Pointer<Float> strengths,
    required double bpm,
    required double positionMs,
    required Pointer<Double> out,
  }) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    return _bindings!.spectrumTargets(
      bands,
      bandLength,
      beats,
      beatCount,
      strengths,
      bpm,
      positionMs,
      out,
    );
  }

  static void spectrumFrame({
    required Pointer<Double> levels,
    required Pointer<Double> synced,
    required Pointer<Double> idle,
    required double elapsedSeconds,
    required double dtSeconds,
    required double gridBlend,
    required double pauseBlend,
    required double idleTau,
  }) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    _bindings!.spectrumFrame(
      levels,
      synced,
      idle,
      elapsedSeconds,
      dtSeconds,
      gridBlend,
      pauseBlend,
      idleTau,
    );
  }

  static double spectrumScalar(int op, double a,
      [double b = 0, double c = 0, double d = 0]) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    return _bindings!.spectrumScalar(op, a, b, c, d);
  }

  /// Writes `[latest, anchor, activeCount, ...indices]` and returns the count.
  static int lyricsActivity({
    required Pointer<Int64> timings,
    required int count,
    required int positionUs,
    required bool simulate,
    required Pointer<Int32> out,
    required int outCapacity,
  }) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    return _bindings!.lyricsActivity(
      timings,
      count,
      positionUs,
      simulate ? 1 : 0,
      out,
      outCapacity,
    );
  }

  /// Null when the helper has no value for the input.
  static String? coverPath(String url,
      {required int wanted, required int mode}) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    final encoded = utf8.encode(url);
    final input = allocBytes(encoded.isEmpty ? 1 : encoded.length);
    final outLength = mode == 3 ? 1 : 4096;
    final out = allocBytes(outLength);
    try {
      if (encoded.isNotEmpty) {
        input.asTypedList(encoded.length).setAll(0, encoded);
      }
      final written = _bindings!.coverPath(
        input,
        encoded.length,
        wanted,
        mode,
        out,
        outLength,
      );
      if (mode == 3) return written == 0 ? '0' : '1';
      if (written < 0) return null;
      return utf8.decode(out.asTypedList(written));
    } finally {
      freeBytes(out, outLength);
      freeBytes(input, encoded.isEmpty ? 1 : encoded.length);
    }
  }

  static int videoSync({
    required double audioMs,
    required double videoMs,
    required bool playing,
    required bool buffering,
    required bool seekInFlight,
    required double sinceLastSeekMs,
  }) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    return _bindings!.videoSync(
      audioMs,
      videoMs,
      playing ? 1 : 0,
      buffering ? 1 : 0,
      seekInFlight ? 1 : 0,
      sinceLastSeekMs,
    );
  }

  static double videoAspect(double rawAspect, int rotationCorrection) {
    if (!_ensureLoaded()) {
      throw StateError('native core unavailable: $_reason');
    }
    return _bindings!.videoAspect(rawAspect, rotationCorrection);
  }
}

/// Caller-owned native memory, freed explicitly to keep per-frame helpers off
/// the allocation path.
class NativeScratch {
  NativeScratch(this.length) : pointer = WispieCore.allocBytes(length);

  final int length;
  final Pointer<Uint8> pointer;

  // Views and typed pointers are built once: a per-frame helper that called
  // `asTypedList` or `cast` each tick would spend more time wrapping the buffer
  // than the core spends filling it.
  late final Uint8List bytes = pointer.asTypedList(length);
  late final Pointer<Double> doublesPointer = pointer.cast<Double>();
  late final Pointer<Int32> intsPointer = pointer.cast<Int32>();
  late final Pointer<Int64> longsPointer = pointer.cast<Int64>();
  late final Pointer<Float> floatsPointer = pointer.cast<Float>();
  late final Float64List doubles = doublesPointer.asTypedList(length ~/ 8);
  late final Int32List ints = intsPointer.asTypedList(length ~/ 4);
  late final Int64List longs = longsPointer.asTypedList(length ~/ 8);

  void dispose() => WispieCore.freeBytes(pointer, length);
}

typedef _EventNative = Void Function(
    Pointer<Void>, Int32, Pointer<Uint8>, IntPtr);

typedef _RunNative = Int32 Function(
    Pointer<Int8>, Pointer<NativeFunction<_EventNative>>, Pointer<Void>);
typedef _RunDart = int Function(
    Pointer<Int8>, Pointer<NativeFunction<_EventNative>>, Pointer<Void>);
typedef _RunBytesNative = Int32 Function(Pointer<Int8>, Pointer<Uint8>, UintPtr,
    Pointer<NativeFunction<_EventNative>>, Pointer<Void>);
typedef _RunBytesDart = int Function(Pointer<Int8>, Pointer<Uint8>, int,
    Pointer<NativeFunction<_EventNative>>, Pointer<Void>);

typedef _AbiVersionNative = Uint32 Function();
typedef _AbiVersionDart = int Function();

typedef _VersionNative = Pointer<Int8> Function();
typedef _VersionDart = Pointer<Int8> Function();

typedef _VoidNative = Void Function();
typedef _VoidDart = void Function();

typedef _AllocNative = Pointer<Uint8> Function(UintPtr);
typedef _AllocDart = Pointer<Uint8> Function(int);

typedef _FreeNative = Void Function(Pointer<Uint8>, UintPtr);
typedef _FreeDart = void Function(Pointer<Uint8>, int);

typedef _HlcObserveNative = Void Function(Int64);
typedef _HlcObserveDart = void Function(int);
typedef _HlcSetNative = Void Function(Int64);
typedef _HlcSetDart = void Function(int);
typedef _HlcNextNative = Int64 Function(Int64);
typedef _HlcNextDart = int Function(int);
typedef _HlcNowNative = Int64 Function();
typedef _HlcNowDart = int Function();

typedef _PlayheadEaseNative = Double Function(Double, Double);
typedef _PlayheadEaseDart = double Function(double, double);
typedef _PlayheadVisualNative = Double Function(
    Double, Double, Uint8, Double, Double);
typedef _PlayheadVisualDart = double Function(
    double, double, int, double, double);
typedef _SpectrumTargetsNative = Int32 Function(Pointer<Uint8>, UintPtr,
    Pointer<Int32>, UintPtr, Pointer<Float>, Double, Double, Pointer<Double>);
typedef _SpectrumTargetsDart = int Function(Pointer<Uint8>, int, Pointer<Int32>,
    int, Pointer<Float>, double, double, Pointer<Double>);
typedef _SpectrumFrameNative = Void Function(Pointer<Double>, Pointer<Double>,
    Pointer<Double>, Double, Double, Double, Double, Double);
typedef _SpectrumFrameDart = void Function(Pointer<Double>, Pointer<Double>,
    Pointer<Double>, double, double, double, double, double);
typedef _SpectrumScalarNative = Double Function(
    Uint8, Double, Double, Double, Double);
typedef _SpectrumScalarDart = double Function(
    int, double, double, double, double);
typedef _LyricsActivityNative = Int32 Function(
    Pointer<Int64>, UintPtr, Int64, Uint8, Pointer<Int32>, UintPtr);
typedef _LyricsActivityDart = int Function(
    Pointer<Int64>, int, int, int, Pointer<Int32>, int);
typedef _CoverPathNative = IntPtr Function(
    Pointer<Uint8>, UintPtr, Uint32, Uint8, Pointer<Uint8>, UintPtr);
typedef _CoverPathDart = int Function(
    Pointer<Uint8>, int, int, int, Pointer<Uint8>, int);
typedef _VideoSyncNative = Int32 Function(
    Double, Double, Uint8, Uint8, Uint8, Double);
typedef _VideoSyncDart = int Function(double, double, int, int, int, double);
typedef _VideoAspectNative = Double Function(Double, Int32);
typedef _VideoAspectDart = double Function(double, int);

class _Bindings {
  _Bindings(DynamicLibrary library)
      : abiVersion = library.lookupFunction<_AbiVersionNative, _AbiVersionDart>(
            'wispie_core_abi_version'),
        version = library.lookupFunction<_VersionNative, _VersionDart>(
            'wispie_core_version'),
        run = library.lookupFunction<_RunNative, _RunDart>('wispie_core_run'),
        runBytes = library.lookupFunction<_RunBytesNative, _RunBytesDart>(
            'wispie_core_run_bytes'),
        cancel = library
            .lookupFunction<_VoidNative, _VoidDart>('wispie_core_cancel'),
        alloc = library
            .lookupFunction<_AllocNative, _AllocDart>('wispie_core_alloc'),
        free =
            library.lookupFunction<_FreeNative, _FreeDart>('wispie_core_free'),
        hlcObserve = library.lookupFunction<_HlcObserveNative, _HlcObserveDart>(
            'wispie_core_hlc_observe'),
        hlcSet = library
            .lookupFunction<_HlcSetNative, _HlcSetDart>('wispie_core_hlc_set'),
        hlcNext = library.lookupFunction<_HlcNextNative, _HlcNextDart>(
            'wispie_core_hlc_next'),
        hlcNow = library
            .lookupFunction<_HlcNowNative, _HlcNowDart>('wispie_core_hlc_now'),
        playheadEase =
            library.lookupFunction<_PlayheadEaseNative, _PlayheadEaseDart>(
                'wispie_playhead_ease'),
        playheadVisual =
            library.lookupFunction<_PlayheadVisualNative, _PlayheadVisualDart>(
                'wispie_playhead_visual'),
        spectrumTargets = library.lookupFunction<_SpectrumTargetsNative,
            _SpectrumTargetsDart>('wispie_spectrum_targets'),
        spectrumFrame =
            library.lookupFunction<_SpectrumFrameNative, _SpectrumFrameDart>(
                'wispie_spectrum_frame'),
        spectrumScalar =
            library.lookupFunction<_SpectrumScalarNative, _SpectrumScalarDart>(
                'wispie_spectrum_scalar'),
        lyricsActivity =
            library.lookupFunction<_LyricsActivityNative, _LyricsActivityDart>(
                'wispie_lyrics_activity'),
        coverPath = library.lookupFunction<_CoverPathNative, _CoverPathDart>(
            'wispie_cover_path'),
        videoSync = library.lookupFunction<_VideoSyncNative, _VideoSyncDart>(
            'wispie_video_sync'),
        videoAspect =
            library.lookupFunction<_VideoAspectNative, _VideoAspectDart>(
                'wispie_video_aspect');

  final _AbiVersionDart abiVersion;
  final _VersionDart version;
  final _RunDart run;
  final _RunBytesDart runBytes;
  final _VoidDart cancel;
  final _AllocDart alloc;
  final _FreeDart free;
  final _HlcObserveDart hlcObserve;
  final _HlcSetDart hlcSet;
  final _HlcNextDart hlcNext;
  final _HlcNowDart hlcNow;
  final _PlayheadEaseDart playheadEase;
  final _PlayheadVisualDart playheadVisual;
  final _SpectrumTargetsDart spectrumTargets;
  final _SpectrumFrameDart spectrumFrame;
  final _SpectrumScalarDart spectrumScalar;
  final _LyricsActivityDart lyricsActivity;
  final _CoverPathDart coverPath;
  final _VideoSyncDart videoSync;
  final _VideoAspectDart videoAspect;
}
