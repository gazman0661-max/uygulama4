import 'package:flutter/material.dart';
import '../services/ai_fill_service.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

/// ============================================================================
/// AI İLE DOLDUR — POPUP
/// ============================================================================
/// 30.08.2026 eklendi. Görsel dili kanka'nın attığı ekran görüntüsündeki
/// eski "AI Bölüm Düzenleyici" ile AYNI (koyu kart, ✨ başlık, camgöbeği
/// çerçeve, mavi gradyan buton — bkz. AppTheme.accentCyan/accentBlue) ama
/// AKIŞ FARKLI: o eski tasarım bölüm-bölüm serbest komut alıyordu (her
/// bölüm = ayrı AI isteği, maliyet/istek-limiti sorunu yaratırdı — bkz.
/// sohbet geçmişi). Bu yeni tasarım TEK popup'ta TÜM formu topluyor, TEK
/// AI isteği atıyor.
///
/// İKİYE AYRIM (bilinçli tasarım kararı):
///   - Sektör / işletme adı / "ürünlerim-hizmetlerim hakkında" → AI'ye
///     gider (yaratıcı metin: tagline, hizmet açıklaması vb.)
///   - Adres / telefon / WhatsApp / Instagram → AI'YE HİÇ GİTMEZ, submit
///     anında yerel olarak (ücretsiz, anında, halüsinasyon riski sıfır)
///     ilgili controller'lara yazılır. Bu yüzden dönüş değeri ([showAiFillDialog])
///     hem "local" (ham, olduğu gibi) hem "ai" (Worker'dan gelen) alanları
///     TEK bir Map'te birleştirip döner — çağıran form ekranı tek yerden
///     okur.
///
/// KULLANIM (bkz. kuafor_form_screen.dart > _openAiFillDialog):
///   final result = await showAiFillDialog(
///     context: context,
///     sectorLabel: t(context, 'Kuaför / Berber'),
///     initialCompanyName: _nameCtrl.text,
///     initialAddress: _addressCtrl.text,
///     initialPhone: _phoneCtrl.text,
///     initialWhatsapp: _whatsappCtrl.text,
///     initialInstagram: _instagramCtrl.text,
///     siteLang: _siteLang,
///   );
///   if (result == null) return; // kullanıcı vazgeçti
///   setState(() {
///     _nameCtrl.text = result['companyName'] ?? _nameCtrl.text;
///     _addressCtrl.text = result['address'] ?? _addressCtrl.text;
///     _phoneCtrl.text = result['phone'] ?? _phoneCtrl.text;
///     _whatsappCtrl.text = result['whatsapp'] ?? _whatsappCtrl.text;
///     _instagramCtrl.text = result['instagram'] ?? _instagramCtrl.text;
///     if (result['tagline'] != null) _taglineCtrl.text = result['tagline']!;
///     if (result['services'] != null) _servicesCtrl.text = result['services']!;
///   });
/// ============================================================================
Future<Map<String, String>?> showAiFillDialog({
  required BuildContext context,
  required String sectorLabel,
  String initialCompanyName = '',
  String initialAddress = '',
  String initialPhone = '',
  String initialWhatsapp = '',
  String initialInstagram = '',
  String siteLang = 'tr',
}) {
  return showDialog<Map<String, String>>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (_) => _AiFillDialog(
      sectorLabel: sectorLabel,
      initialCompanyName: initialCompanyName,
      initialAddress: initialAddress,
      initialPhone: initialPhone,
      initialWhatsapp: initialWhatsapp,
      initialInstagram: initialInstagram,
      siteLang: siteLang,
    ),
  );
}

class _AiFillDialog extends StatefulWidget {
  final String sectorLabel;
  final String initialCompanyName;
  final String initialAddress;
  final String initialPhone;
  final String initialWhatsapp;
  final String initialInstagram;
  final String siteLang;

  const _AiFillDialog({
    required this.sectorLabel,
    required this.initialCompanyName,
    required this.initialAddress,
    required this.initialPhone,
    required this.initialWhatsapp,
    required this.initialInstagram,
    required this.siteLang,
  });

  @override
  State<_AiFillDialog> createState() => _AiFillDialogState();
}

class _AiFillDialogState extends State<_AiFillDialog> {
  late final _companyCtrl = TextEditingController(text: widget.initialCompanyName);
  late final _aboutCtrl = TextEditingController();
  late final _addressCtrl = TextEditingController(text: widget.initialAddress);
  late final _phoneCtrl = TextEditingController(text: widget.initialPhone);
  late final _whatsappCtrl = TextEditingController(text: widget.initialWhatsapp);
  late final _instagramCtrl = TextEditingController(text: widget.initialInstagram);

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _companyCtrl.dispose();
    _aboutCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _instagramCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_companyCtrl.text.trim().isEmpty) {
      setState(() => _error = t(context, 'İşletme adını yaz.'));
      return;
    }

    // Adres/telefon/whatsapp/instagram — AI'YE GİTMEDEN, doğrudan sonuca
    // eklenir (bkz. dosya üstündeki İKİYE AYRIM notu).
    final result = <String, String>{
      'companyName': _companyCtrl.text.trim(),
      if (_addressCtrl.text.trim().isNotEmpty) 'address': _addressCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      if (_whatsappCtrl.text.trim().isNotEmpty) 'whatsapp': _whatsappCtrl.text.trim(),
      if (_instagramCtrl.text.trim().isNotEmpty) 'instagram': _instagramCtrl.text.trim(),
    };

    if (!AiFillService.isConfigured) {
      // Worker henüz bağlanmadı (bkz. ai_fill_service.dart > TODO) — AI
      // kısmını atla, en azından yerel alanları (adres/telefon/sosyal)
      // doldurarak kullanıcıya YİNE DE bir fayda sağla, akışı tıkama.
      if (mounted) Navigator.of(context).pop(result);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final aiResult = await AiFillService.generateFields(
      sector: widget.sectorLabel,
      companyName: _companyCtrl.text.trim(),
      aboutInfo: _aboutCtrl.text.trim(),
      siteLang: widget.siteLang,
    );

    if (!mounted) return;

    if (aiResult == null) {
      setState(() {
        _loading = false;
        _error = t(context,
            'AI şu an yardımcı olamadı. Adres/telefon/sosyal medya bilgilerini yine de uyguladım — metin alanlarını elle doldurabilirsin.');
      });
      // Hata olsa bile 2 saniye sonra yerel alanları uygulayıp kapat —
      // kullanıcı en azından o kısmı elle tekrar girmesin. Hata mesajını
      // kısa süre görebilsin diye anında kapatmıyoruz.
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.of(context).pop(result);
      return;
    }

    result.addAll(aiResult.fields);
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1420),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accentCyan, width: 1.4),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t(context, 'AI ile Doldur'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(null),
                    icon: const Icon(Icons.close, color: Colors.grey),
                    splashRadius: 20,
                  ),
                ],
              ),
              Divider(color: Colors.white.withOpacity(0.1), height: 24),
              Text(
                '${t(context, 'Sektör')}: ${widget.sectorLabel}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              _field(
                controller: _companyCtrl,
                label: t(context, 'İşletme adı'),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _aboutCtrl,
                label: t(context, 'Ürünlerin/hizmetlerin ve işletmen hakkında'),
                hint: t(context,
                    'Örn: 10 yıldır saç kesimi ve sakal tıraşı yapıyoruz, çocuk kesimi de var, samimi bir ortamımız var...'),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              _field(controller: _addressCtrl, label: t(context, 'Adres (opsiyonel)')),
              const SizedBox(height: 12),
              _field(
                controller: _phoneCtrl,
                label: t(context, 'Telefon (opsiyonel)'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _whatsappCtrl,
                label: t(context, 'WhatsApp (opsiyonel, 90XXXXXXXXXX)'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _instagramCtrl,
                label: t(context, 'Instagram kullanıcı adı (opsiyonel)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [AppTheme.accentCyan, AppTheme.accentBlue],
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _loading ? null : _submit,
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    t(context, 'Gönder'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('✨', style: TextStyle(fontSize: 15)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
