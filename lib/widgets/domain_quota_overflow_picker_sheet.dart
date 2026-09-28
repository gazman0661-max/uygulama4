import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../state/app_state.dart';
import '../widgets/pill_button.dart';
import '../widgets/app_popup.dart';
import '../widgets/confirm_popup.dart';
import '../localization/app_strings.dart';

/// ============================================================================
/// DOMAIN KOTA AŞIMI SEÇİM SHEET'İ — 16.09.2026 eklendi (kanka isteği:
/// "domain kota aşımı: UI YOK" fix'i — bkz.
/// DEGISIKLIKLER_16_09_2026_DOMAIN_KOTA_BILINCLI_EKLENDI.md > madde 2, o
/// notta "eklendi" denmişti ama dosya hiç yazılmamıştı; bu GERÇEK ekleme).
/// ============================================================================
/// bkz. AppState.hasDomainQuotaOverflow/domainQuotaProjects/
/// unassignDomainQuota dokümanları — quota_overflow_picker_sheet.dart
/// (site/rozet kotası) ile BİREBİR AYNI desen, TEK ve ÖNEMLİ fark:
///
/// rozet kotası aşımında seçilmeyen bir site sadece rozetini/kilitlerini
/// geri alır (hiçbir şey sökülmez). Domain kotası aşımında ise seçilmeyen
/// bir domain GERÇEKTEN SÖKÜLÜR (unassignDomainQuota alsoDisconnect:true
/// ile hem domainViaSubscription'ı kapatır hem DomainService.disconnect
/// çağırır) — çünkü bu domain'i hiç kimse standalone (kProductConnectDomain)
/// ödemedi. Site kendisi yayından KALKMAZ, sadece kendi ücretsiz alt alan
/// adında yayında kalmaya devam eder; ama domain bağlantısının kendisi
/// gerçekten kopar. Bu yüzden burada (site/rozet sheet'inin aksine) SAVE
/// öncesi bir onay (showConfirmPopup) alınıyor.
///
/// NE ZAMAN AÇILIR: hesabın domain kotasında (domainQuotaProjects) o anki
/// paketin izin verdiğinden (activeSubscriptionTier?.domainQuota) DAHA
/// FAZLA domain varsa.
///
/// Kullanıcı seçim yapmadan sheet'i kapatırsa (geri tuşu/dışarı dokunma,
/// Save/Otomatik Seç DIŞINDA herhangi bir yol) — 16.09.2026 DAVRANIŞ
/// DEĞİŞİKLİĞİ (kanka isteği: site/rozet sheet'indeki AYNI davranış
/// domain tarafına da uygulandı, bkz. quota_overflow_picker_sheet.dart
/// dosya başı dokümanı): artık eski "hiçbir şey değişmez" kuralı KALDIRILDI.
/// Sheet kapandıktan SONRA burada (showDomainQuotaOverflowPickerSheet
/// içinde) hasDomainQuotaOverflow HÂLÂ true ise — yani kullanıcı Save ile
/// elle seçim yapmadıysa VE "Otomatik Seç" butonuna da basmadıysa — sistem
/// otomatik olarak autoResolveDomainQuotaOverflow çağırır: EN YENİ bağlanan
/// domain'leri kota içinde tutar, en eski bağlanan fazlalık domain'leri hem
/// kota slotundan çıkarır HEM DE GERÇEKTEN söktürür (site kendisi yayından
/// KALKMAZ, sadece o domain'in bağlantısı kopar). Kullanıcı bilgilendirme
/// popup'ı ile bundan haberdar edilir. Sheet içindeki uyarı metni de artık
/// bunu AÇIKÇA söylüyor, sürpriz olmasın diye.
///
/// "Otomatik Seç" butonu — 16.09.2026 eklendi (kanka isteği: eski "Daha
/// sonra karar ver" butonunun yerine geçti). Kullanıcı beklemeden hemen
/// aynı sonucu tetiklemek isterse bu butona basar.
Future<void> showDomainQuotaOverflowPickerSheet(BuildContext context) async {
  // 17.09.2026 eklendi (kanka isteği — "seçim yapmadan/otomatik seç
  // demeden popup KAPANMASIN, garantiye alalım" fix'i) — site/rozet
  // sheet'indeki (quota_overflow_picker_sheet.dart) AYNI kilit: isDismissible/
  // enableDrag false + PopScope(canPop:false). Sheet artık SADECE Save ya
  // da Otomatik Seç'in kendi programatik Navigator.pop() çağrısıyla
  // kapanabiliyor — geri tuşu/dışarı dokunma/aşağı sürükleme HİÇBİRİ
  // işe yaramıyor.
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: const Color(0xFF141821),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const PopScope(
      canPop: false,
      child: _DomainQuotaOverflowPickerSheet(),
    ),
  );

  // GÜVENLİK AĞI — bkz. quota_overflow_picker_sheet.dart'taki AYNI
  // yorumun dokümanı: normalde artık hiç tetiklenmemesi gerekir, çift kilit
  // olarak bırakıldı.
  if (!context.mounted) return;
  final appState = context.read<AppState>();
  if (!appState.hasDomainQuotaOverflow) return;

  final removedNames = await appState.autoResolveDomainQuotaOverflow();
  if (!context.mounted || removedNames.isEmpty) return;
  final en = isEnglish(context);
  await showAppPopup(
    context,
    icon: '⚠️',
    message: en
        ? 'You closed the picker without choosing, so the oldest connected domain(s) were automatically disconnected to fit your plan (the site itself stays live on its free subdomain): ${removedNames.join(', ')}'
        : 'Seçim yapmadan kapattığın için paketine sığması amacıyla en eski bağlanan domain(ler) otomatik olarak söküldü (sitenin kendisi yayından kalkmadı, kendi ücretsiz alt alan adında kalmaya devam ediyor): ${removedNames.join(', ')}',
  );
}

class _DomainQuotaOverflowPickerSheet extends StatefulWidget {
  const _DomainQuotaOverflowPickerSheet();

  @override
  State<_DomainQuotaOverflowPickerSheet> createState() => _DomainQuotaOverflowPickerSheetState();
}

class _DomainQuotaOverflowPickerSheetState extends State<_DomainQuotaOverflowPickerSheet> {
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final appState = context.watch<AppState>();
    final quotaProjects = appState.domainQuotaProjects;
    final allowed = appState.activeSubscriptionTier?.domainQuota ?? 0;
    final atLimit = _selected.length >= allowed;
    final toRemoveCount = quotaProjects.length - _selected.length;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('🌐', style: TextStyle(fontSize: 30), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              en ? 'Choose which domains stay connected' : 'Bağlı kalacak domain\'leri seç',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              allowed > 0
                  ? (en
                      ? 'Your current plan allows $allowed domain(s), but ${quotaProjects.length} are currently connected for free through your subscription. Pick up to $allowed to keep — the rest will be REALLY disconnected (the site itself stays live on its free subdomain, it just loses its custom domain).'
                      : 'Şu anki paketin $allowed domain hakkı veriyor, ama ${quotaProjects.length} domain şu an abonelikle ücretsiz bağlı. En fazla $allowed tanesini seçebilirsin — geri kalanlar GERÇEKTEN SÖKÜLÜR (sitenin kendisi yayından kalkmaz, sadece kendi ücretsiz alt alan adında kalır, özel domain\'i kopar).')
                  : (en
                      ? 'Your subscription is no longer active, so no domain can stay connected through it right now. Tap below to disconnect all of them — this does NOT unpublish any site, it only removes the custom domain (each site keeps working on its free subdomain).'
                      : 'Aboneliğin artık aktif değil, bu yüzden şu an hiçbir domain onunla bağlı kalamıyor. Aşağıdan hepsini söktür — bu hiçbir siteyi yayından kaldırmaz, sadece özel domain\'i kaldırır (her site kendi ücretsiz alt alan adında çalışmaya devam eder).'),
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA726).withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFA726).withOpacity(0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      en
                          ? 'If you close this without choosing, the system will choose for you: the oldest connected domain(s) will be automatically disconnected so the rest fit your plan (sites stay live on their free subdomain).'
                          : 'Seçim yapmadan bu ekranı kapatırsan sistem senin yerine seçer: en eski bağlanan domain(ler) paketine sığması için otomatik olarak söktürülür (siteler kendi ücretsiz alt alan adında yayında kalmaya devam eder).',
                      style: const TextStyle(color: Color(0xFFFFA726), fontFamily: 'monospace', fontSize: 11.5, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.42),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: quotaProjects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = quotaProjects[i];
                  final isChecked = _selected.contains(p.id);
                  final disabled = allowed <= 0 || (!isChecked && atLimit);
                  return _DomainCheckRow(
                    project: p,
                    checked: isChecked,
                    disabled: disabled,
                    onTap: allowed <= 0
                        ? null
                        : () {
                            setState(() {
                              if (isChecked) {
                                _selected.remove(p.id);
                              } else if (!atLimit) {
                                _selected.add(p.id);
                              }
                            });
                          },
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            if (allowed > 0)
              Text(
                en
                    ? 'Selected: ${_selected.length} / $allowed'
                    : 'Seçilen: ${_selected.length} / $allowed',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 11.5),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: PillButton(
                label: _saving
                    ? (en ? 'Saving...' : 'Kaydediliyor...')
                    : (allowed > 0
                        ? (en ? 'Save' : 'Kaydet')
                        : (en ? 'Disconnect all' : 'Tümünü Söktür')),
                emoji: _saving ? null : '✅',
                borderColor: const Color(0xFFEF5350),
                textColor: Colors.white,
                filled: true,
                fillColor: const Color(0xFFEF5350),
                height: 46,
                fontSize: 14,
                onTap: _saving ? null : () => _confirmAndSave(quotaProjects, toRemoveCount),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _saving ? null : _autoSelect,
              child: Text(
                en ? 'Auto select' : 'Otomatik Seç',
                style: TextStyle(color: Colors.grey.shade500, fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndSave(List<SiteProject> quotaProjects, int toRemoveCount) async {
    final en = isEnglish(context);
    if (toRemoveCount > 0) {
      final ok = await showConfirmPopup(
        context,
        icon: '⚠️',
        title: en ? 'Disconnect domains?' : 'Domain\'ler söksün mü?',
        message: en
            ? '$toRemoveCount domain will be permanently disconnected from their sites. This cannot be undone from here — you would need to reconnect (and pay again) to restore it. Continue?'
            : '$toRemoveCount domain sitelerinden kalıcı olarak sökülecek. Bu işlem buradan geri alınamaz — geri getirmek için tekrar bağlaman (ve tekrar ödemen) gerekir. Devam edilsin mi?',
        confirmLabel: en ? 'Yes, disconnect' : 'Evet, söktür',
        cancelLabel: en ? 'Cancel' : 'Vazgeç',
      );
      if (!ok) return;
      if (!mounted) return;
    }
    await _save(quotaProjects);
  }

  Future<void> _save(List<SiteProject> quotaProjects) async {
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    for (final p in quotaProjects) {
      if (!_selected.contains(p.id)) {
        await appState.unassignDomainQuota(p.id);
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    final en = isEnglish(context);
    await showAppPopup(
      context,
      icon: '✅',
      message: en ? 'Saved' : 'Kaydedildi',
    );
  }

  /// "Otomatik Seç" — kullanıcı elle seçim yapmak yerine kararı sisteme
  /// bırakır. bkz. AppState.autoResolveDomainQuotaOverflow dokümanı: en eski
  /// bağlanan fazlalık domain'ler GERÇEKTEN söktürülür. Bu geri alınamaz bir
  /// işlem olduğu için (tekrar bağlamak tekrar ödeme gerektirir) _confirmAndSave
  /// ile AYNI onay popup'ı burada da önce gösterilir.
  Future<void> _autoSelect() async {
    final appState = context.read<AppState>();
    final allowed = appState.activeSubscriptionTier?.domainQuota ?? 0;
    final toRemoveCount = appState.domainQuotaProjects.length - allowed;
    final en = isEnglish(context);
    if (toRemoveCount > 0) {
      final ok = await showConfirmPopup(
        context,
        icon: '⚠️',
        title: en ? 'Disconnect domains?' : 'Domain\'ler söksün mü?',
        message: en
            ? 'The oldest $toRemoveCount domain will be automatically and permanently disconnected from their sites. This cannot be undone from here — you would need to reconnect (and pay again) to restore it. Continue?'
            : 'En eski $toRemoveCount domain sitelerinden otomatik ve kalıcı olarak sökülecek. Bu işlem buradan geri alınamaz — geri getirmek için tekrar bağlaman (ve tekrar ödemen) gerekir. Devam edilsin mi?',
        confirmLabel: en ? 'Yes, disconnect' : 'Evet, söktür',
        cancelLabel: en ? 'Cancel' : 'Vazgeç',
      );
      if (!ok) return;
      if (!mounted) return;
    }
    setState(() => _saving = true);
    final removedNames = await appState.autoResolveDomainQuotaOverflow();
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    await showAppPopup(
      context,
      icon: '⚠️',
      message: removedNames.isEmpty
          ? (en ? 'Nothing to remove' : 'Sökülecek domain yoktu')
          : (en
              ? 'Disconnected: ${removedNames.join(', ')}'
              : 'Söküldü: ${removedNames.join(', ')}'),
    );
  }
}

class _DomainCheckRow extends StatelessWidget {
  final SiteProject project;
  final bool checked;
  final bool disabled;
  final VoidCallback? onTap;

  const _DomainCheckRow({
    required this.project,
    required this.checked,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: checked ? const Color(0xFF66BB6A).withOpacity(0.12) : Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: disabled ? null : onTap,
        child: Opacity(
          opacity: disabled && !checked ? 0.4 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  checked ? Icons.check_circle : Icons.circle_outlined,
                  color: checked ? const Color(0xFF66BB6A) : Colors.white38,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                      ),
                      if (project.customDomain != null)
                        Text(
                          project.customDomain!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
