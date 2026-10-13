import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../templates/html/section_registry.dart';

/// 15.09.2026 eklendi (kanka isteği) — "Bölüm Sırala/Gizle" alanı.
///
/// Her sektör formunun generator'ı artık ORTA blokları (hero VE
/// iletişim/talep formu HARİÇ — bunlar kasıtlı olarak sabit tutuluyor,
/// bkz. section_registry.dart dokümanı) sabit sırada değil, bu widget'tan
/// gelen `sectionOrder` listesine göre diziyor. Kullanıcı bir bölümün
/// checkbox'ını kapatırsa o blok HTML'e hiç yazılmaz (gizlenir);
/// sürükleyip bırakırsa sırası değişir.
///
/// `initialOrder` null/boş verilirse TÜM bölümler açık ve
/// `defaultSectionIds` sırasında başlar (mevcut/eski projelerle birebir
/// aynı görünüm — geriye dönük uyumlu).
///
/// Kullanım (bkz. kuafor_form_screen.dart):
/// ```dart
/// SectionOrderField(
///   defaultSectionIds: kBusinessSiteDefaultOrder,
///   initialOrder: _sectionOrder,
///   onChanged: (order) => _sectionOrder = order,
/// )
/// ```
/// ve generator çağrısına `sectionOrder: _sectionOrder` eklemek yeterli.
class SectionOrderField extends StatefulWidget {
  const SectionOrderField({
    super.key,
    required this.defaultSectionIds,
    required this.onChanged,
    this.initialOrder,
    this.label = 'Bölüm Sırası ve Görünürlüğü',
  });

  /// İlgili generator ailesinin TÜM olası orta blok id'leri, varsayılan
  /// sırasıyla (bkz. section_registry.dart — kBusinessSiteDefaultOrder,
  /// kCafeDefaultOrder, kClinicDefaultOrder, kPortfolioDefaultOrder,
  /// kExtendedBusinessDefaultOrder, kGenericBusinessDefaultOrder).
  final List<String> defaultSectionIds;

  /// Formun mevcut (kaydedilmiş veya kullanıcının bu oturumda değiştirdiği)
  /// sırası. Null/boş ise tüm bölümler açık, varsayılan sırada gösterilir.
  final List<String>? initialOrder;

  final String label;

  /// Kullanıcı her değişiklikte (checkbox veya sürükleme) çağrılır;
  /// sadece AÇIK bölümlerin id'lerini, güncel sırasıyla döner — doğrudan
  /// generator'ın `sectionOrder` parametresine geçilebilir.
  final ValueChanged<List<String>> onChanged;

  @override
  State<SectionOrderField> createState() => _SectionOrderFieldState();
}

class _SectionOrderFieldState extends State<SectionOrderField> {
  // Görünüm sırasında TÜM id'ler (açık + kapalı bir arada) — sürükleme
  // listenin tamamında yapılır, kapalı satırlar sadece checkbox'ı boş
  // görünür, listeden çıkmaz (kullanıcı istediği an tekrar açabilsin).
  late List<String> _allIds;
  late Set<String> _enabled;

  @override
  void initState() {
    super.initState();
    final saved = widget.initialOrder;
    if (saved == null || saved.isEmpty) {
      _allIds = List.of(widget.defaultSectionIds);
      _enabled = widget.defaultSectionIds.toSet();
    } else {
      // Kaydedilmiş sıradaki id'ler önce (kullanıcının seçtiği sıra
      // korunur), sonra defaultSectionIds'ta olup kaydedilmiş listede
      // olmayanlar (örn. sonradan eklenen bir bölüm türü) sona, KAPALI
      // olarak eklenir — eski projelerde yeni bölüm aniden belirmesin.
      final rest = widget.defaultSectionIds.where((id) => !saved.contains(id));
      _allIds = [...saved.where(widget.defaultSectionIds.contains), ...rest];
      _enabled = saved.toSet();
    }
  }

  void _emit() {
    widget.onChanged(_allIds.where(_enabled.contains).toList());
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    final lang = isEnglish(context) ? 'en' : 'tr';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, widget.label), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          t(context, 'Kapatılan bölüm sitede hiç görünmez. Tutup sürükleyerek sırasını değiştirebilirsin.'),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final id = _allIds.removeAt(oldIndex);
                _allIds.insert(newIndex, id);
              });
              _emit();
            },
            children: [
              for (int i = 0; i < _allIds.length; i++)
                Container(
                  key: ValueKey(_allIds[i]),
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.transparent : Colors.grey.shade50,
                    border: i == _allIds.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: CheckboxListTile(
                    value: _enabled.contains(_allIds[i]),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    title: Text(sectionLabel(_allIds[i], lang)),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _enabled.add(_allIds[i]);
                        } else {
                          _enabled.remove(_allIds[i]);
                        }
                      });
                      _emit();
                    },
                    secondary: ReorderableDragStartListener(
                      index: i,
                      child: Icon(Icons.drag_handle, color: Colors.grey.shade500),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
