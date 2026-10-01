class FreePlanRestrictionService {
  FreePlanRestrictionService._();

  static bool isPremiumGeneration = true;

  static bool _generationInProgress = false;

  static T runGeneration<T>(bool isPremium, T Function() body) {
    assert(
      !_generationInProgress,
      'FreePlanRestrictionService.runGeneration iç içe çağrıldı — '
      'isPremiumGeneration flag\'i senkron/tek-akış varsayımıyla tasarlandı, '
      'bu varsayım burada ihlal edildi.',
    );
    final previous = isPremiumGeneration;
    _generationInProgress = true;
    isPremiumGeneration = isPremium;
    try {
      return body();
    } finally {
      isPremiumGeneration = previous;
      _generationInProgress = false;
    }
  }

  static String strip(String html, {required bool isPremium}) {
    if (isPremium) return html;
    var out = _stripSection(html, 'map-section');
    out = _stripLeadForm(out);
    return out;
  }

  static Map<String, String> stripFromFiles(
    Map<String, String> files, {
    required bool isPremium,
  }) {
    if (isPremium) return files;
    return files.map((name, content) {
      if (!name.toLowerCase().endsWith('.html')) return MapEntry(name, content);
      return MapEntry(name, strip(content, isPremium: isPremium));
    });
  }

  static final RegExp _leadFormRe = RegExp(
    r'<form id="sitora-lead-form".*?</script>',
    dotAll: true,
  );

  static String _stripLeadForm(String html) => html.replaceAll(_leadFormRe, '');

  static String _stripSection(String html, String sectionClass) {
    final re = RegExp(
      '<section class="section $sectionClass">.*?</section>',
      dotAll: true,
    );
    return html.replaceAll(re, '');
  }
}
