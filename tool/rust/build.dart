import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Builds the Rust core for one platform and reports what it produced.
///
/// Targets: `host`, `android <abi>`, `apple macos`, `apple ios`, `linux`,
/// `windows`, `check`. Run from the repository root.
Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  if (!File(p.join(root, 'pubspec.yaml')).existsSync()) {
    stderr.writeln('run this from the repository root');
    exit(64);
  }

  final target = args.isEmpty ? 'host' : args.first;
  final rest = args.skip(1).toList();

  switch (target) {
    case 'host':
      await _buildAppleOrHost(root);
    case 'linux':
      await _cargo(
          root, ['build', '--release', '--target', 'x86_64-unknown-linux-gnu']);
      _print(p.join(root, 'rust', 'target', 'x86_64-unknown-linux-gnu',
          'release', 'libwispie_core.so'));
    case 'windows':
      await _cargo(
          root, ['build', '--release', '--target', 'x86_64-pc-windows-msvc']);
      _print(p.join(root, 'rust', 'target', 'x86_64-pc-windows-msvc', 'release',
          'wispie_core.dll'));
    case 'android':
      await _buildAndroid(root, rest.isEmpty ? 'arm64-v8a' : rest.first);
    case 'apple':
      await _buildApple(root, rest.isEmpty ? 'macos' : rest.first);
    case 'check':
      await _check(root);
    default:
      stderr.writeln('unknown target: $target');
      exit(64);
  }
}

Future<void> _buildAppleOrHost(String root) async {
  if (Platform.isMacOS) {
    final triple = Abi.current() == Abi.macosArm64
        ? 'aarch64-apple-darwin'
        : 'x86_64-apple-darwin';
    await _cargo(root, ['build', '--release', '--target', triple]);
    _print(
        p.join(
            root, 'rust', 'target', triple, 'release', 'libwispie_core.dylib'),
        also: p.join(
            root, 'rust', 'target', triple, 'release', 'libwispie_core.a'));
    return;
  }
  if (Platform.isLinux) {
    await _cargo(root, ['build', '--release']);
    _print(p.join(root, 'rust', 'target', 'release', 'libwispie_core.so'));
    return;
  }
  if (Platform.isWindows) {
    await _cargo(root, ['build', '--release']);
    _print(p.join(root, 'rust', 'target', 'release', 'wispie_core.dll'));
    return;
  }
  stderr.writeln('unsupported host: ${Platform.operatingSystem}');
  exit(64);
}

Future<void> _buildApple(String root, String platform) async {
  if (platform == 'macos-host') {
    final triple = Abi.current() == Abi.macosArm64
        ? 'aarch64-apple-darwin'
        : 'x86_64-apple-darwin';
    await _cargo(root, ['build', '--release', '--target', triple]);
    final target =
        p.join(root, 'macos', 'Runner', 'Configs', 'libwispie_core.a');
    await _lipo(
      root,
      [p.join(root, 'rust', 'target', triple, 'release', 'libwispie_core.a')],
      target,
    );
    _writeXcconfig(
      p.join(root, 'macos', 'Runner', 'Configs', 'RustCore.xcconfig'),
      '-force_load \$(SRCROOT)/Runner/Configs/libwispie_core.a '
      '-framework CoreFoundation -liconv',
    );
    _print(target);
    return;
  }

  if (platform == 'macos') {
    const triples = ['aarch64-apple-darwin', 'x86_64-apple-darwin'];
    for (final triple in triples) {
      await _cargo(root, ['build', '--release', '--target', triple]);
    }

    final target =
        p.join(root, 'macos', 'Runner', 'Configs', 'libwispie_core.a');
    await _lipo(
      root,
      [
        for (final triple in triples)
          p.join(root, 'rust', 'target', triple, 'release', 'libwispie_core.a')
      ],
      target,
    );
    _writeXcconfig(
      p.join(root, 'macos', 'Runner', 'Configs', 'RustCore.xcconfig'),
      // force_load: Dart resolves the symbols at runtime, so a plain -l lets the
      // linker drop the archive member and the app silently ships without a core.
      '-force_load \$(SRCROOT)/Runner/Configs/libwispie_core.a '
      '-framework CoreFoundation -liconv',
    );
    _print(target);
    return;
  }

  if (platform == 'ios') {
    const triple = 'aarch64-apple-ios';
    await _cargo(root, ['build', '--release', '--target', triple]);
    final target = p.join(root, 'ios', 'Flutter', 'libwispie_core.a');
    await _lipo(
      root,
      [p.join(root, 'rust', 'target', triple, 'release', 'libwispie_core.a')],
      target,
    );
    _writeXcconfig(
      p.join(root, 'ios', 'Flutter', 'RustCore.xcconfig'),
      // force_load: Dart resolves the symbols at runtime, so a plain -l lets the
      // linker drop the archive member and the app silently ships without a core.
      '-force_load \$(SRCROOT)/Flutter/libwispie_core.a '
      '-framework CoreFoundation -liconv',
    );
    _print(target);
    return;
  }

  stderr.writeln('unknown apple platform: $platform (expected macos or ios)');
  exit(64);
}

Future<void> _buildAndroid(String root, String abi) async {
  final triple = switch (abi) {
    'arm64-v8a' => 'aarch64-linux-android',
    'armeabi-v7a' => 'armv7-linux-androideabi',
    _ => throw StateError('unsupported android abi: $abi'),
  };
  final clangPrefix =
      abi == 'arm64-v8a' ? 'aarch64-linux-android' : 'armv7a-linux-androideabi';

  final ndk = _androidNdk(root);
  final hostTag = switch (Platform.operatingSystem) {
    'macos' => 'darwin-x86_64',
    'linux' => 'linux-x86_64',
    'windows' => 'windows-x86_64',
    _ => throw StateError('unsupported NDK host: ${Platform.operatingSystem}'),
  };
  final bin = p.join(ndk, 'toolchains', 'llvm', 'prebuilt', hostTag, 'bin');
  final linker = p.join(bin, '${clangPrefix}24-clang');
  if (!File(linker).existsSync()) {
    throw StateError('NDK linker not found: $linker');
  }

  final upper = triple.toUpperCase().replaceAll('-', '_');
  await _cargo(
    root,
    ['build', '--release', '--target', triple],
    environment: {
      'CARGO_TARGET_${upper}_LINKER': linker,
      'CARGO_TARGET_${upper}_AR': p.join(bin, 'llvm-ar'),
    },
  );

  final built =
      p.join(root, 'rust', 'target', triple, 'release', 'libwispie_core.so');
  final destination = p.join(root, 'android', 'app', 'src', 'main', 'jniLibs',
      abi, 'libwispie_core.so');
  Directory(p.dirname(destination)).createSync(recursive: true);
  File(built).copySync(destination);
  _print(destination);
}

String _androidNdk(String root) {
  final environment = Platform.environment;
  for (final key in ['ANDROID_NDK_HOME', 'ANDROID_NDK_ROOT']) {
    final value = environment[key];
    if (value != null && value.isNotEmpty) return value;
  }

  final gradle = File(p.join(root, 'android', 'app', 'build.gradle.kts'));
  final version = RegExp(r'ndkVersion\s*=\s*"([^"]+)"')
      .firstMatch(gradle.existsSync() ? gradle.readAsStringSync() : '')
      ?.group(1);
  final sdk = environment['ANDROID_HOME'] ?? environment['ANDROID_SDK_ROOT'];
  if (version != null && sdk != null) return p.join(sdk, 'ndk', version);

  throw StateError('Android NDK not found; set ANDROID_NDK_HOME');
}

Future<void> _cargo(
  String root,
  List<String> arguments, {
  Map<String, String>? environment,
}) async {
  final result = await Process.run(
    'cargo',
    arguments,
    workingDirectory: p.join(root, 'rust'),
    environment: environment,
    runInShell: Platform.isWindows,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    stderr.writeln('cargo ${arguments.join(' ')} failed');
    exit(result.exitCode == 0 ? 1 : result.exitCode);
  }
}

Future<void> _lipo(String root, List<String> inputs, String output) async {
  final result = await Process.run(
    'lipo',
    ['-create', ...inputs, '-output', output],
  );
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    stderr.writeln('lipo failed');
    exit(1);
  }
}

void _writeXcconfig(String path, String linkFlags) {
  File(path).writeAsStringSync(
    '// Generated by tool/rust/build.dart; do not commit.\n'
    'OTHER_LDFLAGS = \$(inherited) $linkFlags\n',
  );
}

Future<void> _check(String root) async {
  final checks = <List<String>>[
    ['fmt', '--all', '--', '--check'],
    ['clippy', '--all-targets', '--', '-D', 'warnings'],
    ['check', '--all-targets'],
  ];
  for (final arguments in checks) {
    await _cargo(root, arguments);
  }
  stdout.writeln('rust checks passed');
}

void _print(String path, {String? also}) {
  stdout.writeln(path);
  if (also != null) stdout.writeln(also);
}
