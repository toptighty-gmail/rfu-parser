import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

class LogoUploadDialog extends StatefulWidget {
  final Function(String teamName, String logoUrl) onUploaded;

  const LogoUploadDialog({super.key, required this.onUploaded});

  @override
  State<LogoUploadDialog> createState() => _LogoUploadDialogState();
}

class _LogoUploadDialogState extends State<LogoUploadDialog> {
  final TextEditingController _teamController = TextEditingController();
  Uint8List? _fileBytes;
  String? _fileName;
  bool _isUploading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.cardBorder),
      ),
      title: const Row(
        children: [
          Icon(Icons.cloud_upload, color: AppTheme.goldAccent),
          SizedBox(width: 10),
          Text('Upload Team Logo', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _teamController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Team Name',
                hintText: 'e.g. Exeter Chiefs',
                labelStyle: const TextStyle(color: AppTheme.textMuted),
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.darkBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.attach_file, color: AppTheme.goldAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fileName ?? 'Select Logo Image (PNG, JPG, SVG, WEBP)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _fileName != null ? AppTheme.goldAccent : AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppTheme.rubyAccent, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.goldAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isUploading ? null : _upload,
          child: _isUploading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Upload to Supabase', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      final dynamic result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'svg'],
      );

      if (result != null && result.files != null && (result.files as List).isNotEmpty) {
        final dynamic file = result.files.first;
        setState(() {
          _fileBytes = file.bytes;
          _fileName = file.name;
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'File pick error: $e');
    }
  }

  Future<void> _upload() async {
    final teamName = _teamController.text.trim();
    if (teamName.isEmpty) {
      setState(() => _error = 'Please enter a team name');
      return;
    }
    if (_fileBytes == null || _fileName == null) {
      setState(() => _error = 'Please select a logo image file');
      return;
    }

    setState(() => _isUploading = true);

    final ext = '.${_fileName!.split('.').last}';
    final logoUrl = await SupabaseService.uploadTeamLogo(teamName, _fileBytes!, ext);

    if (logoUrl != null) {
      widget.onUploaded(teamName, logoUrl);
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() {
        _isUploading = false;
        _error = 'Upload failed. Check Supabase connection or permissions.';
      });
    }
  }
}
