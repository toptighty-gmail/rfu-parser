import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ThemeSelectorDialog extends StatefulWidget {
  const ThemeSelectorDialog({super.key});

  @override
  State<ThemeSelectorDialog> createState() => _ThemeSelectorDialogState();
}

class _ThemeSelectorDialogState extends State<ThemeSelectorDialog> {
  late AppThemeMode _selected;

  @override
  void initState() {
    super.initState();
    _selected = AppTheme.currentMode;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _selected.surfaceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _selected.cardBorder, width: 1.2),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _selected.goldAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.palette, color: _selected.goldAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Club & App Theme Styles',
                  style: TextStyle(color: _selected.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Customize colors or revert back to the original theme anytime',
                  style: TextStyle(color: _selected.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...AppThemeMode.values.map((mode) {
              final isCurrent = _selected == mode;
              final isOriginal = mode == AppThemeMode.rfuChampionship;
              final isPlymouthOaks = mode == AppThemeMode.plymouthOaks;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selected = mode;
                    });
                    AppTheme.setTheme(mode);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrent ? mode.surfaceBg : mode.darkBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent ? mode.goldAccent : mode.cardBorder,
                        width: isCurrent ? 2.0 : 1.0,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: mode.goldAccent.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Radio / Check Indicator
                        Icon(
                          isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isCurrent ? mode.goldAccent : mode.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 12),

                        // Title & Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    mode.title,
                                    style: TextStyle(
                                      color: mode.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (isPlymouthOaks) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF041A11),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF10B981)),
                                      ),
                                      child: const Text(
                                        'PLYMOUTH OAKS',
                                        style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                  if (isOriginal) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0B0F19),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.goldAccent),
                                      ),
                                      child: const Text(
                                        'ORIGINAL',
                                        style: TextStyle(color: AppTheme.goldAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                mode.subtitle,
                                style: TextStyle(color: mode.textMuted, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),

                        // Color Palette Preview Swatches
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSwatch(mode.darkBg, 'Dark'),
                            const SizedBox(width: 4),
                            _buildSwatch(mode.surfaceBg, 'Surface'),
                            const SizedBox(width: 4),
                            _buildSwatch(mode.goldAccent, 'Accent'),
                            const SizedBox(width: 4),
                            _buildSwatch(mode.emeraldAccent, 'Sub'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        // One-Click Revert Button
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.rubyAccent,
          ),
          icon: const Icon(Icons.restore, size: 16),
          label: const Text('Revert to Original'),
          onPressed: () {
            setState(() {
              _selected = AppThemeMode.rfuChampionship;
            });
            AppTheme.revertToOriginal();
          },
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _selected.goldAccent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSwatch(Color color, String label) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
    );
  }
}
