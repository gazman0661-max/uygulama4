library google_font_catalog;

const List<String> kGoogleFontCatalog = [
  'Inter', 'Roboto', 'Open Sans', 'Lato', 'Montserrat', 'Poppins', 'Nunito',
  'Source Sans 3', 'Work Sans', 'Rubik', 'Manrope', 'Karla', 'DM Sans',
  'Mulish', 'Raleway', 'Quicksand', 'Sora', 'Outfit', 'Figtree', 'Urbanist',
  'Space Grotesk', 'IBM Plex Sans', 'Barlow', 'Josefin Sans', 'Cabin',
  'Playfair Display', 'Merriweather', 'Fraunces', 'Lora', 'Libre Baskerville',
  'PT Serif', 'Crimson Text', 'Cormorant Garamond', 'Bitter', 'Spectral',
  'EB Garamond', 'Source Serif 4', 'Noto Serif',
  'Oswald', 'Bebas Neue', 'Archivo', 'Anton', 'Big Shoulders Display',
  'League Spartan', 'Unbounded',
  'Dancing Script', 'Pacifico', 'Caveat', 'Satisfy', 'Great Vibes',
  'Sacramento', 'Playfair Display SC',
  'JetBrains Mono', 'Space Mono', 'IBM Plex Mono', 'Roboto Mono',
];

const int kMaxExtraFontsPerSite = 3;

const Set<String> _serifFonts = {
  'Playfair Display', 'Merriweather', 'Fraunces', 'Lora', 'Libre Baskerville',
  'PT Serif', 'Crimson Text', 'Cormorant Garamond', 'Bitter', 'Spectral',
  'EB Garamond', 'Source Serif 4', 'Noto Serif', 'Playfair Display SC',
};
const Set<String> _scriptFonts = {
  'Dancing Script', 'Pacifico', 'Caveat', 'Satisfy', 'Great Vibes', 'Sacramento',
};
const Set<String> _monoFonts = {
  'JetBrains Mono', 'Space Mono', 'IBM Plex Mono', 'Roboto Mono',
};

String fontSlug(String name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

final Map<String, String> _slugToName = {
  for (final n in kGoogleFontCatalog) fontSlug(n): n,
};

String? fontNameFromSlug(String? slug) => slug == null ? null : _slugToName[slug.toLowerCase()];

String fontFamilyCss(String name) {
  final fb = _monoFonts.contains(name)
      ? 'monospace'
      : _scriptFonts.contains(name)
          ? 'cursive'
          : _serifFonts.contains(name)
              ? 'serif'
              : 'sans-serif';
  return "'$name',$fb";
}

String googleFontsLinkTags(Iterable<String> names) {
  final fams = names.where(_slugToName.containsValue).toSet();
  if (fams.isEmpty) return '';
  final q = fams.map((n) => 'family=${n.replaceAll(' ', '+')}').join('&');
  return '<link rel="preconnect" href="https://fonts.googleapis.com">\n'
      '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
      '<link id="sitora-extra-fonts" rel="stylesheet" href="https://fonts.googleapis.com/css2?$q&display=swap">';
}
