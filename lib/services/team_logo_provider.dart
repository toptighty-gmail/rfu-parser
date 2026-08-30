import 'dart:convert';

class TeamLogoProvider {
  // Predefined distinctive team crests in optimized SVG Data-URIs
  static final Map<String, String> _predefinedLogos = {
    'plymstock': _svgBadge(
      primaryColor: '#005A36', // British Racing Green
      secondaryColor: '#D4AF37', // Gold
      text: 'OAKS',
      iconSvg: '<path d="M12 4C8 8 7 12 12 18C17 12 16 8 12 4Z" fill="#D4AF37"/>',
    ),
    'torquay': _svgBadge(
      primaryColor: '#002B7F', // Navy Blue
      secondaryColor: '#FFD700', // Gold
      text: 'TARCS',
      iconSvg: '<circle cx="12" cy="11" r="6" stroke="#FFD700" stroke-width="2" fill="none"/>',
    ),
    'withycombe': _svgBadge(
      primaryColor: '#1B4D3E', // Forest Green
      secondaryColor: '#000000', // Black
      textColor: '#FFFFFF',
      text: 'WITHY',
      iconSvg: '<path d="M6 6L12 18L18 6" stroke="#FFD700" stroke-width="2.5" fill="none"/>',
    ),
    'honiton': _svgBadge(
      primaryColor: '#003399', // Blue
      secondaryColor: '#FF9900', // Amber
      text: 'HON',
      iconSvg: '<path d="M12 5L6 18H18L12 5Z" fill="#FF9900"/>',
    ),
    'south molton': _svgBadge(
      primaryColor: '#C8102E', // Red
      secondaryColor: '#FFFFFF', // White
      text: 'SMRFC',
      iconSvg: '<circle cx="12" cy="11" r="5" fill="#FFFFFF"/>',
    ),
    'barnstaple': _svgBadge(
      primaryColor: '#D21034', // Red
      secondaryColor: '#FFFFFF', // White
      text: 'BARUM',
      iconSvg: '<rect x="7" y="7" width="10" height="8" rx="2" fill="#FFFFFF"/>',
    ),
    'exmouth': _svgBadge(
      primaryColor: '#0038A8', // Royal Blue
      secondaryColor: '#FFFFFF', // White
      text: 'COCKLES',
      iconSvg: '<path d="M6 14C6 9 18 9 18 14H6Z" fill="#FFFFFF"/>',
    ),
    'brixham': _svgBadge(
      primaryColor: '#0C2340', // Navy
      secondaryColor: '#DAA520', // Gold
      text: 'FISHER',
      iconSvg: '<path d="M5 12L12 6L19 12L12 18L5 12Z" fill="#DAA520"/>',
    ),
    'tavistock': _svgBadge(
      primaryColor: '#B30000', // Crimson
      secondaryColor: '#000000', // Black
      textColor: '#FFFFFF',
      text: 'TAVY',
      iconSvg: '<path d="M12 4V18M6 10H18" stroke="#FFFFFF" stroke-width="2.5"/>',
    ),
    'exeter saracens': _svgBadge(
      primaryColor: '#000000', // Black
      secondaryColor: '#FFBF00', // Amber
      textColor: '#FFBF00',
      text: 'SARRIES',
      iconSvg: '<path d="M12 5C8 9 8 13 12 17C16 13 16 9 12 5Z" fill="#FFBF00"/>',
    ),
    'plymouth argaum': _svgBadge(
      primaryColor: '#006400', // Green
      secondaryColor: '#FFFFFF', // White
      text: 'ARGAUM',
      iconSvg: '<path d="M6 6H18V16H6Z" stroke="#FFFFFF" stroke-width="2" fill="none"/>',
    ),
    'opms': _svgBadge(
      primaryColor: '#001F3F', // Navy
      secondaryColor: '#C8102E', // Red
      text: 'OPMs',
      iconSvg: '<circle cx="12" cy="11" r="6" stroke="#C8102E" stroke-width="2" fill="none"/>',
    ),
    'opm': _svgBadge(
      primaryColor: '#001F3F', // Navy
      secondaryColor: '#C8102E', // Red
      text: 'OPMs',
      iconSvg: '<circle cx="12" cy="11" r="6" stroke="#C8102E" stroke-width="2" fill="none"/>',
    ),
    'old plymothian': _svgBadge(
      primaryColor: '#001F3F', // Navy
      secondaryColor: '#C8102E', // Red
      text: 'OPMs',
      iconSvg: '<circle cx="12" cy="11" r="6" stroke="#C8102E" stroke-width="2" fill="none"/>',
    ),
    'bideford': _svgBadge(
      primaryColor: '#C8102E', // Red
      secondaryColor: '#FFFFFF', // White
      text: 'BIDE',
      iconSvg: '<path d="M12 5L18 16H6L12 5Z" fill="#FFFFFF"/>',
    ),
    'kingsbridge': _svgBadge(
      primaryColor: '#002B7F', // Navy
      secondaryColor: '#87CEEB', // Sky Blue
      text: 'KINGS',
      iconSvg: '<path d="M12 4L15 9L20 10L16 14L17 19L12 16L7 19L8 14L4 10L9 9L12 4Z" fill="#87CEEB"/>',
    ),
    'tiverton': _svgBadge(
      primaryColor: '#990000', // Dark Red
      secondaryColor: '#FFCC00', // Amber
      text: 'TIVVY',
      iconSvg: '<rect x="6" y="6" width="12" height="10" rx="2" fill="#FFCC00"/>',
    ),
    'cullompton': _svgBadge(
      primaryColor: '#800000', // Maroon
      secondaryColor: '#FFD700', // Gold
      text: 'CULLY',
      iconSvg: '<path d="M6 12C6 7 18 7 18 12C18 17 6 17 6 12Z" fill="#FFD700"/>',
    ),
    'teignmouth': _svgBadge(
      primaryColor: '#001A4E', // Navy
      secondaryColor: '#FFFFFF', // White
      text: 'TEIGNS',
      iconSvg: '<path d="M5 12H19M12 5V19" stroke="#FFFFFF" stroke-width="2.5"/>',
    ),
    'sidmouth': _svgBadge(
      primaryColor: '#1B4D3E', // Forest Green
      secondaryColor: '#000000', // Black
      textColor: '#FFFFFF',
      text: 'SID',
      iconSvg: '<circle cx="12" cy="11" r="5" fill="#FFFFFF"/>',
    ),
    'crediton': _svgBadge(
      primaryColor: '#FF9900', // Amber
      secondaryColor: '#000000', // Black
      textColor: '#000000',
      text: 'KIRTON',
      iconSvg: '<path d="M6 6L18 18M6 18L18 6" stroke="#000000" stroke-width="2.5"/>',
    ),
    'newton abbot': _svgBadge(
      primaryColor: '#FFFFFF', // All Whites
      secondaryColor: '#002B7F', // Navy
      textColor: '#002B7F',
      text: 'ALL WHITES',
      iconSvg: '<circle cx="12" cy="11" r="6" stroke="#002B7F" stroke-width="2" fill="#FFFFFF"/>',
    ),
    'saltash': _svgBadge(
      primaryColor: '#B31B1B', // Cardinal Red
      secondaryColor: '#FFFFFF', // White
      textColor: '#FFFFFF',
      text: 'ASHES',
      iconSvg: '<path d="M12 4L6 18H18L12 4Z" fill="#FFFFFF"/><circle cx="12" cy="14" r="2" fill="#B31B1B"/>',
    ),
    'salatsh': _svgBadge(
      primaryColor: '#B31B1B', // Cardinal Red
      secondaryColor: '#FFFFFF', // White
      textColor: '#FFFFFF',
      text: 'ASHES',
      iconSvg: '<path d="M12 4L6 18H18L12 4Z" fill="#FFFFFF"/><circle cx="12" cy="14" r="2" fill="#B31B1B"/>',
    ),
    'ivybridge': _svgBadge(
      primaryColor: '#006400', // Green
      secondaryColor: '#FFD700', // Gold
      text: 'BRIDGE',
      iconSvg: '<path d="M6 14C6 8 18 8 18 14" stroke="#FFD700" stroke-width="2.5" fill="none"/>',
    ),
    'devonport': _svgBadge(
      primaryColor: '#002B7F', // Navy
      secondaryColor: '#FFFFFF', // White
      text: 'SERVICES',
      iconSvg: '<circle cx="12" cy="11" r="6" stroke="#FFFFFF" stroke-width="2" fill="none"/>',
    ),
    'topsham': _svgBadge(
      primaryColor: '#006400', // Green
      secondaryColor: '#FFFFFF', // White
      text: 'TOPS',
      iconSvg: '<path d="M12 4L19 16H5L12 4Z" fill="#FFFFFF"/>',
    ),
    'mannamedian': _svgBadge(
      primaryColor: '#001F3F', // Navy
      secondaryColor: '#C8102E', // Red
      text: 'OPM',
      iconSvg: '<circle cx="12" cy="11" r="6" stroke="#C8102E" stroke-width="2" fill="none"/>',
    ),
    'harlequins': _svgBadge(
      primaryColor: '#005A36',
      secondaryColor: '#990000',
      text: 'QUINS',
      iconSvg: '<path d="M12 4L18 12L12 20L6 12Z" fill="#990000" stroke="#FFFFFF" stroke-width="1"/>',
    ),
    'bath': _svgBadge(
      primaryColor: '#002B7F',
      secondaryColor: '#000000',
      text: 'BATH',
      iconSvg: '<circle cx="12" cy="11" r="6" stroke="#DAA520" stroke-width="2" fill="none"/>',
    ),
    'saracens': _svgBadge(
      primaryColor: '#000000',
      secondaryColor: '#C8102E',
      text: 'SARRIES',
      iconSvg: '<path d="M12 4L15 9L20 10L16 14L17 19L12 16L7 19L8 14L4 10L9 9L12 4Z" fill="#C8102E"/>',
    ),
    'leicester': _svgBadge(
      primaryColor: '#005A36',
      secondaryColor: '#C8102E',
      text: 'TIGERS',
      iconSvg: '<path d="M6 6L12 18L18 6" stroke="#C8102E" stroke-width="2.5" fill="none"/>',
    ),
    'exeter chiefs': _svgBadge(
      primaryColor: '#000000',
      secondaryColor: '#DAA520',
      text: 'CHIEFS',
      iconSvg: '<path d="M12 5C8 9 8 13 12 17C16 13 16 9 12 5Z" fill="#DAA520"/>',
    ),
    'gloucester': _svgBadge(
      primaryColor: '#C8102E',
      secondaryColor: '#FFFFFF',
      text: 'GLAWS',
      iconSvg: '<path d="M12 4L19 16H5L12 4Z" fill="#FFFFFF"/>',
    ),
    'northampton': _svgBadge(
      primaryColor: '#005A36',
      secondaryColor: '#000000',
      text: 'SAINTS',
      iconSvg: '<circle cx="12" cy="11" r="6" stroke="#DAA520" stroke-width="2" fill="none"/>',
    ),
    'bristol': _svgBadge(
      primaryColor: '#002B7F',
      secondaryColor: '#C8102E',
      text: 'BEARS',
      iconSvg: '<circle cx="12" cy="11" r="6" fill="#002B7F" stroke="#FFFFFF" stroke-width="1.5"/>',
    ),
    'sale': _svgBadge(
      primaryColor: '#002B7F',
      secondaryColor: '#FFFFFF',
      text: 'SHARKS',
      iconSvg: '<path d="M5 12L12 6L19 12L12 18L5 12Z" fill="#FFFFFF"/>',
    ),
    'newcastle': _svgBadge(
      primaryColor: '#000000',
      secondaryColor: '#FFFFFF',
      text: 'FALCONS',
      iconSvg: '<path d="M6 14C6 9 18 9 18 14H6Z" fill="#FFFFFF"/>',
    ),
  };

  static String _svgBadge({
    required String primaryColor,
    required String secondaryColor,
    String textColor = '#FFFFFF',
    required String text,
    required String iconSvg,
  }) {
    final svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <defs>
    <linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="$primaryColor" />
      <stop offset="100%" stop-color="$primaryColor" stop-opacity="0.85" />
    </linearGradient>
  </defs>
  <path d="M24 2C35 2 44 8 44 18C44 32 24 46 24 46C24 46 4 32 4 18C4 8 13 2 24 2Z" fill="url(#g)" stroke="$secondaryColor" stroke-width="2"/>
  <g transform="translate(12, 6) scale(1)">
    $iconSvg
  </g>
  <text x="24" y="38" text-anchor="middle" font-family="Arial, sans-serif" font-weight="900" font-size="7.5" fill="$textColor" letter-spacing="0.5">$text</text>
</svg>
''';
    final base64 = base64Encode(utf8.encode(svg));
    return 'data:image/svg+xml;base64,$base64';
  }

  static String? getPredefinedLogo(String teamName) {
    final clean = teamName.toLowerCase().trim();
    for (var entry in _predefinedLogos.entries) {
      if (clean.contains(entry.key)) {
        return entry.value;
      }
    }
    // Generate an automatic club shield badge with club initial
    final initials = clean.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(3).join();
    return _generateGenericBadge(initials.isNotEmpty ? initials : 'RFC');
  }

  static String _generateGenericBadge(String initials) {
    final svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#1A2234" />
      <stop offset="100%" stop-color="#0E131F" />
    </linearGradient>
  </defs>
  <path d="M24 2C35 2 44 8 44 18C44 32 24 46 24 46C24 46 4 32 4 18C4 8 13 2 24 2Z" fill="url(#bg)" stroke="#D4AF37" stroke-width="2"/>
  <circle cx="24" cy="18" r="10" fill="#D4AF37" fill-opacity="0.15" stroke="#D4AF37" stroke-width="1"/>
  <text x="24" y="22" text-anchor="middle" font-family="Arial, sans-serif" font-weight="900" font-size="11" fill="#D4AF37">$initials</text>
  <text x="24" y="38" text-anchor="middle" font-family="Arial, sans-serif" font-weight="bold" font-size="6.5" fill="#8E9BB0">RFC</text>
</svg>
''';
    final base64 = base64Encode(utf8.encode(svg));
    return 'data:image/svg+xml;base64,$base64';
  }
}
