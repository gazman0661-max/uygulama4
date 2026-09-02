import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/billing_constants.dart';
import '../models/site_project.dart';
import '../services/billing_service.dart';
import '../state/app_state.dart';
import '../widgets/pill_button.dart';
import '../widgets/login_gate.dart';
import '../localization/app_strings.dart';

/// 28.08.2026 eklendi, 28.08.2026'da fiyat/akış revizyonuyla güncellendi —
/// İndirme artık ücretsiz bir "reklam izle" akışı DEĞİL, HER ZAMAN ücretli
/// bir kilit (bkz. AppState.canDownloadFreely — SADECE downloadPurchased'a
/// bakar, rozet kaldırma tek başına indirme hakkı VERMEZ). Kullanıcı
/// "İndir" butonuna basınca bu popup açılır ve projenin GÜNCEL rozet
/// durumuna göre İKİ FARKLI görünüm sunar:
///
///   A) Proje ZATEN rozetsizse (watermarkRemoved=true, kullanıcı daha önce
///      149.90 ödeyip rozeti kaldırmış): TEK seçenek gösterilir — sadece
///      indirme hakkı, kProductDownloadWatermarked (29.90). Rozet zaten
///      kalkmış olduğundan indirilen dosya otomatik olarak rozetsiz olur.
///
///   B) Proje HÂLÂ rozetliyse (watermarkRemoved=false): İKİ seçenek
///      gösterilir:
///      1) Watermarklı İndir — kProductDownloadWatermarked (29.90). Rozet
///         HTML'de kalır; proje bir daha ÜCRETSİZ (popup'sız) rozetLİ
///         indirilebilir.
///      2) Watermarksız İndir + İndirme — kProductDownloadNoWatermark
///         (169.90). KOMBO ürün: tek ödemede hem rozeti kalıcı olarak
///         kaldırır HEM DE indirme hakkını verir (ayrı ayrı
///         149.90+29.90=179.80 yerine indirimli tek fiyat).
///
/// Fiyatlar Play Console'dan CANLI çekilir (bkz. BillingService.products),
/// burada hiçbir sabit TL değeri YAZILMAZ — kullanıcının Play Console'da
/// girdiği fiyat neyse birebir o gösterilir.
///
/// Dönen değer: kullanıcı gerçekten bir satın alma TAMAMLADIYSA true
/// (çağıran taraf bu durumda asıl indirmeyi hemen başlatmalı), vazgeçtiyse
/// (popup'ı kapattıysa/"Vazgeç"e bastıysa) false.
Future<bool> showDownloadPurchaseSheet(
  BuildContext context, {
  required SiteProject project,
}) async {
  // Rozet kaldırma sheet'iyle AYNI desen: ödeme akışı girişe bağlı.
  final ok = await requireLogin(context, feature: t(context, 'İndir'));
  if (!ok || !context.mounted) return false;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141821),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _DownloadPurchaseSheet(project: project),
  );
  return result ?? false;
}

class _DownloadPurchaseSheet extends StatefulWidget {
  final SiteProject project;

  const _DownloadPurchaseSheet({required this.project});

  @override
  State<_DownloadPurchaseSheet> createState() => _DownloadPurchaseSheetState();
}

class _DownloadPurchaseSheetState extends State<_DownloadPurchaseSheet> {
  // Aynı anda sadece TEK bir buton "işleniyor" olabilir — hangi ürünün
  // satın alınmakta olduğunu tutar (null = boşta).
  String? _busyProductId;
  String? _error;

  Future<void> _purchase(String productId) async {
    setState(() {
      _busyProductId = productId;
      _error = null;
    });
    try {
      final purchased = await BillingService.instance.buyConsumable(productId);
      if (!purchased) {
        // Kullanıcı mağaza ekranında vazgeçti — sessizce boşta durumuna dön.
        if (mounted) setState(() => _busyProductId = null);
        return;
      }
      if (!mounted) return;
      final appState = context.read<AppState>();
      if (productId == kProductDownloadNoWatermark) {
        await appState.unlockDownloadWithoutWatermark(widget.project.id);
      } else {
        await appState.unlockDownloadForProject(widget.project.id);
      }
      if (!mounted) return;
      // Satın alma TAMAMLANDI — popup'ı kapatıp çağıran tarafa "indirmeye
      // devam et" sinyali gönder (bkz. dosya başı açıklaması).
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyProductId = null;
        _error = isEnglish(context)
            ? 'Purchase failed. Please try again.'
            : 'Satın alma başarısız oldu. Lütfen tekrar deneyin.';
      });
    }
  }

  /// remove_watermark_sheet.dart ile AYNI desen: BillingService.products,
  /// Play Console'dan canlı çekilen (bölgeye göre lokalize/formatlanmış)
  /// fiyatı tutar. Henüz yüklenmediyse/mağaza kurulmadıysa '—' gösterir.
  String _priceLabel(String productId) {
    final product = BillingService.instance.products[productId];
    return product?.price ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final busy = _busyProductId != null;
    // Rozet ZATEN kaldırılmışsa (daha önce 149.90 ödenmiş) tek seçenek
    // gösterilir: sadece indirme hakkı — bkz. dosya başı açıklaması (A).
    final alreadyWatermarkFree = widget.project.watermarkRemoved;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 22,
          bottom: MediaQuery.of(context).viewInsets.bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💾', style: TextStyle(fontSize: 30)),
            const SizedBox(height: 10),
            Text(
              t(context, 'Siteni İndir'),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              alreadyWatermarkFree
                  ? (en
                      ? '"${widget.project.name}" is already watermark-free. Pay the download fee once to unlock unlimited free re-downloads for this site.'
                      : '"${widget.project.name}" zaten rozetsiz. Bu site için sınırsız ücretsiz tekrar indirme hakkı almak üzere tek seferlik indirme ücretini öde.')
                  : (en
                      ? 'Choose how you\'d like to download "${widget.project.name}". Either option unlocks unlimited free re-downloads for this site.'
                      : '"${widget.project.name}" için indirme şeklini seç. Her iki seçenek de bu site için sınırsız ücretsiz tekrar indirme hakkı verir.'),
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),

            if (alreadyWatermarkFree) ...[
              // --- Rozet zaten kaldırılmış: TEK seçenek — sadece indirme hakkı.
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: _busyProductId == kProductDownloadWatermarked
                      ? t(context, 'İşleniyor...')
                      : '${t(context, 'İndir')} — ${_priceLabel(kProductDownloadWatermarked)}',
                  emoji: _busyProductId == kProductDownloadWatermarked ? null : '💾',
                  borderColor: const Color(0xFF29B6F6),
                  textColor: Colors.white,
                  filled: true,
                  fillColor: const Color(0xFF29B6F6),
                  height: 46,
                  fontSize: 14,
                  onTap: busy ? null : () => _purchase(kProductDownloadWatermarked),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t(context, 'Rozet zaten kaldırılmıştı — dosya rozetsiz iner.'),
                style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11.5),
              ),
            ] else ...[
              // --- Seçenek 1: Watermarklı indir (ucuz) ------------------------
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: _busyProductId == kProductDownloadWatermarked
                      ? t(context, 'İşleniyor...')
                      : '${t(context, 'Watermarklı İndir')} — ${_priceLabel(kProductDownloadWatermarked)}',
                  emoji: _busyProductId == kProductDownloadWatermarked ? null : '🏷️',
                  borderColor: Colors.white24,
                  textColor: Colors.white,
                  height: 46,
                  fontSize: 14,
                  onTap: busy ? null : () => _purchase(kProductDownloadWatermarked),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t(context, '"Sitora ile üretildi" rozeti sitede görünür kalır.'),
                style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11.5),
              ),

              const SizedBox(height: 16),

              // --- Seçenek 2: Watermarksız indir + indirme (kombo, pahalı) ----
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: _busyProductId == kProductDownloadNoWatermark
                      ? t(context, 'İşleniyor...')
                      : '${t(context, 'Watermarksız İndir')} — ${_priceLabel(kProductDownloadNoWatermark)}',
                  emoji: _busyProductId == kProductDownloadNoWatermark ? null : '✨',
                  borderColor: const Color(0xFF29B6F6),
                  textColor: Colors.white,
                  filled: true,
                  fillColor: const Color(0xFF29B6F6),
                  height: 46,
                  fontSize: 14,
                  onTap: busy ? null : () => _purchase(kProductDownloadNoWatermark),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t(context, 'Rozet tamamen kaldırılır + indirme hakkı verilir — bu site ileride yayınlanırsa o da rozetsiz olur.'),
                style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11.5),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PillButton(
                label: t(context, 'Vazgeç'),
                borderColor: Colors.transparent,
                textColor: Colors.white54,
                height: 40,
                fontSize: 13,
                onTap: busy ? null : () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
