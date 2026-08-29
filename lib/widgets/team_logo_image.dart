import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class TeamLogoImage extends StatelessWidget {
  final String? logoUrl;
  final double size;
  final double? width;
  final double? height;
  final BoxFit fit;

  const TeamLogoImage({
    super.key,
    required this.logoUrl,
    this.size = 24,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;

    if (logoUrl == null || logoUrl!.trim().isEmpty) {
      return Icon(Icons.shield, size: size * 0.85, color: AppTheme.textMuted);
    }

    final url = logoUrl!.trim();

    // 1. Check for SVG Data URI (e.g. data:image/svg+xml;base64,...)
    if (url.startsWith('data:image/svg') || url.contains('image/svg+xml')) {
      try {
        final base64Part = url.split(',').last;
        final bytes = base64Decode(base64Part);
        return SvgPicture.memory(
          bytes,
          width: w,
          height: h,
          fit: fit,
          placeholderBuilder: (_) =>
              Icon(Icons.shield, size: size * 0.85, color: AppTheme.textMuted),
        );
      } catch (_) {
        return Icon(Icons.shield, size: size * 0.85, color: AppTheme.textMuted);
      }
    }

    // 2. Check for other raster base64 data URIs (PNG, JPEG, etc.)
    if (url.startsWith('data:image')) {
      try {
        final base64Part = url.split(',').last;
        final bytes = base64Decode(base64Part);
        return Image.memory(
          bytes,
          width: w,
          height: h,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.shield, size: size * 0.85, color: AppTheme.textMuted),
        );
      } catch (_) {
        return Icon(Icons.shield, size: size * 0.85, color: AppTheme.textMuted);
      }
    }

    // 3. Network SVG (.svg)
    if (url.toLowerCase().endsWith('.svg') || url.toLowerCase().contains('.svg?')) {
      return SvgPicture.network(
        url,
        width: w,
        height: h,
        fit: fit,
        placeholderBuilder: (_) =>
            Icon(Icons.shield, size: size * 0.85, color: AppTheme.textMuted),
      );
    }

    // 4. Standard HTTP/HTTPS network image
    return Image.network(
      url,
      width: w,
      height: h,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.shield, size: size * 0.85, color: AppTheme.textMuted),
    );
  }
}
