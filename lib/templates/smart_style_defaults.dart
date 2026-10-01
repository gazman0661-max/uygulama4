import 'dart:math';

class SmartStyle {
  final String themeId;
  final String heroLayout;
  final String fontPackageId;
  final String galleryStyle;
  const SmartStyle(this.themeId, this.fontPackageId, this.heroLayout, this.galleryStyle);
}

const Map<String, SmartStyle> kSmartStylePresets = {
  'clean_modern': SmartStyle('clean_light', 'modern_sade', 'centered', 'grid'),
  'clean_split': SmartStyle('clean_light', 'modern_sade', 'split', 'bento'),
  'clean_editorial': SmartStyle('clean_light', 'editorial', 'editorial', 'grid'),
  'clean_classic': SmartStyle('clean_light', 'klasik', 'centered', 'slideshow'),
  'soft_warm': SmartStyle('soft_pastel', 'sicak_elyazisi', 'centered', 'grid'),
  'soft_classic': SmartStyle('soft_pastel', 'klasik', 'split', 'crossfade'),
  'soft_editorial': SmartStyle('soft_pastel', 'editorial', 'editorial', 'bento'),
  'night_diag': SmartStyle('midnight_dark', 'modern_sade', 'diagonal', 'grid'),
  'night_editorial': SmartStyle('midnight_dark', 'editorial', 'editorial', 'crossfade'),
  'night_bold': SmartStyle('midnight_dark', 'kalin_vurgulu', 'split', 'bento'),
  'neon_bold': SmartStyle('neon_cyber', 'kalin_vurgulu', 'diagonal', 'bento'),
  'sunset_warm': SmartStyle('sunset_gradient', 'sicak_elyazisi', 'centered', 'grid'),
  'sunset_bold': SmartStyle('sunset_gradient', 'kalin_vurgulu', 'split', 'grid'),
};

const Map<String, List<String>> kSmartStyleBySector = {
  'kuafor': ['night_diag', 'night_editorial', 'sunset_bold'],
  'beauty_salon': ['soft_editorial', 'soft_warm', 'sunset_warm'],
  'makeup_artist': ['soft_editorial', 'night_editorial', 'sunset_warm'],
  'massage_spa': ['soft_warm', 'soft_classic', 'clean_editorial'],
  'dentist': ['clean_modern', 'clean_split', 'soft_classic'],
  'clinic': ['clean_modern', 'clean_split', 'clean_classic'],
  'dietitian': ['soft_warm', 'clean_split', 'clean_modern'],
  'veterinarian': ['soft_warm', 'clean_split', 'clean_modern'],
  'lawyer': ['clean_classic', 'night_editorial', 'soft_classic'],
  'real_estate': ['clean_split', 'night_diag', 'clean_editorial'],
  'restaurant': ['night_editorial', 'clean_editorial', 'sunset_warm'],
  'kafe': ['soft_warm', 'clean_editorial', 'night_editorial'],
  'bakery': ['soft_warm', 'sunset_warm', 'clean_editorial'],
  'florist': ['soft_editorial', 'soft_warm', 'clean_editorial'],
  'fitness': ['neon_bold', 'night_bold', 'sunset_bold'],
  'personal_trainer': ['neon_bold', 'night_bold', 'sunset_bold'],
  'photographer': ['night_editorial', 'clean_editorial', 'night_diag'],
  'musician_dj': ['neon_bold', 'night_diag', 'night_bold'],
  'portfolio': ['clean_editorial', 'night_editorial', 'clean_split'],
  'boutique_hotel': ['clean_editorial', 'night_editorial', 'soft_classic'],
  'car_wash': ['night_bold', 'clean_split', 'sunset_bold'],
  'auto_repair': ['night_bold', 'clean_modern', 'clean_split'],
  'electrician': ['clean_split', 'clean_modern', 'night_diag'],
  'handyman': ['clean_split', 'clean_modern', 'night_diag'],
  'moving_company': ['clean_split', 'clean_modern', 'night_diag'],
  'cleaning_company': ['soft_warm', 'clean_split', 'clean_modern'],
  'driving_school': ['clean_split', 'sunset_bold', 'clean_modern'],
  'kindergarten': ['sunset_warm', 'soft_warm', 'clean_split'],
  'pet_grooming': ['soft_warm', 'sunset_warm', 'clean_split'],
  'tailor': ['clean_editorial', 'soft_classic', 'night_editorial'],
  'furniture_decor': ['clean_editorial', 'soft_editorial', 'clean_split'],
  'generic_business': [
    'clean_modern', 'clean_split', 'night_diag', 'clean_editorial', 'soft_warm',
  ],
  'bio_link': ['clean_modern', 'night_diag', 'soft_warm', 'neon_bold', 'sunset_warm'],
  'business_card': ['clean_modern', 'clean_classic', 'night_editorial', 'soft_classic'],
};

SmartStyle smartStyleFor(String sectorKey, {Random? random}) {
  final list = kSmartStyleBySector[sectorKey] ?? kSmartStyleBySector['generic_business']!;
  final rnd = random ?? Random();
  final key = list[rnd.nextInt(list.length)];
  return kSmartStylePresets[key]!;
}
