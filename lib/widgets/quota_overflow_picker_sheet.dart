import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../state/app_state.dart';
import '../widgets/pill_button.dart';
import '../widgets/app_popup.dart';
import '../localization/app_strings.dart';

Future<void> showQuotaOverflowPickerSheet(BuildContext context) async {
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
      child: _QuotaOverflowPickerSheet(),
    ),
  );

  if (!context.mounted) return;
  final appState = context.read<AppState>();
  if (!appState.hasSubscriptionQuotaOverflow) return;

  final removedNames = await appState.autoResolveSubscriptionQuotaOverflow();
  if (!context.mounted || removedNames.isEmpty) return;
  final en = isEnglish(context);
  await showAppPopup(
    context,
    icon: '⚠️',
    message: en
        ? 'You closed the picker without choosing, so the oldest published site(s) were automatically unpublished to fit your plan: ${removedNames.join(', ')}'
        : 'Seçim yapmadan kapattığın için paketine sığması amacıyla en eski yayınlanan site(ler) otomatik olarak yayından kaldırıldı: ${removedNames.join(', ')}',
  );
}

class _QuotaOverflowPickerSheet extends StatefulWidget {
  const _QuotaOverflowPickerSheet();

  @override
  State<_QuotaOverflowPickerSheet> createState() => _QuotaOverflowPickerSheetState();
}

class _QuotaOverflowPickerSheetState extends State<_QuotaOverflowPickerSheet> {
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final appState = context.watch<AppState>();
    final quotaProjects = appState.subscriptionQuotaProjects;
    final allowed = appState.activeSubscriptionTier?.siteQuota ?? 0;
    final atLimit = _selected.length >= allowed;

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
            const Text('🗂️', style: TextStyle(fontSize: 30), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              en ? 'Choose which sites stay in your quota' : 'Kota içinde kalacak siteleri seç',
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
                      ? 'Your current plan allows $allowed site(s), but ${quotaProjects.length} are currently using badge-free/premium benefits. Pick up to $allowed to keep — the rest will get their badge and locks back automatically (nothing is unpublished or deleted).'
                      : 'Şu anki paketin $allowed site hakkı veriyor, ama ${quotaProjects.length} site şu an rozetsiz/premium avantajlardan yararlanıyor. En fazla $allowed tanesini seçebilirsin — geri kalanların rozeti/kilitleri otomatik geri gelir (hiçbir site yayından kaldırılmaz/silinmez).')
                  : (en
                      ? 'Your subscription is no longer active, so no site can stay in the quota right now. Tap below to release all of them — this does NOT unpublish or delete any site, it only removes the badge-free/premium benefits.'
                      : 'Aboneliğin artık aktif değil, bu yüzden şu an hiçbir site kota içinde kalamıyor. Aşağıdan hepsini serbest bırak — bu hiçbir siteyi yayından kaldırmaz/silmez, sadece rozetsiz/premium avantajları geri alır.'),
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
                          ? 'If you close this without choosing, the system will choose for you: the oldest published site(s) will be automatically unpublished so the rest fit your plan.'
                          : 'Seçim yapmadan bu ekranı kapatırsan sistem senin yerine seçer: en eski yayınlanan site(ler) paketine sığması için otomatik olarak yayından kaldırılır.',
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
                  return _ProjectCheckRow(
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
                        : (en ? 'Release all' : 'Tümünü Serbest Bırak')),
                emoji: _saving ? null : '✅',
                borderColor: const Color(0xFF66BB6A),
                textColor: Colors.white,
                filled: true,
                fillColor: const Color(0xFF66BB6A),
                height: 46,
                fontSize: 14,
                onTap: _saving ? null : () => _save(quotaProjects),
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

  Future<void> _save(List<SiteProject> quotaProjects) async {
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    for (final p in quotaProjects) {
      if (!_selected.contains(p.id)) {
        await appState.unassignProjectFromSubscriptionQuota(p.id);
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

  Future<void> _autoSelect() async {
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final removedNames = await appState.autoResolveSubscriptionQuotaOverflow();
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    final en = isEnglish(context);
    await showAppPopup(
      context,
      icon: '⚠️',
      message: removedNames.isEmpty
          ? (en ? 'Nothing to remove' : 'Kaldırılacak site yoktu')
          : (en
              ? 'Unpublished: ${removedNames.join(', ')}'
              : 'Yayından kaldırıldı: ${removedNames.join(', ')}'),
    );
  }
}

class _ProjectCheckRow extends StatelessWidget {
  final SiteProject project;
  final bool checked;
  final bool disabled;
  final VoidCallback? onTap;

  const _ProjectCheckRow({
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
                  child: Text(
                    project.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
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
