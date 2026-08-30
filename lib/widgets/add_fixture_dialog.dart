import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fixture.dart';
import '../theme/app_theme.dart';

import '../services/rfu_team_registry.dart';

class AddFixtureDialog extends StatefulWidget {
  final Fixture? existingFixture;
  final String? contextTeam;
  final int? rfuTeamId;
  final Function(Fixture fixture) onSave;

  const AddFixtureDialog({
    super.key,
    this.existingFixture,
    this.contextTeam,
    this.rfuTeamId,
    required this.onSave,
  });

  @override
  State<AddFixtureDialog> createState() => _AddFixtureDialogState();
}

class _AddFixtureDialogState extends State<AddFixtureDialog> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 15, minute: 0);
  String _fixtureType = 'Friendly'; // 'Friendly' or 'Cup'

  late TextEditingController _dateController;
  late TextEditingController _timeController;
  late TextEditingController _homeTeamController;
  late TextEditingController _awayTeamController;
  late TextEditingController _homeScoreController;
  late TextEditingController _awayScoreController;
  late TextEditingController _venueController;
  late TextEditingController _cupNameController;

  static final DateFormat _rfuDateFormat = DateFormat('EEEE, d MMM yyyy');

  @override
  void initState() {
    super.initState();
    final f = widget.existingFixture;

    if (f != null) {
      // Attempt to parse existing fixture date
      _selectedDate = _parseFixtureDate(f.dateIso, f.date);

      // Attempt to parse existing fixture time
      try {
        if (f.time.isNotEmpty && f.time.contains(':')) {
          final timeParts = f.time.split(':');
          _selectedTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
        }
      } catch (_) {
        _selectedTime = const TimeOfDay(hour: 15, minute: 0);
      }

      final isCup = f.competition.toLowerCase().contains('cup') || f.roundNum.toLowerCase().contains('cup');
      _fixtureType = isCup ? 'Cup' : 'Friendly';
    }

    _dateController = TextEditingController(text: _rfuDateFormat.format(_selectedDate));
    _timeController = TextEditingController(text: _formatTimeOfDay(_selectedTime));
    _homeTeamController = TextEditingController(text: f?.homeTeam ?? '');
    _awayTeamController = TextEditingController(text: f?.awayTeam ?? '');
    _homeScoreController = TextEditingController(text: f?.homeScore?.toString() ?? '');
    _awayScoreController = TextEditingController(text: f?.awayScore?.toString() ?? '');
    _venueController = TextEditingController(text: f?.venue ?? '');
    _cupNameController = TextEditingController(
      text: f != null && (f.competition.toLowerCase().contains('cup') || f.roundNum.toLowerCase().contains('cup'))
          ? f.competition
          : 'Devon Senior Cup',
    );
  }

  DateTime _parseFixtureDate(String? dateIso, String? dateStr) {
    if (dateIso != null && dateIso.isNotEmpty) {
      try {
        return DateTime.parse(dateIso);
      } catch (_) {}
    }
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        return _rfuDateFormat.parse(dateStr);
      } catch (_) {}
      try {
        return DateFormat('d MMM yyyy').parse(dateStr);
      } catch (_) {}
      try {
        return DateFormat('dd-MM-yyyy').parse(dateStr);
      } catch (_) {}
      try {
        return DateTime.parse(dateStr);
      } catch (_) {}
    }
    return DateTime.now();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.goldAccent,
              onPrimary: Colors.black,
              surface: AppTheme.surfaceBg,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _rfuDateFormat.format(picked);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.goldAccent,
              onPrimary: Colors.black,
              surface: AppTheme.surfaceBg,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = _formatTimeOfDay(picked);
      });
    }
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
          Icon(
            isEditing ? Icons.edit : (_fixtureType == 'Cup' ? Icons.emoji_events : Icons.sports_rugby),
            color: _fixtureType == 'Cup' ? AppTheme.emeraldAccent : AppTheme.goldAccent,
          ),
          const SizedBox(width: 10),
          Text(
            isEditing
                ? 'Edit Custom Fixture'
                : (_fixtureType == 'Cup' ? 'Add Cup Fixture' : 'Add Friendly Fixture'),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Team Context Header Badge (if created from a team context)
              if (widget.contextTeam != null && widget.contextTeam!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.goldAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield, size: 16, color: AppTheme.goldAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'CLUB CONTEXT: ${widget.contextTeam!.toUpperCase()}${widget.rfuTeamId != null ? " [RFU ID: ${widget.rfuTeamId}]" : ""}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: AppTheme.goldAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Fixture Type Selector (Friendly vs Cup)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.darkBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _fixtureType = 'Friendly'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _fixtureType == 'Friendly' ? AppTheme.goldAccent : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.sports_rugby,
                                size: 16,
                                color: _fixtureType == 'Friendly' ? Colors.black : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Friendly Match',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _fixtureType == 'Friendly' ? Colors.black : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _fixtureType = 'Cup'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _fixtureType == 'Cup' ? AppTheme.emeraldAccent : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                size: 16,
                                color: _fixtureType == 'Cup' ? Colors.black : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Cup Fixture',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _fixtureType == 'Cup' ? Colors.black : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Cup Name Input (Visible when Cup is selected)
              if (_fixtureType == 'Cup') ...[
                _buildInput('Cup Competition (e.g. Devon Senior Cup, Papa Johns Cup)', _cupNameController, icon: Icons.emoji_events),
                const SizedBox(height: 12),
              ],

              // RFU Standard Date Picker & Time Picker
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: _pickDate,
                      child: IgnorePointer(
                        child: TextField(
                          controller: _dateController,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Date (e.g. Saturday, 26 Sep 2026)',
                            labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            prefixIcon: const Icon(Icons.calendar_month, size: 18, color: AppTheme.goldAccent),
                            suffixIcon: const Icon(Icons.arrow_drop_down, color: AppTheme.goldAccent),
                            filled: true,
                            fillColor: AppTheme.darkBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.cardBorder),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _pickTime,
                      child: IgnorePointer(
                        child: TextField(
                          controller: _timeController,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Time (HH:MM)',
                            labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            prefixIcon: const Icon(Icons.access_time, size: 18, color: AppTheme.goldAccent),
                            suffixIcon: const Icon(Icons.arrow_drop_down, color: AppTheme.goldAccent),
                            filled: true,
                            fillColor: AppTheme.darkBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.cardBorder),
                            ),
                          ),
                        ),
                      ),
                    ),
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
                    child: _buildInput('Home Score (Optional)', _homeScoreController, isNumber: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInput('Away Score (Optional)', _awayScoreController, isNumber: true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInput('Venue / Location (Optional)', _venueController, icon: Icons.location_on),
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
            backgroundColor: _fixtureType == 'Cup' ? AppTheme.emeraldAccent : AppTheme.goldAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _save,
          child: Text(
            isEditing ? 'Save Changes' : (_fixtureType == 'Cup' ? 'Create Cup Fixture' : 'Create Friendly Fixture'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
    final rfuFormattedDate = _rfuDateFormat.format(_selectedDate);

    if (home.isEmpty || away.isEmpty) return;

    final hScore = int.tryParse(_homeScoreController.text.trim());
    final aScore = int.tryParse(_awayScoreController.text.trim());
    final dateIso = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final isCup = _fixtureType == 'Cup';
    final competitionName = isCup
        ? (_cupNameController.text.trim().isNotEmpty ? _cupNameController.text.trim() : 'Cup Match')
        : 'Friendly';
    final roundLabel = isCup
        ? (_cupNameController.text.trim().isNotEmpty ? _cupNameController.text.trim() : 'Cup Matches')
        : 'Friendly Matches';

    final effectiveContext = widget.contextTeam?.trim().isNotEmpty == true
        ? widget.contextTeam!.trim()
        : (widget.existingFixture?.contextTeam ?? home);

    final effectiveRfuId = widget.rfuTeamId ??
        widget.existingFixture?.rfuTeamId ??
        RfuTeamRegistry.lookupTeamId(effectiveContext) ??
        RfuTeamRegistry.lookupTeamId(home) ??
        RfuTeamRegistry.lookupTeamId(away);

    final baseVenue = _venueController.text.trim();
    final enrichedVenue = baseVenue.isNotEmpty
        ? '$baseVenue [Context: $effectiveContext]${effectiveRfuId != null ? " [ID: $effectiveRfuId]" : ""}'
        : '[Context: $effectiveContext]${effectiveRfuId != null ? " [ID: $effectiveRfuId]" : ""}';

    final homeTeamId = widget.existingFixture?.homeTeamId ?? RfuTeamRegistry.lookupTeamId(home);
    final awayTeamId = widget.existingFixture?.awayTeamId ?? RfuTeamRegistry.lookupTeamId(away);

    final fixture = Fixture(
      id: widget.existingFixture?.id,
      date: rfuFormattedDate,
      dateIso: dateIso,
      time: _timeController.text.trim(),
      homeTeam: home,
      awayTeam: away,
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
      homeScore: hScore,
      awayScore: aScore,
      status: (hScore != null && aScore != null) ? 'Completed' : 'Scheduled',
      venue: enrichedVenue,
      competition: competitionName,
      roundNum: roundLabel,
      contextTeam: effectiveContext,
      rfuTeamId: effectiveRfuId,
      isCustom: true,
    );

    widget.onSave(fixture);
    Navigator.of(context).pop();
  }
}
