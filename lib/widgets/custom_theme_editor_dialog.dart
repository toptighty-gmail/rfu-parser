import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/custom_theme_store.dart';

/// Lets the user edit the colors and font used by [AppThemeMode.custom].
///
/// Edits are staged locally and only written to [CustomThemeStore] (and
/// applied to the live app) when "Apply" is pressed; "Cancel" discards them.
class CustomThemeEditorDialog extends StatefulWidget {
  const CustomThemeEditorDialog({super.key});

  @override
  State<CustomThemeEditorDialog> createState() => _CustomThemeEditorDialogState();
}

class _CustomThemeEditorDialogState extends State<CustomThemeEditorDialog> {
  late Color _primary;
  late Color _accent;
  late Color _background;
  late Color _surface;
  late Color _text;
  late Color _textMuted;
  late Color _border;
  late String _font;

  @override
  void initState() {
    super.initState();
    _primary = CustomThemeStore.primary.value;
    _accent = CustomThemeStore.accent.value;
    _background = CustomThemeStore.background.value;
    _surface = CustomThemeStore.surface.value;
    _text = CustomThemeStore.text.value;
    _textMuted = CustomThemeStore.textMuted.value;
    _border = CustomThemeStore.border.value;
    _font = CustomThemeStore.fontFamily.value;
  }

  void _resetToDefaults() {
    setState(() {
      _primary = CustomThemeStore.defaultPrimary;
      _accent = CustomThemeStore.defaultAccent;
      _background = CustomThemeStore.defaultBackground;
      _surface = CustomThemeStore.defaultSurface;
      _text = CustomThemeStore.defaultText;
      _textMuted = CustomThemeStore.defaultTextMuted;
      _border = CustomThemeStore.defaultBorder;
      _font = CustomThemeStore.defaultFontFamily;
    });
  }

  Future<void> _apply() async {
    await CustomThemeStore.setPrimary(_primary);
    await CustomThemeStore.setAccent(_accent);
    await CustomThemeStore.setBackground(_background);
    await CustomThemeStore.setSurface(_surface);
    await CustomThemeStore.setText(_text);
    await CustomThemeStore.setTextMuted(_textMuted);
    await CustomThemeStore.setBorder(_border);
    await CustomThemeStore.setFontFamily(_font);
    await AppTheme.setTheme(AppThemeMode.custom);
    AppTheme.refreshIfCustom();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _editColor(String label, Color current, ValueChanged<Color> onChanged) async {
    Color staged = current;
    final result = await showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pick $label'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: staged,
              onColorChanged: (c) => staged = c,
              enableAlpha: true,
              hexInputBar: true,
              paletteType: PaletteType.hsvWithHue,
              labelTypes: const [ColorLabelType.rgb, ColorLabelType.hsv],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(staged),
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      setState(() => onChanged(result));
    }
  }

  Widget _colorRow(String label, Color color, ValueChanged<Color> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _editColor(label, color, onChanged),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26, width: 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Text(
                '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
                style: const TextStyle(fontSize: 11, color: Colors.black54, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit, size: 16, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contrastWarning() {
    final textVsBg = CustomThemeStore.contrastRatio(_text, _background);
    final textVsSurface = CustomThemeStore.contrastRatio(_text, _surface);
    final worst = textVsBg < textVsSurface ? textVsBg : textVsSurface;
    if (worst >= 4.5) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Low contrast (${worst.toStringAsFixed(1)}:1) between Text and Background/Surface - '
              'WCAG recommends at least 4.5:1 for body text.',
              style: const TextStyle(fontSize: 11.5, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final textStyle = GoogleFonts.getFont(_font, color: _text, fontSize: 14, fontWeight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview', style: GoogleFonts.getFont(_font, color: _text, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Fixture card sample text', style: textStyle),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(6)),
                  child: Text('BADGE', style: GoogleFonts.getFont(_font, color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
                onPressed: () {},
                child: Text('Primary Button', style: GoogleFonts.getFont(_font, color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text('Muted text sample', style: GoogleFonts.getFont(_font, color: _textMuted, fontSize: 12)),
            ],
          ),
          _contrastWarning(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Customize Theme'),
      content: SizedBox(
        width: 520,
        height: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Colors', style: Theme.of(context).textTheme.titleSmall),
              _colorRow('Primary', _primary, (c) => _primary = c),
              _colorRow('Accent', _accent, (c) => _accent = c),
              _colorRow('Background', _background, (c) => _background = c),
              _colorRow('Surface', _surface, (c) => _surface = c),
              _colorRow('Text', _text, (c) => _text = c),
              _colorRow('Muted Text', _textMuted, (c) => _textMuted = c),
              _colorRow('Border', _border, (c) => _border = c),
              const SizedBox(height: 16),
              Text('Font', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _font,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                items: CustomThemeStore.availableFonts
                    .map((f) => DropdownMenuItem(value: f, child: Text(f, style: GoogleFonts.getFont(f))))
                    .toList(),
                onChanged: (f) {
                  if (f != null) setState(() => _font = f);
                },
              ),
              const SizedBox(height: 16),
              _preview(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.restore, size: 16),
          label: const Text('Reset to Defaults'),
          onPressed: _resetToDefaults,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
