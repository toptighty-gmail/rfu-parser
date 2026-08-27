import 'package:flutter/material.dart';
import '../models/fixture.dart';
import '../theme/app_theme.dart';

class AddFixtureDialog extends StatefulWidget {
  final Fixture? existingFixture;
  final Function(Fixture fixture) onSave;

  const AddFixtureDialog({super.key, this.existingFixture, required this.onSave});

  @override
  State<AddFixtureDialog> createState() => _AddFixtureDialogState();
}

class _AddFixtureDialogState extends State<AddFixtureDialog> {
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  late TextEditingController _homeTeamController;
  late TextEditingController _awayTeamController;
  late TextEditingController _homeScoreController;
  late TextEditingController _awayScoreController;
  late TextEditingController _venueController;

  @override
  void initState() {
    super.initState();
    final f = widget.existingFixture;
    _dateController = TextEditingController(text: f?.dateIso ?? DateTime.now().toIso8601String().split('T')[0]);
    _timeController = TextEditingController(text: f?.time ?? '15:00');
    _homeTeamController = TextEditingController(text: f?.homeTeam ?? '');
    _awayTeamController = TextEditingController(text: f?.awayTeam ?? '');
    _homeScoreController = TextEditingController(text: f?.homeScore?.toString() ?? '');
    _awayScoreController = TextEditingController(text: f?.awayScore?.toString() ?? '');
    _venueController = TextEditingController(text: f?.venue ?? 'Friendly Match');
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingFixture != null;

    return AlertDialog(
      backgroundColor: AppTheme.surfaceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.cardBorder),
      ),
      title: Row(
        children: [
          Icon(isEditing ? Icons.edit : Icons.add_circle, color: AppTheme.emeraldAccent),
          const SizedBox(width: 10),
          Text(
            isEditing ? 'Edit Custom Fixture' : 'Add Friendly Fixture',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildInput('Date (YYYY-MM-DD)', _dateController, icon: Icons.calendar_month),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInput('Time', _timeController, icon: Icons.access_time),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInput('Home Team', _homeTeamController, icon: Icons.shield),
            const SizedBox(height: 12),
            _buildInput('Away Team', _awayTeamController, icon: Icons.shield_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInput('Home Score', _homeScoreController, isNumber: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInput('Away Score', _awayScoreController, isNumber: true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInput('Venue / Location', _venueController, icon: Icons.location_on),
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
            backgroundColor: AppTheme.emeraldAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _save,
          child: Text(isEditing ? 'Save Changes' : 'Create Fixture', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildInput(String label, TextEditingController controller, {IconData? icon, bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        prefixIcon: icon != null ? Icon(icon, size: 18, color: AppTheme.goldAccent) : null,
        filled: true,
        fillColor: AppTheme.darkBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.cardBorder),
        ),
      ),
    );
  }

  void _save() {
    final home = _homeTeamController.text.trim();
    final away = _awayTeamController.text.trim();
    final date = _dateController.text.trim();

    if (home.isEmpty || away.isEmpty || date.isEmpty) return;

    final hScore = int.tryParse(_homeScoreController.text.trim());
    final aScore = int.tryParse(_awayScoreController.text.trim());

    final fixture = Fixture(
      id: widget.existingFixture?.id,
      date: date,
      dateIso: date,
      time: _timeController.text.trim(),
      homeTeam: home,
      awayTeam: away,
      homeScore: hScore,
      awayScore: aScore,
      status: (hScore != null && aScore != null) ? 'Completed' : 'Scheduled',
      venue: _venueController.text.trim(),
      competition: 'Friendly',
      roundNum: 'Friendly',
      isCustom: true,
    );

    widget.onSave(fixture);
    Navigator.of(context).pop();
  }
}
