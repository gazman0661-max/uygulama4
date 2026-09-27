import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../localization/app_strings.dart';
import '../services/qt_form_data_codec.dart';
import '../theme/app_theme.dart';

/// 19.09.2026 eklendi (kanka isteği) — kafe/restoran menüsünde ürün başına
/// YASAL BİLGİ (alerjen, kalori, et türü, alkol/domuz içeriği) girişi.
///
/// TASARIM KARARI: Önceki sohbette serbest metin ("Ürün - alerjen:...")
/// yerine ürün başına küçük kart + işaretleme kutucukları önerilmişti —
/// esnafı serbest metinle uğraştırmamak için. Bu widget TAM O deseni
/// uygular: [menuController]'daki metinden (kafe_form_screen.dart /
/// restaurant_form_screen.dart > _parseMenu ile AYNI format) canlı olarak
/// ürün listesini türetir, her ürün için katlanır bir kart gösterir.
///
/// VERİ MODELİ: Map<String, Map<String,dynamic>> — anahtar
/// "kategori|||ürün" (trim+lowercase; aynı isimli 2. ürün "…###2"), değer:
///   {'allergens': List<String>, 'calories': String, 'meatType': String,
///    'alcohol': bool, 'pork': bool, 'altPork': bool(eski kayıt)}
/// Anahtar üretimi ve kanonik şekil qt_form_data_codec.dart'ta
/// (qtMenuLegalKey / qtNormalizeMenuLegalEntry) — burada TEKRAR yazılmaz.
///
/// ABONELİK KİLİDİ: [locked] true ise liste IgnorePointer ile devre dışı
/// kalır ve üzerine kilit rozeti + "Abonelik planlarını gör" CTA'sı biner
/// (bkz. [onUnlockTap] -> showSubscriptionPlansScreen). Daha önce
/// (abonelikken) girilmiş veri varsa KAYBOLMAZ, sadece salt-okunur görünür —
/// aboneliği biten esnaf verisini kaybetmez, sadece yeniden abone olana
/// kadar siteye basılmaz (bkz. _generate akışındaki hasActiveSubscription
/// kontrolü, qtMergeMenuLegalInfo çağrılmadan önce).
class MenuLegalInfoField extends StatefulWidget {
  const MenuLegalInfoField({
    super.key,
    required this.menuController,
    required this.parseMenu,
    required this.onChanged,
    required this.locked,
    required this.onUnlockTap,
    this.initialLegalInfo,
  });

  /// Menü metin kutusunun controller'ı — canlı ürün listesi türetmek için
  /// dinlenir (bkz. initState/dispose).
  final TextEditingController menuController;

  /// _parseMenu ile AYNI imza — ekran zaten sahip olduğu parser'ı geçirir,
  /// böylece format burada TEKRAR yazılmaz (tek kaynak: ekranın kendi parser'ı).
  final List<Map<String, dynamic>> Function(String) parseMenu;

  final Map<String, dynamic>? initialLegalInfo;
  final ValueChanged<Map<String, dynamic>> onChanged;

  final bool locked;
  final VoidCallback onUnlockTap;

  /// 14 alerjen (AB listesi; Türk gıda etiketleme mevzuatı da aynı
  /// listeyi baz alır — yayına almadan güncel yönetmelikten doğrula).
  static const List<String> allergenOptions = [
    'Gluten',
    'Süt',
    'Yumurta',
    'Yer Fıstığı',
    'Kuruyemiş',
    'Soya',
    'Balık',
    'Kabuklu Deniz Ürünleri',
    'Yumuşakçalar',
    'Susam',
    'Kereviz',
    'Hardal',
    'Acı Bakla',
    'Sülfit',
  ];

  static const List<String> meatTypeOptions = [
    'Vejetaryen',
    'Vegan',
    'Dana',
    'Kuzu',
    'Tavuk',
    'Balık',
    'Diğer',
  ];

  @override
  State<MenuLegalInfoField> createState() => _MenuLegalInfoFieldState();
}

class _MenuLegalInfoFieldState extends State<MenuLegalInfoField> {
  late Map<String, Map<String, dynamic>> _data;
  final Set<String> _expanded = {};

  /// Ürün başına kalori controller'ı — build'de HER SEFERİNDE yeni controller
  /// üretmek imleci zıplatıyordu ve controller sızdırıyordu; artık ürün
  /// anahtarına göre bir kez üretilip dispose'ta temizleniyor.
  final Map<String, TextEditingController> _calorieCtrls = {};

  @override
  void initState() {
    super.initState();
    _data = _cloneInitial();
    widget.menuController.addListener(_onMenuTextChanged);
  }

  @override
  void dispose() {
    widget.menuController.removeListener(_onMenuTextChanged);
    for (final c in _calorieCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Map<String, dynamic>> _cloneInitial() {
    final initial = widget.initialLegalInfo;
    if (initial == null) return {};
    final out = <String, Map<String, dynamic>>{};
    initial.forEach((k, v) {
      if (v is Map) out[k.toString()] = qtNormalizeMenuLegalEntry(v);
    });
    return out;
  }

  void _onMenuTextChanged() {
    // Ürün isimleri/kategoriler değiştikçe kart listesi güncellensin diye —
    // veri kaybı yok (anahtarları isimle eşleşmeyen eski girişler sadece
    // görünmez olur, silinmez; kullanıcı ismi geri değiştirirse geri gelir).
    if (mounted) setState(() {});
  }

  Map<String, dynamic> _entry(String key) =>
      _data[key] ?? qtNormalizeMenuLegalEntry(const {});

  void _patch(String key, Map<String, dynamic> changes) {
    final next = Map<String, dynamic>.from(_entry(key))..addAll(changes);
    setState(() => _data[key] = next);
    widget.onChanged(_data);
  }

  String _summary(BuildContext context, Map<String, dynamic>? info) {
    if (!qtMenuLegalEntryHasData(info)) return t(context, 'Dokunup yasal bilgi ekle');
    final parts = <String>[];
    final allergens = info!['allergens'];
    if (allergens is List && allergens.isNotEmpty) {
      parts.add(allergens.map((a) => t(context, a.toString())).join(', '));
    }
    final cal = info['calories']?.toString() ?? '';
    if (cal.isNotEmpty) parts.add('$cal kcal');
    final meat = info['meatType']?.toString() ?? '';
    if (meat.isNotEmpty) parts.add(t(context, meat));
    if (info['alcohol'] == true) parts.add(t(context, 'Alkol içerir'));
    if (info['pork'] == true) parts.add(t(context, 'Domuz içerir'));
    if (info['altPork'] == true) parts.add(t(context, 'Alkol/Domuz'));
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.parseMenu(widget.menuController.text);

    // Anahtarlar qtMergeMenuLegalInfo ile AYNI sırada/sayımla üretilir
    // (aynı kategori+isimli tekrarlar "###2" alır; boş isimler atlanır).
    final seen = <String, int>{};
    final listChildren = <Widget>[];
    var tileCount = 0;
    for (final cat in categories) {
      final catTitle = (cat['title'] as String?) ?? '';
      final tiles = <Widget>[];
      for (final rawItem in (cat['items'] as List)) {
        final name = ((rawItem as Map)['name'] as String?) ?? '';
        if (name.trim().isEmpty) continue;
        final base = qtMenuLegalKey(catTitle, name);
        final n = seen[base] ?? 0;
        seen[base] = n + 1;
        tiles.add(_buildItemTile(context, qtMenuLegalKey(catTitle, name, n), name, n));
      }
      if (tiles.isEmpty) continue;
      tileCount += tiles.length;
      listChildren.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
          child: Text(
            catTitle,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      );
      listChildren.addAll(tiles);
    }

    final content = Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: tileCount == 0
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                t(context, 'Önce yukarıya menü ürünlerini ekle — her ürün için ayrı ayrı burada alerjen/kalori/içerik bilgisi girebilirsin.'),
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
              ),
            )
          : Column(children: listChildren),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t(context, 'Ürün Bazlı Yasal Bilgiler (Alerjen / Kalori / İçerik)'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (widget.locked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 13, color: AppTheme.accentOrange),
                    const SizedBox(width: 4),
                    Text(
                      t(context, 'Abonelikte'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accentOrange),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          t(context, 'Gıda Bilgilendirme Yönetmeliği kapsamında müşterilerin görmesi gereken içerik/alerjen bilgisini ürün altında gösterir. Hangi bilgilerin zorunlu olduğunu yayına almadan önce kendi işletme türün için doğrula.'),
          style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            IgnorePointer(ignoring: widget.locked, child: content),
            if (widget.locked)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2.4, sigmaY: 2.4),
                    child: Material(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.55)
                          : Colors.white.withOpacity(0.72),
                      child: InkWell(
                        onTap: widget.onUnlockTap,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_outline, size: 26, color: AppTheme.accentOrange),
                              const SizedBox(height: 6),
                              Text(
                                t(context, 'Bu özellik abonelikle açılır'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: widget.onUnlockTap,
                                child: Text(t(context, 'Abonelik planlarını gör')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemTile(BuildContext context, String key, String name, int occurrence) {
    final info = _data[key];
    final tagged = qtMenuLegalEntryHasData(info);
    final isOpen = _expanded.contains(key);
    // Aynı isimli tekrarlar listede ayırt edilebilsin: "Latte (2)".
    final title = occurrence > 0 ? '$name (${occurrence + 1})' : name;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tagged
            ? AppTheme.accentGreenLink.withOpacity(0.08)
            : Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkInputBg
                : AppColors.lightInputBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Icon(
              tagged ? Icons.check_circle : Icons.info_outline,
              color: tagged ? AppTheme.accentGreenLink : Theme.of(context).disabledColor,
              size: 20,
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              _summary(context, info),
              style: TextStyle(fontSize: 12, color: tagged ? null : Theme.of(context).disabledColor),
            ),
            trailing: Icon(isOpen ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() {
              if (isOpen) {
                _expanded.remove(key);
              } else {
                _expanded.add(key);
              }
            }),
          ),
          if (isOpen) _buildEditor(context, key),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context, String key) {
    final entry = _entry(key);
    final allergens = List<String>.from(entry['allergens'] as List);
    final storedMeat = entry['meatType']?.toString() ?? '';
    // Listede olmayan (bozuk/eski) bir değer DropdownButton'ı assert ile
    // düşürür — o durumda "Seçilmedi" göster (veri yine de korunur).
    final meatValue = MenuLegalInfoField.meatTypeOptions.contains(storedMeat) ? storedMeat : '';
    final caloriesCtrl = _calorieCtrls.putIfAbsent(
      key,
      () => TextEditingController(text: entry['calories']?.toString() ?? ''),
    );
    final hasLegacyAltPork = entry['altPork'] == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t(context, 'Alerjenler'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in MenuLegalInfoField.allergenOptions)
                FilterChip(
                  label: Text(t(context, a), style: const TextStyle(fontSize: 12)),
                  selected: allergens.contains(a),
                  visualDensity: VisualDensity.compact,
                  onSelected: (v) {
                    final next = List<String>.from(allergens);
                    if (v) {
                      if (!next.contains(a)) next.add(a);
                    } else {
                      next.remove(a);
                    }
                    // Seçim sırası değil liste sırası — site çıktısı sabit kalsın.
                    next.sort((x, y) => MenuLegalInfoField.allergenOptions
                        .indexOf(x)
                        .compareTo(MenuLegalInfoField.allergenOptions.indexOf(y)));
                    _patch(key, {'allergens': next});
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: caloriesCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  decoration: InputDecoration(
                    labelText: t(context, 'Kalori (kcal)'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => _patch(key, {'calories': v.trim()}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  // Değer dışarıdan (temizle/seç) değişince alanın yeniden
                  // kurulması için değeri key'e koyuyoruz.
                  key: ValueKey('meat|$key|$meatValue'),
                  value: meatValue,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: t(context, 'Et türü'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(
                        t(context, 'Seçilmedi'),
                        style: TextStyle(fontSize: 13, color: Theme.of(context).disabledColor),
                      ),
                    ),
                    for (final m in MenuLegalInfoField.meatTypeOptions)
                      DropdownMenuItem(value: m, child: Text(t(context, m), style: const TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) => _patch(key, {'meatType': v ?? ''}),
                ),
              ),
            ],
          ),
          if (hasLegacyAltPork)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                t(context, 'Bu ürün eski kayıtta tek "alkol/domuz" seçeneğiyle işaretlenmiş — lütfen aşağıda ayrı ayrı işaretle.'),
                style: const TextStyle(fontSize: 12, color: AppTheme.accentOrange),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: entry['alcohol'] == true,
            title: Text(t(context, 'Alkol içerir'), style: const TextStyle(fontSize: 13)),
            // Ayrı seçim yapılınca eski birleşik işaret düşer.
            onChanged: (v) => _patch(key, {'alcohol': v, 'altPork': false}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: entry['pork'] == true,
            title: Text(t(context, 'Domuz içerir'), style: const TextStyle(fontSize: 13)),
            onChanged: (v) => _patch(key, {'pork': v, 'altPork': false}),
          ),
        ],
      ),
    );
  }
}
