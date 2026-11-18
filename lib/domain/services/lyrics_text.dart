import 'native_accel.dart';

/// Plain lyric text: timestamps and `[ar:…]`-style metadata dropped, blank
/// lines removed. Used by the search index and by lyric-fetch validation.
String lyricsPlainText(String content) => NativeAccel.plainLyricsText(content);
