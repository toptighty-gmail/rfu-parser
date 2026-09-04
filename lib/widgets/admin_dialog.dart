import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AdminDialog extends StatefulWidget {
  final Future<void> Function(String password) onLogin;

  const AdminDialog({super.key, required this.onLogin});

  @override
  State<AdminDialog> createState() => _AdminDialogState();
}

class _AdminDialogState extends State<AdminDialog> {
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      title: Row(
        children: [
          Icon(Icons.admin_panel_settings, color: AppTheme.goldAccent),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'Admin Mode Authentication',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the admin password to add/edit custom fixtures and upload team logos:',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passController,
            obscureText: true,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: '',
              filled: true,
              fillColor: AppTheme.darkBg,
              prefixIcon: Icon(
                Icons.lock,
                color: AppTheme.goldAccent,
                size: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.goldAccent, width: 1.5),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.goldAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Text(
                  'Authenticate',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final password = _passController.text.trim();
    if (password.isNotEmpty) {
      setState(() => _isLoading = true);
      await widget.onLogin(password);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
