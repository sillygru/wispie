import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../services/cover_refresh_service.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';

class AlbumArtImage extends StatefulWidget {
  final String url;
  final String? filename;

  /// Changes when the bytes at a stable local cover path are replaced.
  final Object? cacheVersion;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? cacheWidth;
  final int? cacheHeight;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final FilterQuality filterQuality;

  const AlbumArtImage({
    super.key,
    required this.url,
    this.filename,
    this.cacheVersion,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.placeholder,
    this.errorWidget,
    this.cacheWidth,
    this.cacheHeight,
    this.memCacheWidth,
    this.memCacheHeight,
    this.filterQuality = FilterQuality.medium,
  });

  @override
  State<AlbumArtImage> createState() => _AlbumArtImageState();
}

class _AlbumArtImageState extends State<AlbumArtImage> {
  Future<String?>? _refreshFuture;
  String? _resolvedUrl;
  int _imageRevision = 0;

  @override
  void didUpdateWidget(covariant AlbumArtImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.filename != widget.filename) {
      _refreshFuture = null;
      _resolvedUrl = null;
      _imageRevision++;
    } else if (oldWidget.cacheVersion != widget.cacheVersion) {
      // Cover extraction deliberately reuses the song-scoped path. Evict the
      // resized provider too: evicting only FileImage leaves Image.file's
      // cacheWidth variant alive.
      unawaited(_refreshAfterEviction(oldWidget));
      _imageRevision++;
    }
  }

  bool get _canAttemptLazyRefresh =>
      widget.filename != null &&
      _looksLikeSongFile(widget.filename!) &&
      // A recycled tile would otherwise re-enqueue a song we already know has
      // no art, on every rebuild.
      !CoverRefreshService.instance.isSuppressed(widget.filename!);

  void _scheduleLazyRefresh() {
    if (_refreshFuture != null || !_canAttemptLazyRefresh) return;

    _refreshFuture =
        CoverRefreshService.instance.ensureCoverForSong(widget.filename!).then(
      (path) {
        if (!mounted) return path;
        if (path != null && path.isNotEmpty) {
          setState(() {
            _resolvedUrl = path;
          });
        }
        return path;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) {
      if (_canAttemptLazyRefresh) {
        _scheduleLazyRefresh();
        return widget.placeholder ?? _buildPlaceholder();
      }
      return _buildError();
    }

    final imageUrl = _resolvedUrl ?? widget.url;
    final bool isLocal = imageUrl.startsWith('/') ||
        imageUrl.startsWith('C:\\') ||
        imageUrl.startsWith('file://') ||
        imageUrl.startsWith('content://');

    int? effectiveMemCacheWidth = widget.memCacheWidth;
    int? effectiveMemCacheHeight = widget.memCacheHeight;

    if (effectiveMemCacheWidth == null && effectiveMemCacheHeight == null) {
      final width = widget.width;
      final height = widget.height;
      final hasFiniteWidth = width != null && width.isFinite;
      final hasFiniteHeight = height != null && height.isFinite;
      if (hasFiniteWidth && width < 400) {
        effectiveMemCacheWidth = (width * 2.5).toInt();
      } else if (hasFiniteHeight && height < 400) {
        effectiveMemCacheHeight = (height * 2.5).toInt();
      } else if (hasFiniteWidth) {
        effectiveMemCacheWidth = (width * 2.0).toInt().clamp(100, 1024);
      } else if (hasFiniteHeight) {
        effectiveMemCacheHeight = (height * 2.0).toInt().clamp(100, 1024);
      } else {
        effectiveMemCacheWidth = 1024;
      }
    }

    final filterQuality = widget.filterQuality;

    Widget content;

    if (isLocal) {
      String path;
      try {
        final uri = Uri.parse(imageUrl);
        if (uri.isScheme('file')) {
          path = uri.toFilePath();
        } else {
          path = imageUrl;
        }
      } catch (_) {
        path = imageUrl;
      }

      // No existsSync() pre-check: it ran synchronously on the UI thread for
      // every build of every tile, and errorBuilder below already handles a
      // missing file identically.
      content = Image.file(
        File(path),
        key: ValueKey('$path-$_imageRevision'),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        filterQuality: filterQuality,
        cacheWidth: effectiveMemCacheWidth ?? widget.cacheWidth,
        cacheHeight: effectiveMemCacheHeight ?? widget.cacheHeight,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          CoverRefreshService.evictCoverFromImageCache(path);
          _refreshFuture = null;
          _scheduleLazyRefresh();
          return widget.placeholder ?? _buildPlaceholder();
        },
      );
    } else {
      content = Image.network(
        // The resolved URL, not widget.url — otherwise a cover the lazy
        // refresh just found is thrown away on this branch.
        imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        filterQuality: filterQuality,
        cacheWidth: effectiveMemCacheWidth ?? widget.cacheWidth,
        cacheHeight: effectiveMemCacheHeight ?? widget.cacheHeight,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: child,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return widget.placeholder ?? _buildPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return widget.errorWidget ?? _buildError();
        },
      );
    }

    if (widget.borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: content,
      );
    }

    return content;
  }

  Future<void> _refreshAfterEviction(AlbumArtImage image) async {
    await _evictLocalImage(image);
    if (mounted) setState(() {});
  }

  Future<void> _evictLocalImage(AlbumArtImage image) async {
    final path = _localPath(image.url);
    if (path == null) return;

    final provider = FileImage(File(path));
    await provider.evict();

    final dimensions = _cacheDimensions(image);
    if (dimensions.width != null || dimensions.height != null) {
      await ResizeImage(
        provider,
        width: dimensions.width,
        height: dimensions.height,
      ).evict();
    }
  }

  ({int? width, int? height}) _cacheDimensions(AlbumArtImage image) {
    var width = image.memCacheWidth;
    var height = image.memCacheHeight;
    if (width == null && height == null) {
      final w = image.width;
      final h = image.height;
      final hasFiniteWidth = w != null && w.isFinite;
      final hasFiniteHeight = h != null && h.isFinite;
      if (hasFiniteWidth && w < 400) {
        width = (w * 2.5).toInt();
      } else if (hasFiniteHeight && h < 400) {
        height = (h * 2.5).toInt();
      } else if (hasFiniteWidth) {
        width = (w * 2.0).toInt().clamp(100, 1024);
      } else if (hasFiniteHeight) {
        height = (h * 2.0).toInt().clamp(100, 1024);
      } else {
        width = 1024;
      }
    }
    return (
      width: width ?? image.cacheWidth,
      height: height ?? image.cacheHeight,
    );
  }

  String? _localPath(String value) {
    final isLocal = value.startsWith('/') ||
        value.startsWith('C:\\\\') ||
        value.startsWith('file://') ||
        value.startsWith('content://');
    if (!isLocal) return null;

    try {
      final uri = Uri.parse(value);
      return uri.isScheme('file') ? uri.toFilePath() : value;
    } catch (_) {
      return value;
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFF1E1E1E),
    );
  }

  Widget _buildError() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFF1E1E1E),
      child: const Center(
        child: AppIcon(AppIcons.musicNote, color: Colors.white24),
      ),
    );
  }

  bool _looksLikeSongFile(String value) {
    final lower = value.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.heic')) {
      return false;
    }

    return p.extension(lower).isNotEmpty;
  }
}

class StaticAlbumArtImage extends StatelessWidget {
  final String url;
  final String? filename;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const StaticAlbumArtImage({
    super.key,
    required this.url,
    this.filename,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _buildErrorWidget();
    }

    final bool isLocal = url.startsWith('/') ||
        url.startsWith('C:\\') ||
        url.startsWith('file://') ||
        url.startsWith('content://');

    Widget content;

    // Locals: public fields do not promote, so copy before null checks.
    final w = width;
    final h = height;

    if (isLocal) {
      String path;
      try {
        final uri = Uri.parse(url);
        if (uri.isScheme('file')) {
          path = uri.toFilePath();
        } else {
          path = url;
        }
      } catch (_) {
        path = url;
      }

      content = Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        filterQuality: FilterQuality.low,
        cacheWidth: w != null && w.isFinite ? (w * 2).toInt() : null,
        cacheHeight: h != null && h.isFinite ? (h * 2).toInt() : null,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? _buildErrorWidget();
        },
      );
    } else {
      content = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        filterQuality: FilterQuality.low,
        cacheWidth: w != null && w.isFinite ? (w * 2).toInt() : null,
        cacheHeight: h != null && h.isFinite ? (h * 2).toInt() : null,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ?? _buildPlaceholderWidget();
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? _buildErrorWidget();
        },
      );
    }

    if (borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    return content;
  }

  Widget _buildPlaceholderWidget() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1E1E1E),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1E1E1E),
      child: const Center(
        child: AppIcon(AppIcons.musicNote, color: Colors.white24),
      ),
    );
  }
}
