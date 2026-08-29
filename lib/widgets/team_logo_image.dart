import 'dart:convert';
import 'package:flutter/material.dart';
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

    // Check for base64 data URI
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

    // Standard HTTP/HTTPS network image
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
