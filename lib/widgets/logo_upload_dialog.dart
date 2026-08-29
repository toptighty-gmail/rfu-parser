import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

class LogoUploadDialog extends StatefulWidget {
  final List<String> availableTeams;
  final String? initialTeam;
  final Function(String teamName, String logoUrl) onUploaded;

  const LogoUploadDialog({
    super.key,
    this.availableTeams = const [],
    this.initialTeam,
    required this.onUploaded,
  });

  @override
  State<LogoUploadDialog> createState() => _LogoUploadDialogState();
}

class _LogoUploadDialogState extends State<LogoUploadDialog> {
  final TextEditingController _teamController = TextEditingController();
  String? _selectedDropdownTeam;
  Uint8List? _fileBytes;
  String? _fileName;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialTeam != null && widget.initialTeam!.isNotEmpty) {
      _teamController.text = widget.initialTeam!;
      if (widget.availableTeams.contains(widget.initialTeam!)) {
        _selectedDropdownTeam = widget.initialTeam!;
      }
    } else if (widget.availableTeams.isNotEmpty) {
      _selectedDropdownTeam = widget.availableTeams.first;
      _teamController.text = widget.availableTeams.first;
    }
  }

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
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.availableTeams.isNotEmpty) ...[
                const Text('Select Existing Team:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.availableTeams.contains(_selectedDropdownTeam) ? _selectedDropdownTeam : null,
                      hint: const Text('Choose a team from division...', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      isExpanded: true,
                      dropdownColor: AppTheme.surfaceBg,
                      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.goldAccent),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      items: widget.availableTeams.map((team) {
                        return DropdownMenuItem<String>(
                          value: team,
                          child: Text(team, style: const TextStyle(color: AppTheme.textPrimary)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedDropdownTeam = val;
                            _teamController.text = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Or type team name manually:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
              ],
              TextField(
                controller: _teamController,
                style: const TextStyle(color: AppTheme.textPrimary),
                onChanged: (val) {
                  setState(() {
                    if (widget.availableTeams.contains(val.trim())) {
                      _selectedDropdownTeam = val.trim();
                    } else {
                      _selectedDropdownTeam = null;
                    }
                  });
                },
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
