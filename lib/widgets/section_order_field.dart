import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../theme/app_theme.dart';

/// 05.09.2026 eklendi (kanka isteği) — "kullanıcılar form doldurma
/// ekranında kutuları sürükle bırak tarzı yerlerini değiştirip
/// istedikleri gibi sıralayıp site üretseler nasıl olur?"
///
/// Bu widget, üretilen sitedeki belirli bir grup bölümün (örn. Galeri,
/// Video, Yorumlar, SSS, Hero, İletişim...) HANGİ SIRAYLA basılacağını
/// kullanıcının sürükle-bırakla belirlemesini sağlar. 05.09.2026 değişti
/// (kanka isteği, "tam özgürlük olsun") — Hero ve İletişim/Footer ARTIK
/// bu widget'a diğer bölümlerle BİRLİKTE verilebilir, hiçbir bölüm
/// otomatik olarak sabit tutulmuyor; hangi bölümlerin taşınabilir
/// olacağına çağıran ekran karar verir.
///
/// Kullanım: bir form ekranında bir `List<String> order` state alanı
/// tutulur (varsayılanı, o generator'ın MEVCUT sabit sırasıyla AYNI —
/// böylece eski kayıtlı formlar/siteler ETKİLENMEZ), bu widget'a
/// [order] + [onChanged] verilir, sonuç `_captureFormData`/generator
/// çağrısına `sectionOrder: order` olarak geçirilir (bkz.
/// real_estate_html_generator.dart > sectionOrder parametresi).
class SectionOrderField extends StatefulWidget {
  const SectionOrderField({
    super.key,
    required this.title,
    required this.helperText,
    required this.sectionLabels,
    required this.order,
    required this.onChanged,
  });

  final String title;
  final String helperText;

  /// {'gallery': 'Galeri', 'video': 'Video', ...} — TÜRKÇE ham metin,
  /// gösterimde t(context, ...) ile çevrilir.
  final Map<String, String> sectionLabels;

  /// Mevcut sıra — [sectionLabels] anahtarlarının bir permütasyonu.
  final List<String> order;

  final ValueChanged<List<String>> onChanged;

  @override
  State<SectionOrderField> createState() => _SectionOrderFieldState();
}

class _SectionOrderFieldState extends State<SectionOrderField> {
  late List<String> _order = List<String>.from(widget.order);

  @override
  void didUpdateWidget(covariant SectionOrderField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Düzenle akışında (initState sonrası initialData restore edilince)
    // dışarıdan gelen sıra değişmişse widget'ı senkron tut.
    if (!_sameOrder(oldWidget.order, widget.order)) {
      _order = List<String>.from(widget.order);
    }
  }

  bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, widget.title), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          t(context, widget.helperText),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _order.removeAt(oldIndex);
                _order.insert(newIndex, item);
              });
              widget.onChanged(_order);
            },
            children: [
              for (var i = 0; i < _order.length; i++)
                Container(
                  key: ValueKey(_order[i]),
                  decoration: BoxDecoration(
                    border: i == _order.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.accentBlue.withOpacity(0.12),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentBlue),
                      ),
                    ),
                    title: Text(t(context, widget.sectionLabels[_order[i]] ?? _order[i])),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle_rounded, color: Colors.grey),
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
