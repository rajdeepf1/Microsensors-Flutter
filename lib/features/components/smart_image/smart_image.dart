import 'dart:io';
import 'package:flutter/material.dart';
import '../../../utils/colors.dart';

enum ImageShape { circle, rounded, rectangle }

class SmartImage extends StatelessWidget {
  final String? imageUrl;
  final String? baseUrl; // optional base URL to prepend for relative paths
  final String? username; // used to build initials fallback
  final double? width;
  final double? height;
  final BoxFit fit;
  final ImageShape shape;
  final double borderRadius; // used when shape == rounded
  final Widget? placeholder; // shown while loading
  final Widget? errorWidget; // shown on load error
  final bool useCached; // if true, you can swap with CachedNetworkImage easily

  const SmartImage({
    super.key,
    required this.imageUrl,
    this.baseUrl,
    this.username,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.shape = ImageShape.rounded,
    this.borderRadius = 12.0,
    this.placeholder,
    this.errorWidget,
    this.useCached = false,
  });

  String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (trimmed.startsWith('/') || trimmed.startsWith('file://')) {
      final filePath = trimmed.startsWith('file://')
          ? trimmed.replaceFirst('file://', '')
          : trimmed;
      final f = File(filePath);
      if (f.existsSync()) {
        return 'file://$filePath';
      }
    }

    if (baseUrl != null && baseUrl!.isNotEmpty) {
      final base = baseUrl!.endsWith('/')
          ? baseUrl!.substring(0, baseUrl!.length - 1)
          : baseUrl!;
      final path = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
      return '$base/$path';
    }

    return null;
  }

  Widget _initialsAvatar(String? name, {double? h, double? w}) {
    final n = (name ?? '').trim();
    String initials = n;
    if (n.isNotEmpty) {
      final parts = n.split(RegExp(r'\s+'));
      initials = parts.length == 1
          ? parts[0].substring(0, 1).toUpperCase()
          : (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
    }

    final size = (h ?? w ?? 48.0);
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppColors.app_blue_color,
        borderRadius: BorderRadius.circular(
          shape == ImageShape.circle ? size / 2 : borderRadius,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _wrapWithShape(Widget child) {
    if (shape == ImageShape.circle) {
      final dim = (width ?? height ?? 48.0);
      return ClipOval(
        child: SizedBox(width: width ?? dim, height: height ?? dim, child: child),
      );
    } else if (shape == ImageShape.rounded) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(width: width, height: height, child: child),
      );
    } else {
      return SizedBox(width: width, height: height, child: child);
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeUrl(imageUrl);

    // 1) Nothing useful -> initials
    if (normalized == null) {
      return _wrapWithShape(
        placeholder ?? _initialsAvatar(username, h: height, w: width),
      );
    }

    // 2) Local file
    if (normalized.startsWith('file://')) {
      final filePath = normalized.replaceFirst('file://', '');
      final file = File(filePath);
      if (file.existsSync()) {
        return _wrapWithShape(
          Image.file(file, fit: fit, width: width, height: height),
        );
      } else {
        return _wrapWithShape(
          errorWidget ?? _initialsAvatar(username, h: height, w: width),
        );
      }
    }

    // 3) Network image
    final net = Image.network(
      normalized,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;

        // Full-size loader inside same shape
        final Widget loader = SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );

        return _wrapWithShape(loader);
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? _initialsAvatar(username, h: height, w: width);
      },
    );

    return _wrapWithShape(net);
  }
}
