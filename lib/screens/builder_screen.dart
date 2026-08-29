import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/canvas_element.dart';
import '../models/site_project.dart';
import '../constants/social_icons.dart';
import '../services/download_service.dart';
import '../widgets/app_popup.dart';
import '../widgets/confirm_popup.dart';
import '../widgets/phone_number_popup.dart';
import '../widgets/drawing_pad_dialog.dart';
import '../widgets/quota_limit_popup.dart';
import '../widgets/download_purchase_sheet.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../state/app_state.dart';
import 'package:provider/provider.dart';

/// BUILDER PRO ekranı — gerçek bir canvas motoruna sahip.
///
/// index.html > #builder-container ile AYNI DÜZEN (üst araç çubuğu +
/// sağdan/alttan açılan özellik paneli + canvas workspace + alt araç
/// çubuğu) Flutter'a taşınmıştır. Canvas artık gerçek elemanlar
/// (yazı/foto/şekil/buton) barındırır: sürükle, yeniden boyutlandır,
/// özellik panelinden düzenle, geri/ileri al, şablon uygula ve HTML
/// olarak dışa aktar.
///
/// Not: HTML'deki puan/premium-kilit sistemi burada YOK — kullanıcı
/// Builder Pro'da tüm araçları serbestçe kullanabilir.
class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

/// Builder Pro > Şablonlar için hazır 10 güncel şablon. Bir şablon
/// seçildiğinde canvas'a gerçek, düzenlenebilir elemanlar (başlık,
/// açıklama, görsel alanı, CTA butonu) yerleştirilir; kullanıcı bunları
/// canvas motoruyla serbestçe değiştirebilir.
class BuilderTemplate {
  final String name;
  final String emoji;
  final String category;
  final String description;
  final Color bgColor;
  final Color accent;
  final String ctaLabel;

  const BuilderTemplate({
    required this.name,
    required this.emoji,
    required this.category,
    required this.description,
    required this.bgColor,
    required this.accent,
    required this.ctaLabel,
  });
}

const List<BuilderTemplate> kBuilderTemplates = [
  BuilderTemplate(
    name: 'Kafe & Restoran',
    emoji: '☕',
    category: 'Yeme-İçme',
    description: 'Menü, konum ve rezervasyon butonu odaklı sıcak tonlu tasarım.',
    bgColor: Color(0xFFFFF3E0),
    accent: Color(0xFFE8710A),
    ctaLabel: 'Rezervasyon Yap',
  ),
  BuilderTemplate(
    name: 'Kuaför & Güzellik Salonu',
    emoji: '💇',
    category: 'Güzellik',
    description: 'Hizmet listesi, galeri ve WhatsApp\'tan randevu akışı.',
    bgColor: Color(0xFFFCE4EC),
    accent: Color(0xFFE1306C),
    ctaLabel: 'Randevu Al',
  ),
  BuilderTemplate(
    name: 'Emlak Ofisi',
    emoji: '🏠',
    category: 'Emlak',
    description: 'İlan kartları, harita ve iletişim formu düzeni.',
    bgColor: Color(0xFFE8F5E9),
    accent: Color(0xFF2E7D32),
    ctaLabel: 'İlanları Gör',
  ),
  BuilderTemplate(
    name: 'Spor Salonu / Fitness',
    emoji: '🏋️',
    category: 'Spor & Sağlık',
    description: 'Üyelik paketleri, program tanıtımı ve enerjik koyu tema.',
    bgColor: Color(0xFF121212),
    accent: Color(0xFF26C6DA),
    ctaLabel: 'Üye Ol',
  ),
  BuilderTemplate(
    name: 'E-ticaret / Butik',
    emoji: '🛍️',
    category: 'Satış',
    description: 'Ürün vitrini, kampanya bandı ve sepete/WhatsApp\'a yönlendirme.',
    bgColor: Color(0xFFFFFFFF),
    accent: Color(0xFF6A1B9A),
    ctaLabel: 'Alışverişe Başla',
  ),
  BuilderTemplate(
    name: 'Diş / Estetik Kliniği',
    emoji: '🦷',
    category: 'Sağlık',
    description: 'Güven veren mavi-beyaz palet, hizmetler ve online randevu.',
    bgColor: Color(0xFFE3F2FD),
    accent: Color(0xFF1565C0),
    ctaLabel: 'Online Randevu',
  ),
  BuilderTemplate(
    name: 'Düğün & Etkinlik',
    emoji: '💍',
    category: 'Etkinlik',
    description: 'Davetiye tarzı zarif tipografi, geri sayım ve konum bilgisi.',
    bgColor: Color(0xFFFCE9EC),
    accent: Color(0xFFAD1457),
    ctaLabel: 'Detayları Gör',
  ),
  BuilderTemplate(
    name: 'Kişisel Portfolyo / CV',
    emoji: '🧑‍💻',
    category: 'Portfolyo',
    description: 'Proje vitrini, yetenekler ve sosyal medya bağlantıları.',
    bgColor: Color(0xFF0D0D0D),
    accent: Color(0xFF4FC3F7),
    ctaLabel: 'Projelerimi Gör',
  ),
  BuilderTemplate(
    name: 'Mobil Uygulama Tanıtımı',
    emoji: '📱',
    category: 'Uygulama Tanıtımı',
    description: 'Ekran görüntüleri, özellik listesi ve Play Store/App Store CTA.',
    bgColor: Color(0xFF0F1B2D),
    accent: Color(0xFF00E5FF),
    ctaLabel: 'Uygulamayı İndir',
  ),
  BuilderTemplate(
    name: 'Kurumsal / Ajans',
    emoji: '🏢',
    category: 'Kurumsal',
    description: 'Hizmet alanları, referanslar ve iletişim odaklı ciddi düzen.',
    bgColor: Color(0xFFF5F5F5),
    accent: Color(0xFF37474F),
    ctaLabel: 'Bize Ulaşın',
  ),
];

class _BuilderScreenState extends State<BuilderScreen> with WidgetsBindingObserver {
  // ---- canvas motoru durumu ----
  final List<CanvasElement> _elements = [];
  String? _selectedId;
  int _idCounter = 0;
  Size _canvasSize = Size.zero;
  final GlobalKey _canvasKey = GlobalKey();

  /// Bu canvas oturumunda "İndir"e birden fazla kez basılırsa "Projelerim"de
  /// her seferinde YENİ bir satır açılmasın diye — ilk export'ta oluşan
  /// proje id'si burada tutulur, sonraki export'lar aynı projeyi günceller.
  /// null = bu oturumda henüz hiç "Projelerim"e kaydedilmedi.
  String? _savedProjectId;

  // Uygulama kapatılıp açıldığında Builder Pro canvas'ındaki tasarım
  // kaybolmasın diye elemanlar SharedPreferences'ta saklanır. Kullanıcı
  // sadece "Tasarımı Sil" butonuna basıp onaylarsa temizlenir.
  static const _canvasPrefsKey = 'builder_canvas_v1';
  bool _canvasLoaded = false;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCanvas();
  }

  Future<void> _loadCanvas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_canvasPrefsKey);
    _canvasLoaded = true;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final bgValue = decoded['bg'] as int?;
      final elementsRaw = (decoded['elements'] as List?) ?? [];
      final restored = elementsRaw
          .map((e) => CanvasElement.fromJson(e as Map<String, dynamic>))
          .toList();
      int maxIdNum = -1;
      for (final e in restored) {
        final m = RegExp(r'^el(\d+)$').firstMatch(e.id);
        if (m != null) {
          final n = int.tryParse(m.group(1)!) ?? -1;
          if (n > maxIdNum) maxIdNum = n;
        }
      }
      if (mounted) {
        setState(() {
          _elements
            ..clear()
            ..addAll(restored);
          if (bgValue != null) _canvasBg = Color(bgValue);
          _idCounter = maxIdNum + 1;
        });
      }
    } catch (_) {
      // Bozuk/okunamayan bir kayıt varsa sessizce yok say; canvas boş başlar.
    }
  }

  /// Canvas'ı diske yazar. Metin girişi gibi art arda hızlı tetiklenen
  /// değişikliklerde her tuş vuruşunda diske yazmamak için kısa bir
  /// gecikmeyle (debounce) biriktirir; ekran kapanırken (didChangeAppLifecycleState)
  /// ayrıca anında da kaydedilir.
  void _saveCanvas({bool immediate = false}) {
    if (!_canvasLoaded) return; // henüz yüklenmeden üzerine yazma
    _saveDebounce?.cancel();
    if (immediate) {
      _persistCanvasNow();
    } else {
      _saveDebounce = Timer(const Duration(milliseconds: 400), _persistCanvasNow);
    }
  }

  Future<void> _persistCanvasNow() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'bg': _canvasBg.value,
      'elements': _elements.map((e) => e.toJson()).toList(),
    };
    await prefs.setString(_canvasPrefsKey, jsonEncode(data));
  }

  Future<void> _clearPersistedCanvas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_canvasPrefsKey);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka plana alınırken/kapanırken canvas'ın kesinlikle
    // kaydedilmiş olmasını garanti eder.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _saveCanvas(immediate: true);
    }
  }

  // Sürükle/boyutlandır/döndür sırasında SADECE canvas içeriğini yeniden
  // çizdirmek için ayrı bir tetikleyici. setState() kullanırsak üst/alt araç
  // çubukları dahil TÜM ekran her parmak hareketinde yeniden inşa edilir ve
  // bu da donuk/yavaş bir sürükleme hissi yaratır. Bunun yerine bu tetikleyici
  // sadece ValueListenableBuilder ile sarılı canvas Stack'ini günceller.
  final ValueNotifier<int> _canvasTick = ValueNotifier<int>(0);
  void _repaintCanvas() => _canvasTick.value++;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    _persistCanvasNow();
    _canvasTick.dispose();
    super.dispose();
  }

  final List<List<CanvasElement>> _undoStack = [];
  final List<List<CanvasElement>> _redoStack = [];
  bool _dirtyEdit = false; // props panelinde art arda yapılan düzenlemeleri tek geçmiş adımında toplar

  bool _gridOn = false;
  bool _propsPanelOpen = false;
  Color _canvasBg = Colors.white;
  BuilderTemplate? _selectedTemplate;

  static const _colorPalette = <Color>[
    Colors.white,
    Colors.black,
    Color(0xFF26C6DA),
    Color(0xFF4FC3F7),
    Color(0xFFE1306C),
    Color(0xFF25D366),
    Color(0xFFFF7043),
    Color(0xFFAD1457),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFF1565C0),
    Color(0xFF37474F),
  ];

  String _newId() => 'el${_idCounter++}';

  CanvasElement? get _selectedElement {
    if (_selectedId == null) return null;
    for (final e in _elements) {
      if (e.id == _selectedId) return e;
    }
    return null;
  }

  // ------------------------------------------------------------------
  // Geri / İleri (undo / redo)
  // ------------------------------------------------------------------
  List<CanvasElement> _cloneAll() => _elements.map((e) => e.clone()).toList();

  void _pushHistory() {
    _undoStack.add(_cloneAll());
    if (_undoStack.length > 40) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) {
      _snack(t(context, 'Geri alınacak bir değişiklik yok.'));
      return;
    }
    _redoStack.add(_cloneAll());
    final prev = _undoStack.removeLast();
    setState(() {
      _elements
        ..clear()
        ..addAll(prev);
      _selectedId = null;
      _propsPanelOpen = false;
      _dirtyEdit = false;
    });
    _saveCanvas();
  }

  void _redo() {
    if (_redoStack.isEmpty) {
      _snack(t(context, 'İleri alınacak bir değişiklik yok.'));
      return;
    }
    _undoStack.add(_cloneAll());
    final next = _redoStack.removeLast();
    setState(() {
      _elements
        ..clear()
        ..addAll(next);
      _selectedId = null;
      _propsPanelOpen = false;
      _dirtyEdit = false;
    });
    _saveCanvas();
  }

  /// Props panelindeki düzenlemeler (TextField/slider/renk) için: aynı
  /// eleman üzerinde art arda yapılan değişiklikler geçmişte TEK adım
  /// olarak birikir; her tuş vuruşunda ayrı undo adımı oluşmaz.
  void _mutate(VoidCallback fn) {
    if (!_dirtyEdit) {
      _pushHistory();
      _dirtyEdit = true;
    }
    setState(fn);
    _saveCanvas();
  }

  void _snack(String text, {String icon = 'ℹ️'}) {
    showAppPopup(context, message: text, icon: icon);
  }

  void _toggleGrid() => setState(() => _gridOn = !_gridOn);

  void _selectElement(String id) {
    setState(() {
      _selectedId = id;
      _propsPanelOpen = true;
      _dirtyEdit = false;
    });
  }

  void _closeProps() => setState(() {
        _propsPanelOpen = false;
        _selectedId = null;
        _dirtyEdit = false;
      });

  void _deleteSelected() {
    final e = _selectedElement;
    if (e == null) return;
    _pushHistory();
    setState(() {
      _elements.removeWhere((el) => el.id == e.id);
      _selectedId = null;
      _propsPanelOpen = false;
      _dirtyEdit = false;
    });
    _saveCanvas();
  }

  // ------------------------------------------------------------------
  // Sürükleme / yeniden boyutlandırma
  // ------------------------------------------------------------------
  void _moveElement(CanvasElement e, Offset delta) {
    if (_canvasSize.isEmpty) return;
    // FİX: Bu GestureDetector elemanın kendi Transform.rotate'i İÇİNDE
    // olduğundan Flutter, onPanUpdate.delta'yı OTOMATİK olarak elemanın
    // yerel (döndürülmüş) eksenine göre verir (event.localDelta). Taşıma
    // ise kanvasın (döndürülmemiş) x/y eksenine ihtiyaç duyar — o yüzden
    // yerel deltayı ileri rotasyonla (R(theta)) kanvas eksenine geri
    // çeviriyoruz. Eskiden bu adım hiç yapılmıyordu; element döndürülünce
    // parmağın gittiği yönle elemanın gittiği yön birbirinden sapıyordu.
    final theta = e.rotation * math.pi / 180;
    final cosT = math.cos(theta);
    final sinT = math.sin(theta);
    final globalDx = delta.dx * cosT - delta.dy * sinT;
    final globalDy = delta.dx * sinT + delta.dy * cosT;

    double nx = e.x + globalDx / _canvasSize.width;
    double ny = e.y + globalDy / _canvasSize.height;
    if (_gridOn) {
      const step = 0.05;
      nx = (nx / step).round() * step;
      ny = (ny / step).round() * step;
    }
    e.x = nx.clamp(0.0, 1.0 - e.width);
    e.y = ny.clamp(0.0, 1.0 - e.height);
    _repaintCanvas();
  }

  /// index.html > initInteract() > .resizable({...}).listeners.move ile
  /// BİREBİR aynı mantık (piksel uzayında): parmağın ekran deltasını
  /// elemanın kendi (döndürülmüş) eksenine çevirip yeni width/height'ı
  /// hesaplıyor, image/shape/social için en-boy oranını koruyor, sonra
  /// rotasyona göre pozisyonu telafi ediyor — HTML referansındaki
  /// shiftX/shiftY/nextX/nextY formülleriyle aynı.
  double? _resizeAspectRatio;

  void _resizeElement(CanvasElement e, Offset delta) {
    if (_canvasSize.isEmpty) return;
    final theta = e.rotation * math.pi / 180;
    final cosT = math.cos(theta);
    final sinT = math.sin(theta);

    final widthPx = e.width * _canvasSize.width;
    final heightPx = e.height * _canvasSize.height;

    // FİX: Bu tutamaç da elemanın kendi Transform.rotate'i İÇİNDEKİ
    // GestureDetector'a bağlı, dolayısıyla delta Flutter tarafından ZATEN
    // elemanın yerel (döndürülmemiş) eksenine çevrilerek geliyor
    // (event.localDelta). Eskiden burada AYRICA cosT/sinT ile ters
    // döndürülüyordu — bu da rotasyonu iki kere tersine uyguluyordu (net
    // -2*theta). theta=90°'de büyütme/küçültme yönü çapraz kayıyor,
    // theta=180°'de "büyüt" hareketi fiilen küçültüyordu — bildirdiğin
    // birebir bu. Çözüm: delta'yı olduğu gibi kullan, ikinci kez döndürme.
    final localDx = delta.dx;
    final localDy = delta.dy;

    double newW = widthPx + localDx;
    double newH = heightPx + localDy;

    // index.html: isImage/isShape/isSocial için aspect ratio korunuyor,
    // hangi eksende daha fazla hareket varsa o eksen esas alınıyor.
    final ratioLocked = e.type == ElementType.image ||
        e.type == ElementType.shape ||
        e.type == ElementType.social;
    if (ratioLocked) {
      final ratio = _resizeAspectRatio ?? (heightPx == 0 ? 1.0 : widthPx / heightPx);
      if (localDy.abs() > localDx.abs()) {
        newH = heightPx + localDy;
        newW = newH * ratio;
      } else {
        newW = widthPx + localDx;
        newH = newW / ratio;
      }
    }

    if (_gridOn) {
      const step = 0.05;
      newW = ((newW / _canvasSize.width) / step).round() * step * _canvasSize.width;
      newH = ((newH / _canvasSize.height) / step).round() * step * _canvasSize.height;
    }

    // index.html: clamp(newW, 30, canvasRect.width) / clamp(newH, 30, canvasRect.height)
    newW = newW.clamp(24.0, _canvasSize.width * 4);
    newH = newH.clamp(24.0, _canvasSize.height * 4);

    final dW = newW - widthPx;
    final dH = newH - heightPx;

    // index.html: shiftX = (dW/2)*cosT - (dH/2)*sinT; shiftY = (dW/2)*sinT + (dH/2)*cosT
    final shiftX = (dW / 2) * cosT - (dH / 2) * sinT;
    final shiftY = (dW / 2) * sinT + (dH / 2) * cosT;

    final oldLeftPx = e.x * _canvasSize.width;
    final oldTopPx = e.y * _canvasSize.height;
    // index.html: nextX = trueX + dW/2 - shiftX; nextY = trueY + dH/2 - shiftY
    final nextLeftPx = oldLeftPx + (dW / 2) - shiftX;
    final nextTopPx = oldTopPx + (dH / 2) - shiftY;

    e.width = (newW / _canvasSize.width).clamp(0.03, 4.0);
    e.height = (newH / _canvasSize.height).clamp(0.02, 4.0);
    e.x = nextLeftPx / _canvasSize.width;
    e.y = nextTopPx / _canvasSize.height;
    _repaintCanvas();
  }

  /// index.html > initRotation()'daki ile birebir aynı mantık: canvas
  /// içindeki parmak/imleç konumunun, elemanın merkezine göre açısını
  /// (atan2) hesaplayıp 0-360° arasına normalize eder.
  void _rotateElement(CanvasElement e, Offset globalPosition) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _canvasSize.isEmpty) return;
    final local = box.globalToLocal(globalPosition);
    final centerX = (e.x + e.width / 2) * _canvasSize.width;
    final centerY = (e.y + e.height / 2) * _canvasSize.height;
    double angle = math.atan2(local.dy - centerY, local.dx - centerX) * 180 / math.pi + 90;
    angle = (angle + 360) % 360;
    e.rotation = (angle + 360) % 360;
    _repaintCanvas();
  }

  // ------------------------------------------------------------------
  // Eleman ekleme
  // ------------------------------------------------------------------
  void _addElement(CanvasElement e) {
    _pushHistory();
    setState(() {
      _elements.add(e);
      _selectedId = e.id;
      _propsPanelOpen = true;
      _dirtyEdit = false;
    });
    _saveCanvas();
  }

  void _addTextElement() {
    _addElement(CanvasElement(
      id: _newId(),
      type: ElementType.text,
      x: 0.1,
      y: 0.1,
      width: 0.8,
      height: 0.1,
      text: t(context, 'Yeni metin'),
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ));
  }

  Future<void> _addImageElement() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final ext = xfile.path.split('.').last.toLowerCase();
      _addElement(CanvasElement(
        id: _newId(),
        type: ElementType.image,
        x: 0.15,
        y: 0.25,
        width: 0.7,
        height: 0.3,
        imageBytes: bytes,
        imageExt: ext == 'png' ? 'png' : 'jpg',
      ));
    } catch (e) {
      _snack('${isEnglish(context) ? 'Could not add photo' : 'Fotoğraf eklenemedi'}: $e');
    }
  }

  void _addShapeElement(ShapeKind kind) {
    _addElement(CanvasElement(
      id: _newId(),
      type: ElementType.shape,
      x: 0.3,
      y: 0.4,
      width: 0.4,
      height: (kind == ShapeKind.circle || kind == ShapeKind.star) ? 0.2 : 0.15,
      shapeKind: kind,
      fillColor: AppColors.accentCyan,
      borderRadius: kind == ShapeKind.circle ? 999 : 12,
    ));
  }

  void _addButtonElement({required String label, required Color color, String link = ''}) {
    _addElement(CanvasElement(
      id: _newId(),
      type: ElementType.button,
      x: 0.15,
      y: 0.55,
      width: 0.7,
      height: 0.08,
      text: label,
      fillColor: color,
      color: Colors.white,
      borderRadius: 24,
      fontSize: 15,
      fontWeight: FontWeight.bold,
      link: link,
    ));
  }

  /// index.html > addSocial(): gerçek marka SVG'si, ikon-only, arka plan
  /// yok. Sürükle/boyutlandır/döndür canvas motoruyla aynı şekilde çalışır.
  Future<void> _addSocialElement(SocialPlatform platform) async {
    String link = SocialIcons.defaultLinkFor(platform);
    if (platform == SocialPlatform.whatsapp) {
      final phone = await showWhatsAppPhonePopup(context);
      if (phone == null) return; // vazgeçildi
      link = 'https://wa.me/$phone';
    }
    _addElement(CanvasElement(
      id: _newId(),
      type: ElementType.social,
      x: 0.4,
      y: 0.45,
      width: 0.16,
      height: 0.16,
      socialPlatform: platform,
      link: link,
    ));
  }

  void _addSection(String kind) {
    _pushHistory();
    final List<CanvasElement> group = [];
    if (kind == 'hero') {
      group.addAll([
        CanvasElement(
            id: _newId(),
            type: ElementType.text,
            x: 0.08,
            y: 0.08,
            width: 0.84,
            height: 0.1,
            text: t(context, 'Başlığını buraya yaz'),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87),
        CanvasElement(
            id: _newId(),
            type: ElementType.text,
            x: 0.1,
            y: 0.2,
            width: 0.8,
            height: 0.1,
            text: t(context, 'Kısa bir alt açıklama ekle'),
            fontSize: 13,
            color: Colors.black54),
        CanvasElement(
            id: _newId(),
            type: ElementType.button,
            x: 0.2,
            y: 0.34,
            width: 0.6,
            height: 0.08,
            text: t(context, 'Hemen Başla'),
            fillColor: AppColors.accentBlue,
            color: Colors.white,
            borderRadius: 24,
            fontSize: 14,
            fontWeight: FontWeight.bold),
      ]);
    } else {
      // iletişim bölümü
      group.addAll([
        CanvasElement(
            id: _newId(),
            type: ElementType.text,
            x: 0.1,
            y: 0.6,
            width: 0.8,
            height: 0.06,
            text: t(context, 'Bize Ulaş'),
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black87),
        CanvasElement(
            id: _newId(),
            type: ElementType.button,
            x: 0.15,
            y: 0.67,
            width: 0.7,
            height: 0.08,
            text: 'WhatsApp',
            fillColor: const Color(0xFF25D366),
            color: Colors.white,
            borderRadius: 24,
            fontSize: 14,
            fontWeight: FontWeight.bold),
        CanvasElement(
            id: _newId(),
            type: ElementType.button,
            x: 0.15,
            y: 0.77,
            width: 0.7,
            height: 0.08,
            text: 'Instagram',
            fillColor: const Color(0xFFE1306C),
            color: Colors.white,
            borderRadius: 24,
            fontSize: 14,
            fontWeight: FontWeight.bold),
      ]);
    }
    setState(() {
      _elements.addAll(group);
      _selectedId = group.first.id;
      _propsPanelOpen = true;
      _dirtyEdit = false;
    });
    _saveCanvas();
  }

  /// Builder Pro > "Çizim" aracı: kullanıcı serbest elle kendi
  /// şeklini/çizimini oluşturur; onaylandığında bu çizim canvas'a normal
  /// bir görsel (image) eleman olarak eklenir.
  void _showDrawingDialog() {
    showDrawingPadDialog(
      context,
      onAdd: (bytes) {
        _addElement(CanvasElement(
          id: _newId(),
          type: ElementType.image,
          x: 0.2,
          y: 0.3,
          width: 0.6,
          height: 0.3,
          imageBytes: bytes,
          imageExt: 'png',
        ));
      },
    );
  }

  Future<void> _openBackgroundPicker() async {
    final picked = await showModalBottomSheet<Color>(
      context: context,
      backgroundColor: const Color(0xFF141821),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(context, '🎨 Arka Plan Rengi'),
                style: const TextStyle(
                    color: AppColors.accentOrange,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 15)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colorPalette
                  .map((c) => GestureDetector(
                        onTap: () => Navigator.of(context).pop(c),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1.4),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      _pushHistory();
      setState(() => _canvasBg = picked);
      _saveCanvas();
    }
  }

  void _showShapeMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141821),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.crop_square, color: Colors.white70),
              title: Text(t(context, 'Kare / Dikdörtgen'),
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
              onTap: () {
                Navigator.of(context).pop();
                _addShapeElement(ShapeKind.rectangle);
              },
            ),
            ListTile(
              leading: const Icon(Icons.circle_outlined, color: Colors.white70),
              title: Text(t(context, 'Daire'),
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
              onTap: () {
                Navigator.of(context).pop();
                _addShapeElement(ShapeKind.circle);
              },
            ),
            ListTile(
              leading: const Icon(Icons.change_history, color: Colors.white70),
              title: Text(t(context, 'Üçgen'),
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
              onTap: () {
                Navigator.of(context).pop();
                _addShapeElement(ShapeKind.triangle);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_border, color: Colors.white70),
              title: Text(t(context, 'Yıldız'),
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
              onTap: () {
                Navigator.of(context).pop();
                _addShapeElement(ShapeKind.star);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSectionMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141821),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🚀', style: TextStyle(fontSize: 18)),
              title: Text(t(context, 'Kahraman Bölüm (başlık + CTA)'),
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13)),
              onTap: () {
                Navigator.of(context).pop();
                _addSection('hero');
              },
            ),
            ListTile(
              leading: const Text('📞', style: TextStyle(fontSize: 18)),
              title: Text(t(context, 'İletişim Bölümü (WA + IG)'),
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13)),
              onTap: () {
                Navigator.of(context).pop();
                _addSection('contact');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Şablonlar: canvas'a gerçek, düzenlenebilir elemanlar yerleştirir.
  // ------------------------------------------------------------------
  bool _isLight(Color c) => c.computeLuminance() > 0.5;

  List<CanvasElement> _buildTemplateElements(BuilderTemplate tpl) {
    final onBg = _isLight(tpl.bgColor) ? Colors.black87 : Colors.white;
    final onBgMuted = _isLight(tpl.bgColor) ? Colors.black54 : Colors.white70;
    return [
      CanvasElement(
        id: _newId(),
        type: ElementType.text,
        x: 0.08,
        y: 0.06,
        width: 0.84,
        height: 0.08,
        text: '${tpl.emoji} ${t(context, tpl.name)}',
        fontSize: 21,
        fontWeight: FontWeight.bold,
        color: onBg,
      ),
      CanvasElement(
        id: _newId(),
        type: ElementType.shape,
        shapeKind: ShapeKind.rectangle,
        x: 0.3,
        y: 0.155,
        width: 0.4,
        height: 0.006,
        fillColor: tpl.accent,
        borderRadius: 4,
      ),
      CanvasElement(
        id: _newId(),
        type: ElementType.text,
        x: 0.1,
        y: 0.19,
        width: 0.8,
        height: 0.13,
        text: t(context, tpl.description),
        fontSize: 12.5,
        color: onBgMuted,
      ),
      CanvasElement(
        id: _newId(),
        type: ElementType.shape,
        shapeKind: ShapeKind.rectangle,
        x: 0.12,
        y: 0.37,
        width: 0.76,
        height: 0.26,
        fillColor: tpl.accent.withOpacity(0.14),
        borderRadius: 16,
      ),
      CanvasElement(
        id: _newId(),
        type: ElementType.text,
        x: 0.12,
        y: 0.47,
        width: 0.76,
        height: 0.08,
        text: t(context, 'Görsel alanı — 🖼️ ile fotoğraf ekle'),
        fontSize: 11,
        color: tpl.accent,
      ),
      CanvasElement(
        id: _newId(),
        type: ElementType.button,
        x: 0.18,
        y: 0.72,
        width: 0.64,
        height: 0.08,
        text: t(context, tpl.ctaLabel),
        fillColor: tpl.accent,
        color: Colors.white,
        borderRadius: 24,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    ];
  }

  void _applyTemplate(BuilderTemplate tpl) {
    _pushHistory();
    final elements = _buildTemplateElements(tpl);
    setState(() {
      _elements
        ..clear()
        ..addAll(elements);
      _canvasBg = tpl.bgColor;
      _selectedTemplate = tpl;
      _selectedId = null;
      _propsPanelOpen = false;
      _dirtyEdit = false;
    });
    _saveCanvas();
    Navigator.of(context).pop(); // sheet'i kapat
    _snack(isEnglish(context)
        ? '${tpl.emoji} "${t(context, tpl.name)}" template placed on the canvas. Tap elements to edit them.'
        : '${tpl.emoji} "${t(context, tpl.name)}" şablonu canvas\'a yerleşti. Elemanlara dokunarak düzenleyebilirsiniz.');
  }

  void _openTemplatesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141821),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Text(t(context, '📑 Şablonlar'),
                          style: const TextStyle(
                              color: AppColors.accentOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: kBuilderTemplates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final tpl = kBuilderTemplates[index];
                      final selected = identical(_selectedTemplate, tpl);
                      return Material(
                        color: const Color(0xFF1C232E),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _applyTemplate(tpl),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? tpl.accent : Colors.white12,
                                width: selected ? 1.4 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: tpl.bgColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: tpl.accent, width: 1),
                                  ),
                                  child: Text(tpl.emoji, style: const TextStyle(fontSize: 20)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t(context, tpl.name),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                              fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text(t(context, tpl.category),
                                          style: TextStyle(
                                              color: tpl.accent,
                                              fontFamily: 'monospace',
                                              fontSize: 10.5)),
                                      const SizedBox(height: 4),
                                      Text(t(context, tpl.description),
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                              height: 1.3)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // HTML dışa aktarma
  // ------------------------------------------------------------------
  String _colorToHex(Color c) => '#${c.value.toRadixString(16).substring(2)}';

  String _escapeHtml(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  String _alignCss(TextAlign a) =>
      a == TextAlign.left ? 'left' : a == TextAlign.right ? 'right' : 'center';

  String _flexAlign(TextAlign a) =>
      a == TextAlign.left ? 'flex-start' : a == TextAlign.right ? 'flex-end' : 'center';

  /// index.html > buildHTML(): "font-size: clamp(12px, Xcqw, 72px)". Editör
  /// canvas'ı, tasarımı yapan kişinin KENDİ cihaz ekranına göre boyutlanıyor
  /// (AspectRatio 9:17 + LayoutBuilder). Yazı boyutunu olduğu gibi sabit
  /// px olarak dışa aktarırsak, siteyi ziyaret eden kişinin ekranı tasarım
  /// yapılan cihazdan küçük/büyükse yazı kutuya göre orantısız (taşan ya da
  /// gereğinden küçük) görünür. Bunun yerine tasarım anındaki canvas
  /// genişliğine ORANLA bir değer hesaplayıp clamp() ile alt/üst sınır
  /// koyuyoruz — böylece dışa aktarılan site HANGİ CİHAZDA açılırsa
  /// açılsın metin kutuyla orantılı, okunur kalıyor.
  ///
  /// 2026-08-24 DÜZELTME: birim 'vw' (TARAYICI PENCERESİ genişliği) yerine
  /// 'cqw' (CSS Container Query birimi — .astro-canvas KONTEYNERİNİN
  /// genişliği) yapıldı. Eskiden mobilde canvas zaten ~pencere genişliği
  /// kadar olduğu için 'vw' tesadüfen doğru çalışıyordu; ama masaüstünde
  /// canvas 480px'de sabitken pencere 1500-2000px olunca 'vw' hesabı
  /// PENCEREYE göre devasa büyüyor, yazılar kutudan taşıyordu — masaüstünde
  /// "bozuk" görünmesinin asıl sebebi buydu. 'cqw' ise HER ZAMAN gerçek
  /// canvas konteynerinin genişliğine göre hesaplanır (bkz. _buildExportHtml
  /// içindeki `container-type:inline-size` — modern tarayıcıların hepsinde
  /// 2022'den beri destekleniyor), bu yüzden canvas ister 375px (telefon)
  /// ister 480px (masaüstü kartı) olsun, oranlar HER ZAMAN doğru kalıyor.
  String _responsiveFontSize(double px) {
    final refW = _canvasSize.width > 0 ? _canvasSize.width : 375.0;
    final cqw = (px / refW * 100).toStringAsFixed(2);
    final minPx = (px * 0.55).clamp(9.0, px).toStringAsFixed(0);
    final maxPx = (px * 1.8).clamp(px, 96.0).toStringAsFixed(0);
    return 'clamp(${minPx}px, ${cqw}cqw, ${maxPx}px)';
  }

  /// index.html'deki şekil kütüphanesinin CSS karşılığı: dikdörtgen/daire
  /// border-radius ile, üçgen/yıldız ise clip-path polygon ile çizilir.
  String? _shapeClipPathCss(ShapeKind k) {
    switch (k) {
      case ShapeKind.triangle:
        return 'polygon(50% 0%, 0% 100%, 100% 100%)';
      case ShapeKind.star:
        return 'polygon(50% 0%, 61% 35%, 98% 35%, 68% 57%, 79% 91%, 50% 70%, 21% 91%, 32% 57%, 2% 35%, 39% 35%)';
      case ShapeKind.circle:
      case ShapeKind.rectangle:
        return null;
    }
  }

  String _elementToHtml(CanvasElement e) {
    final left = (e.x * 100).toStringAsFixed(2);
    final top = (e.y * 100).toStringAsFixed(2);
    final w = (e.width * 100).toStringAsFixed(2);
    final h = (e.height * 100).toStringAsFixed(2);
    // index.html > transform: rotate(${rot}deg) — tüm eleman tipleri için
    // ortak döndürme desteği.
    final base = 'left:$left%;top:$top%;width:$w%;height:$h%;'
        'transform:rotate(${e.rotation.toStringAsFixed(1)}deg);';

    switch (e.type) {
      case ElementType.text:
        return '<div class="astro-el" style="$base display:flex;align-items:center;'
            'justify-content:${_flexAlign(e.textAlign)};text-align:${_alignCss(e.textAlign)};'
            'font-size:${_responsiveFontSize(e.fontSize)};font-weight:${e.fontWeight == FontWeight.bold ? 700 : 400};'
            'color:${_colorToHex(e.color)};line-height:1.3;">${_escapeHtml(e.text)}</div>';
      case ElementType.image:
        final b64 = e.imageBytes != null ? base64Encode(e.imageBytes!) : '';
        final mime = e.imageExt == 'png' ? 'image/png' : 'image/jpeg';
        return '<img class="astro-el" style="$base object-fit:cover;border-radius:${e.borderRadius}px;" '
            'src="data:$mime;base64,$b64" />';
      case ElementType.shape:
        final clip = _shapeClipPathCss(e.shapeKind);
        final clipStyle = clip != null ? 'clip-path:$clip;' : '';
        final radius = e.shapeKind == ShapeKind.circle ? '50%' : '${e.borderRadius}px';
        // index.html > shape_img: fotoğraf varsa şeklin siluetine kırpılmış
        // gerçek bir <img> etiketi, yoksa düz renk dolgulu bir <div>.
        if (e.imageBytes != null) {
          final b64 = base64Encode(e.imageBytes!);
          final mime = e.imageExt == 'png' ? 'image/png' : 'image/jpeg';
          return '<img class="astro-el" style="$base object-fit:cover;border-radius:$radius;$clipStyle" '
              'src="data:$mime;base64,$b64" />';
        }
        return '<div class="astro-el" style="$base background:${_colorToHex(e.fillColor)};'
            'border-radius:$radius;$clipStyle"></div>';
      case ElementType.button:
        final href = e.link.isEmpty ? '#' : e.link;
        return '<a class="astro-el" href="${_escapeHtml(href)}" style="$base display:flex;'
            'align-items:center;justify-content:center;background:${_colorToHex(e.fillColor)};'
            'color:${_colorToHex(e.color)};border-radius:${e.borderRadius}px;font-size:${_responsiveFontSize(e.fontSize)};'
            'font-weight:700;text-decoration:none;">${_escapeHtml(e.text)}</a>';
      case ElementType.social:
        // index.html > addSocial(): gerçek marka SVG'si doğrudan gömülür.
        final href = e.link.isEmpty ? '#' : e.link;
        final svg = SocialIcons.forPlatform(e.socialPlatform ?? SocialPlatform.whatsapp);
        return '<a class="astro-el" href="${_escapeHtml(href)}" style="$base display:block;">$svg</a>';
    }
  }

  /// 2026-08-24: Masaüstü uyumluluk düzeltmesi. Bu canvas serbest
  /// sürükle-bırak (elemanlar canvas üzerinde HERHANGİ bir yere
  /// konabiliyor) ile çalıştığı için, gerçek "masaüstünde farklı sütun
  /// düzeni" (Elementor/Webflow tarzı ayrı bir masaüstü yerleşimi) BÜYÜK
  /// bir özellik gerektirir — ayrı bir masaüstü canvas modu demektir.
  /// Burada yapılan, ondan farklı ama gerçek: (1) yazı boyutlarının artık
  /// 'cqw' kullanması (bkz. _responsiveFontSize) sayesinde masaüstünde
  /// metinlerin kutudan TAŞMASI/bozulması düzeltildi — bu gerçek bir
  /// hataydı; (2) canvas'ın masaüstünde ekranın ortasında küçük/kayıp
  /// görünmesi yerine, kasıtlı tasarlanmış gölgeli/yuvarlak köşeli bir
  /// "kart" olarak ortalanması — bio-link/tek sayfa sitelerde (Linktree
  /// vb.) yaygın ve kabul görmüş bir masaüstü sunum şekli.
  String _buildExportHtml() {
    final sorted = [..._elements]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="tr"><head><meta charset="UTF-8">')
      ..writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">')
      ..writeln('<title>Sitora Builder Pro</title>')
      ..writeln('<style>')
      ..writeln('*{box-sizing:border-box;}')
      ..writeln('html,body{margin:0;min-height:100%;}')
      ..writeln('body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;'
          'background:#0D0D0D;display:flex;justify-content:center;'
          'align-items:flex-start;min-height:100vh;}')
      // container-type:inline-size -> içindeki .astro-el'lerin kullandığı
      // 'cqw' birimi artık PENCEREYE değil BU KONTEYNERE göre hesaplanıyor
      // (bkz. _responsiveFontSize açıklaması) — masaüstü taşma hatasının
      // asıl düzeltmesi burası.
      ..writeln('.astro-canvas{position:relative;container-type:inline-size;'
          'width:100%;max-width:480px;aspect-ratio:9/17;'
          'background:${_colorToHex(_canvasBg)};overflow:hidden;}')
      ..writeln('.astro-el{position:absolute;}')
      // 900px+ (tablet/masaüstü) genişlikte: canvas'ı ekranın ortasına,
      // etrafında boşluk bırakan, gölgeli/yuvarlak köşeli bir "kart"
      // olarak sunuyoruz — artık ekranın küçük bir köşesinde kayıp
      // durmuyor, kasıtlı tasarlanmış gibi görünüyor.
      ..writeln('@media (min-width:900px){'
          'body{align-items:center;padding:48px 20px;}'
          '.astro-canvas{border-radius:32px;'
          'box-shadow:0 30px 90px rgba(0,0,0,0.55),0 0 0 1px rgba(255,255,255,0.06);}'
          '}')
      ..writeln('</style></head><body>')
      ..writeln('<div class="astro-canvas">');
    for (final e in sorted) {
      buffer.writeln(_elementToHtml(e));
    }
    buffer
      ..writeln('</div>')
      ..writeln('</body></html>');
    return buffer.toString();
  }

  Future<void> _confirmClearCanvas() async {
    if (_elements.isEmpty) {
      _snack(t(context, 'Canvas zaten boş.'));
      return;
    }
    final confirmed = await showConfirmPopup(
      context,
      title: t(context, 'Tasarımı Sil'),
      message: t(context,
          'Canvas üzerindeki tüm elemanlar silinecek. Bu işlem geri alınamaz. Silmek istediğinizden emin misiniz?'),
      icon: '🗑️',
      confirmLabel: t(context, 'Evet, Sil'),
      cancelLabel: t(context, 'Vazgeç'),
    );
    if (!confirmed) return;
    _pushHistory();
    setState(() {
      _elements.clear();
      _selectedId = null;
      _propsPanelOpen = false;
    });
    _saveDebounce?.cancel();
    await _clearPersistedCanvas();
    _snack(t(context, 'Tasarım silindi.'), icon: '🗑️');
  }

  /// [_exportAndDownload] ile [_saveOnly] arasında PAYLAŞILAN ortak çekirdek:
  /// puan kontrolü + Projelerim'e kayıt + (yeni projede) puan düşme.
  /// Dosya indirme burada YOK — o sadece _exportAndDownload'da.
  /// Döner: null = kullanıcı devam edemedi (boş canvas/kota doldu/hata,
  /// zaten kendi mesajını gösterdi), aksi halde nihai HTML.
  Future<String?> _persistToProjects() async {
    if (_elements.isEmpty) {
      _snack(t(context, 'Canvas boş — önce bir şablon seçiniz ya da eleman ekleyiniz.'));
      return null;
    }
    final appState = context.read<AppState>();

    // 2026-08-20: Builder Pro da tek sayfa üretimidir, form akışındaki
    // "Tek Sayfa" üretimiyle AYNI ortak puan havuzundan 5 puan düşer
    // (bkz. AppState.costSinglePage). SADECE bu canvas'ın İLK
    // kaydında/export'unda (_savedProjectId henüz null'sa, yani YENİ bir
    // "Projelerim" kaydı açılacaksa) puan harcanır — aynı tasarımı tekrar
    // tekrar kaydetmek/indirmek (mevcut projeyi güncellemek) form
    // akışında da ücretsiz olduğu gibi burada da ücretsizdir.
    final isNewProject = _savedProjectId == null;
    if (isNewProject) {
      if (!await appState.ensureFormQuotaFor(AppState.costSinglePage)) {
        if (mounted) await showQuotaLimitPopup(context);
        return null;
      }
    }

    // 2026-08-20: form akışıyla BİREBİR AYNI kural — watermark ve
    // "Projelerim" kaydı burada, tek çağrıda hallediliyor. Dönen
    // (watermark uygulanmış/uygulanmamış) NİHAİ içerik indirilen dosyayla
    // Projelerim'deki kayıt birebir aynı olsun diye appState.projects'ten
    // geri okunuyor — _buildExportHtml() çıktısı DEĞİL.
    _savedProjectId = await appState.saveBuilderProject(
      html: _buildExportHtml(),
      projectId: _savedProjectId,
      nameHint: 'Builder Pro Tasarımı',
    );
    final finalHtml =
        appState.projects.firstWhere((p) => p.id == _savedProjectId).code;

    if (isNewProject) {
      await appState.consumeFormQuota(AppState.costSinglePage);
    }
    return finalHtml;
  }

  /// YENİ (2026-08-24): "Kaydet" butonu — sadece Projelerim'e kaydeder,
  /// cihaza dosya indirme penceresi AÇMAZ. Kullanıcı ilerleme kaydetmek
  /// istediğinde (henüz bitirmediği bir tasarımı) her seferinde dosya
  /// kaydetme diyaloğuyla uğraşmasın diye eklendi. Puan kuralı
  /// [_exportAndDownload] ile AYNI: sadece ilk kayıtta düşer.
  Future<void> _saveOnly() async {
    try {
      final finalHtml = await _persistToProjects();
      if (finalHtml == null) return; // _persistToProjects zaten mesaj gösterdi
      _snack(t(context, 'Projelerim\'e kaydedildi! 📁'), icon: '✅');
    } catch (e) {
      _snack('${isEnglish(context) ? 'Save failed' : 'Kaydetme başarısız'}: $e');
    }
  }

  /// 28.08.2026 değiştirildi, 28.08.2026'da fiyat/akış revizyonuyla
  /// güncellendi — İNDİRME artık ücretsiz "reklam izle" akışı DEĞİL, HER
  /// ZAMAN ücretli bir kilit (bkz. widgets/download_purchase_sheet.dart).
  /// _persistToProjects() ÖNCE çağrılır ki popup'ın hangi projeye
  /// uygulanacağını bilmesi için _savedProjectId dolu olsun; proje zaten
  /// indirme hakkına (downloadPurchased) sahipse popup HİÇ gösterilmez —
  /// rozet kaldırılmış olması (watermarkRemoved) TEK BAŞINA bunu sağlamaz.
  Future<void> _exportAndDownload() async {
    try {
      final finalHtml = await _persistToProjects();
      if (finalHtml == null) return; // _persistToProjects zaten mesaj gösterdi

      final appState = context.read<AppState>();
      if (!appState.canDownloadFreely(_savedProjectId)) {
        final idx = appState.projects.indexWhere((p) => p.id == _savedProjectId);
        if (idx == -1) {
          _snack(t(context, 'Önce bir site oluşturmanız gerekiyor.'), icon: 'ℹ️');
          return;
        }
        final SiteProject project = appState.projects[idx];
        final proceed = await showDownloadPurchaseSheet(context, project: project);
        if (!proceed || !mounted) return;
      }

      final saved = await DownloadService.pickAndSaveHtml(
        html: finalHtml,
        suggestedFileName: 'builder_site.html',
        isEnglish: isEnglish(context),
      );
      if (saved) {
        _snack(t(context, 'HTML dosyası cihaza kaydedildi ve Projelerim\'e eklendi! 💾'), icon: '✅');
      } else {
        // Kullanıcı kayıt penceresini iptal etti — dosya inmedi ama
        // Projelerim'e ekleme/güncelleme YİNE DE gerçekleşti (kasıtlı:
        // aksi halde "indirmeden vazgeç" ile "Projelerim'e hiç ekleme"
        // birbirine karışır, kullanıcı tasarımını kaybetmiş olur).
        _snack(t(context, 'Projelerim\'e kaydedildi (dosya indirilmedi).'), icon: '📁');
      }
    } catch (e) {
      _snack('${isEnglish(context) ? 'Download failed' : 'İndirme başarısız'}: $e');
    }
  }

  // ------------------------------------------------------------------
  // Arayüz
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopTools(),
                Expanded(child: _buildWorkspace()),
                _buildBottomToolbar(),
              ],
            ),
            if (_propsPanelOpen && _selectedElement != null) _buildPropsPanel(),
          ],
        ),
      ),
    );
  }

  /// index.html'in üst araç çubuğu — home_screen.dart > _buildTopPanel ile
  /// AYNI "stabil" desen: tüm satır [FittedBox(scaleDown)] içine alınır.
  /// Doğal genişliği ekrana sığmazsa (küçük telefon) TÜM butonlar orantılı
  /// şekilde birlikte küçülür; sığıyorsa olduğu boyutta kalır. Önceki halde
  /// sol taraf (Geri/İleri/Izgara) ayrı bir scroll view'de, İndir/Sil/Kapat
  /// ise sabit boyutta olduğu için dar ekranlarda İndir ve Sil üst üste
  /// binebiliyordu; artık hepsi TEK satırda ve TEK ölçekte, taşma/örtüşme
  /// hiçbir ekran boyutunda mümkün değil.
  Widget _buildTopTools() {
    return Container(
      color: const Color(0xFF141821),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        height: 34,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _topToolBtn(icon: Icons.undo, label: 'Geri', onTap: _undo),
              _topToolBtn(icon: Icons.redo, label: t(context, 'İleri'), onTap: _redo),
              _topToolBtn(
                icon: Icons.grid_on,
                label: 'Izgara',
                active: _gridOn,
                onTap: _toggleGrid,
              ),
              _topToolBtn(
                icon: Icons.save_outlined,
                label: 'Kaydet',
                accent: AppColors.accentCyan,
                onTap: _saveOnly,
              ),
              _topToolBtn(
                icon: Icons.file_download_outlined,
                label: t(context, 'İndir'),
                accent: AppColors.accentBlue,
                onTap: _exportAndDownload,
              ),
              _topToolBtn(
                icon: Icons.delete_outline,
                label: 'Sil',
                accent: AppColors.danger,
                onTap: _confirmClearCanvas,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                tooltip: t(context, 'Kapat'),
                onPressed: () => Navigator.of(context).maybePop(),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topToolBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    Color accent = Colors.white70,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: active ? AppColors.accentCyan : accent,
          side: BorderSide(color: active ? AppColors.accentCyan : Colors.white24),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 34),
        ),
        icon: Icon(icon, size: 16),
        label: Text(t(context, label), style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5)),
      ),
    );
  }

  /// index.html > #workspace / #canvas — artık gerçek elemanlar barındıran
  /// çalışma alanı: sürükle, seç, yeniden boyutlandır.
  Widget _buildWorkspace() {
    return GestureDetector(
      onTap: _closeProps,
      child: Container(
        color: const Color(0xFF05070A),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: 9 / 17,
          child: Container(
            decoration: BoxDecoration(
              color: _canvasBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24, width: 1),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8)),
              ],
            ),
            // ÖNEMLİ: Bu dış kutuda artık clipBehavior YOK. Önceden
            // Clip.antiAlias buradaydı ve döndürme tutamacı — ki elemanın
            // üst kenarının her zaman 30px ÜSTÜNDE konumlanıyor — canvas'a
            // yakın (y≈0) elemanlarda bu kırpma sınırının dışına düşüp
            // TAMAMEN GÖRÜNMEZ oluyordu (boyutlandırma tutamacı sağ-altta
            // olduğu için bu sorunu yaşamıyordu, sadece döndürme etkileniyordu).
            // Köşe yuvarlama artık sadece arka plan/grid'i saran ayrı bir
            // ClipRRect ile yapılıyor; elemanlar ve tutamaçlar bu kırpmanın
            // DIŞINDA, kırpılmayan bir katmanda kalıyor.
            clipBehavior: Clip.none,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _canvasSize = constraints.biggest;
                return ValueListenableBuilder<int>(
                  valueListenable: _canvasTick,
                  builder: (context, _, __) {
                    return Stack(
                      key: _canvasKey,
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                if (_gridOn) const _GridOverlay(),
                                if (_elements.isEmpty)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        t(context, 'Canvas hazır.\nAlt taraftaki araçlarla\nsitenizi tasarlamaya başlayabilirsiniz.'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.black26,
                                            fontFamily: 'monospace',
                                            fontSize: 12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        ..._elements.map((e) => _buildDraggableElement(e)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Tutamaçlar (döndürme/boyutlandırma) elemanın kutusunun DIŞINDA
  // (negatif offset) duruyordu. Flutter'da bir Stack, kendi sınırlarının
  // dışına taşan (overflow) çocuklarına normalde dokunma testini
  // ULAŞTIRMAZ — bu yüzden döndürme tutamacı tamamen tıklanamaz, yeniden
  // boyutlandırma tutamacı da yarı yarıya tıklanamaz durumdaydı. Çözüm:
  // elemanın etrafına tutamaçları da içine alacak kadar "pay" (pad) bırakan
  // daha büyük bir kutu içinde, tutamaçları o kutunun İÇİNDE (pozitif
  // koordinatlarda) konumlandırmak.
  //
  // Tutamaçlar artık elemanla BİRLİKTE dönüyor: element + iki tutamaç aynı
  // Transform.rotate içine alınıp kutunun tam merkezi etrafında (elemanın
  // merkeziyle birebir aynı nokta) döndürülüyor. Böylece 360° döndürürken
  // tutamaçlar hep görselin köşesinde/üstünde kalır — göz takip etmesi ve
  // işlem yapması çok daha kolay olur. Flutter'ın Transform'u dokunma
  // testini de aynı ters-matrisle çevirdiği için tutamaçlar döndürülmüş
  // haldeyken de tam isabetle sürüklenebilir kalıyor.
  static const double _handlePad = 34;

  // ÖNEMLİ: Eskiden taşıma / resize / rotate için üç AYRI GestureDetector
  // vardı ve resize tutamacının hit-alanı (köşede) taşıma alanıyla ~9px
  // kesişiyordu. Aynı pointer için iki farklı Pan recognizer aynı gesture
  // arena'ya girince kazanan RASTGELE gibi davranıyordu — bazen resize
  // yerine taşıma tetikleniyor, eleman zıplıyor/"saçmalıyor"du. Çözüm: TEK
  // bir GestureDetector kullanıp hangi moda (move/resize/rotate) girileceğine
  // parmağın ilk temas noktasına (onPanDown) bakarak KENDİMİZ karar veriyoruz
  // — böylece arena çakışması tamamen ortadan kalkıyor.
  String? _dragMode; // 'move' | 'resize' | 'rotate' | null

  Widget _buildDraggableElement(CanvasElement e) {
    final selected = _selectedId == e.id;
    final left = e.x * _canvasSize.width;
    final top = e.y * _canvasSize.height;
    final w = e.width * _canvasSize.width;
    final h = e.height * _canvasSize.height;
    const pad = _handlePad;
    final resizeCenter = Offset(pad + w, pad + h);
    final rotateCenter = Offset(pad + w / 2, pad - 15);
    final contentRect = Rect.fromLTWH(pad, pad, w, h);

    return Positioned(
      left: left - pad,
      top: top - pad,
      width: w + pad * 2,
      height: h + pad * 2,
      child: Transform.rotate(
        angle: e.rotation * math.pi / 180,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectElement(e.id),
          onPanDown: (details) {
            final p = details.localPosition;
            if (selected && (p - resizeCenter).distance <= 20) {
              _dragMode = 'resize';
              // index.html > resizable().listeners.start:
              // target.dataset.aspectRatio = currentW / currentH
              final wPx = e.width * _canvasSize.width;
              final hPx = e.height * _canvasSize.height;
              _resizeAspectRatio = hPx == 0 ? 1.0 : wPx / hPx;
            } else if (selected && (p - rotateCenter).distance <= 22) {
              _dragMode = 'rotate';
            } else if (contentRect.contains(p)) {
              _dragMode = 'move';
              _selectElement(e.id);
            } else {
              _dragMode = null;
            }
            if (_dragMode != null) _pushHistory();
          },
          onPanUpdate: (details) {
            switch (_dragMode) {
              case 'resize':
                _resizeElement(e, details.delta);
                break;
              case 'rotate':
                _rotateElement(e, details.globalPosition);
                break;
              case 'move':
                _moveElement(e, details.delta);
                break;
            }
          },
          onPanEnd: (_) {
            if (_dragMode != null) _saveCanvas();
            _dragMode = null;
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Elemanın kendisi (dönüş dışarıdaki Transform.rotate'ten
              // geliyor, burada tekrar döndürmüyoruz).
              Positioned(
                left: pad,
                top: pad,
                width: w,
                height: h,
                child: RepaintBoundary(
                  child: IgnorePointer(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: _buildElementContent(e)),
                        if (selected)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.accentCyan, width: 1.6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Yeniden boyutlandırma tutamacı — artık salt görsel; hit-test
              // yukarıdaki tek GestureDetector'da onPanDown ile yapılıyor.
              if (selected)
                Positioned(
                  left: resizeCenter.dx - 11,
                  top: resizeCenter.dy - 11,
                  child: IgnorePointer(
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              // Döndürme tutamacı — index.html > .rotate-handle — salt görsel.
              if (selected)
                Positioned(
                  left: rotateCenter.dx - 15,
                  top: rotateCenter.dy - 15,
                  child: IgnorePointer(
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.accentCyan,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 6)],
                        ),
                        child: const Text('🔄', style: TextStyle(fontSize: 12)),
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

  Widget _buildElementContent(CanvasElement e) {
    switch (e.type) {
      case ElementType.text:
        return Align(
          alignment: e.textAlign == TextAlign.left
              ? Alignment.centerLeft
              : e.textAlign == TextAlign.right
                  ? Alignment.centerRight
                  : Alignment.center,
          child: Text(
            e.text,
            textAlign: e.textAlign,
            style: TextStyle(
              fontSize: e.fontSize,
              fontWeight: e.fontWeight,
              color: e.color,
            ),
          ),
        );
      case ElementType.image:
        return e.imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(e.borderRadius),
                child: Image.memory(e.imageBytes!, fit: BoxFit.cover),
              )
            : Container(
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(e.borderRadius),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.image_outlined, color: Colors.black38),
              );
      case ElementType.shape:
        final Widget inner = e.imageBytes != null
            ? Image.memory(e.imageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
            : Container(color: e.fillColor);
        switch (e.shapeKind) {
          case ShapeKind.circle:
            return ClipOval(child: inner);
          case ShapeKind.triangle:
            return ClipPath(clipper: _TriangleClipper(), child: inner);
          case ShapeKind.star:
            return ClipPath(clipper: _StarClipper(), child: inner);
          case ShapeKind.rectangle:
            return ClipRRect(
              borderRadius: BorderRadius.circular(e.borderRadius),
              child: inner,
            );
        }
      case ElementType.button:
        return Container(
          decoration: BoxDecoration(
            color: e.fillColor,
            borderRadius: BorderRadius.circular(e.borderRadius),
          ),
          alignment: Alignment.center,
          child: Text(
            e.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: e.color,
              fontSize: e.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case ElementType.social:
        return SvgPicture.string(
          SocialIcons.forPlatform(e.socialPlatform ?? SocialPlatform.whatsapp),
          fit: BoxFit.contain,
        );
    }
  }

  /// index.html > #props-panel — seçili elemanın gerçek özelliklerini
  /// gösterir ve düzenletir.
  Widget _buildPropsPanel() {
    final e = _selectedElement!;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 340),
        decoration: const BoxDecoration(
          color: Color(0xFF141821),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(t(context, 'Düzenle'),
                        style: const TextStyle(
                            color: AppColors.accentOrange,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace')),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                    onPressed: _deleteSelected,
                    tooltip: t(context, 'Sil'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                    onPressed: _closeProps,
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),
              ..._propsFieldsFor(e),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _propsFieldsFor(CanvasElement e) {
    switch (e.type) {
      case ElementType.text:
        return [
          TextFormField(
            key: ValueKey('text-${e.id}'),
            initialValue: e.text,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: t(context, 'Metin'),
              labelStyle: const TextStyle(color: Colors.white54),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
            maxLines: 3,
            onChanged: (v) => _mutate(() => e.text = v),
          ),
          const SizedBox(height: 12),
          _labeled('Yazı Boyutu', Slider(
            value: e.fontSize.clamp(10, 48),
            min: 10,
            max: 48,
            activeColor: AppColors.accentCyan,
            onChanged: (v) => _mutate(() => e.fontSize = v),
          )),
          Row(
            children: [
              Expanded(
                child: _toggleChip(
                  label: t(context, 'Kalın'),
                  active: e.fontWeight == FontWeight.bold,
                  onTap: () => _mutate(() =>
                      e.fontWeight = e.fontWeight == FontWeight.bold ? FontWeight.normal : FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              _alignBtn(e, TextAlign.left, Icons.format_align_left),
              _alignBtn(e, TextAlign.center, Icons.format_align_center),
              _alignBtn(e, TextAlign.right, Icons.format_align_right),
            ],
          ),
          const SizedBox(height: 10),
          _colorSwatchRow(e.color, (c) => _mutate(() => e.color = c)),
        ];
      case ElementType.image:
        return [
          ElevatedButton.icon(
            onPressed: () async {
              final picker = ImagePicker();
              final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (xfile == null) return;
              final bytes = await xfile.readAsBytes();
              final ext = xfile.path.split('.').last.toLowerCase();
              _mutate(() {
                e.imageBytes = bytes;
                e.imageExt = ext == 'png' ? 'png' : 'jpg';
              });
            },
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: Text(t(context, 'Fotoğraf Değiştir'), style: const TextStyle(fontFamily: 'monospace')),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentPurple, foregroundColor: Colors.white),
          ),
          const SizedBox(height: 12),
          _labeled('Köşe Yuvarlaklığı', Slider(
            value: e.borderRadius.clamp(0, 60),
            min: 0,
            max: 60,
            activeColor: AppColors.accentCyan,
            onChanged: (v) => _mutate(() => e.borderRadius = v),
          )),
        ];
      case ElementType.shape:
        return [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 150,
                child: _toggleChip(
                  label: t(context, 'Dikdörtgen'),
                  active: e.shapeKind == ShapeKind.rectangle,
                  onTap: () => _mutate(() => e.shapeKind = ShapeKind.rectangle),
                ),
              ),
              SizedBox(
                width: 150,
                child: _toggleChip(
                  label: 'Daire',
                  active: e.shapeKind == ShapeKind.circle,
                  onTap: () => _mutate(() => e.shapeKind = ShapeKind.circle),
                ),
              ),
              SizedBox(
                width: 150,
                child: _toggleChip(
                  label: t(context, 'Üçgen'),
                  active: e.shapeKind == ShapeKind.triangle,
                  onTap: () => _mutate(() => e.shapeKind = ShapeKind.triangle),
                ),
              ),
              SizedBox(
                width: 150,
                child: _toggleChip(
                  label: t(context, 'Yıldız'),
                  active: e.shapeKind == ShapeKind.star,
                  onTap: () => _mutate(() => e.shapeKind = ShapeKind.star),
                ),
              ),
            ],
          ),
          if (e.shapeKind == ShapeKind.rectangle) ...[
            const SizedBox(height: 12),
            _labeled('Köşe Yuvarlaklığı', Slider(
              value: e.borderRadius.clamp(0, 60),
              min: 0,
              max: 60,
              activeColor: AppColors.accentCyan,
              onChanged: (v) => _mutate(() => e.borderRadius = v),
            )),
          ],
          const SizedBox(height: 12),
          // index.html > shape_img: şeklin içine URL/galeri fotoğrafı
          // yerleştirme. Fotoğraf varsa şekil o fotoğrafla doldurulup
          // şeklin siluetine kırpılır; yoksa düz renk dolgu kullanılır.
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (xfile == null) return;
                    final bytes = await xfile.readAsBytes();
                    final ext = xfile.path.split('.').last.toLowerCase();
                    _mutate(() {
                      e.imageBytes = bytes;
                      e.imageExt = ext == 'png' ? 'png' : 'jpg';
                    });
                  },
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: Text(t(context, e.imageBytes == null ? 'Şekle Foto Ekle' : 'Fotoğrafı Değiştir'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPurple, foregroundColor: Colors.white),
                ),
              ),
              if (e.imageBytes != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _mutate(() => e.imageBytes = null),
                  icon: const Icon(Icons.close, color: AppColors.danger, size: 20),
                  tooltip: t(context, 'Fotoğrafı Kaldır'),
                ),
              ],
            ],
          ),
          if (e.imageBytes == null) ...[
            const SizedBox(height: 10),
            Text(t(context, 'Dolgu Rengi'), style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 6),
            _colorSwatchRow(e.fillColor, (c) => _mutate(() => e.fillColor = c)),
          ],
        ];
      case ElementType.social:
        return [
          Row(
            children: [
              SvgPicture.string(
                SocialIcons.forPlatform(e.socialPlatform ?? SocialPlatform.whatsapp),
                width: 28,
                height: 28,
              ),
              const SizedBox(width: 10),
              Text(SocialIcons.labelFor(e.socialPlatform ?? SocialPlatform.whatsapp),
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if ((e.socialPlatform ?? SocialPlatform.whatsapp) == SocialPlatform.whatsapp) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    e.link.isEmpty ? t(context, 'Telefon numarası girilmedi') : e.link,
                    style: const TextStyle(
                        color: Colors.white70, fontFamily: 'monospace', fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final current = e.link.replaceFirst('https://wa.me/', '');
                    final phone = await showWhatsAppPhonePopup(context, initialPhone: current);
                    if (phone != null) {
                      _mutate(() => e.link = 'https://wa.me/$phone');
                    }
                  },
                  icon: const Icon(Icons.edit, size: 16, color: AppColors.accentCyan),
                  label: Text(t(context, 'Düzenle'),
                      style: const TextStyle(color: AppColors.accentCyan, fontFamily: 'monospace')),
                ),
              ],
            ),
          ] else
            TextFormField(
              key: ValueKey('social-link-${e.id}'),
              initialValue: e.link,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: t(context, 'Bağlantı (instagram.com/, tiktok.com/... vb.)'),
                labelStyle: const TextStyle(color: Colors.white54),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
              onChanged: (v) => _mutate(() => e.link = v),
            ),
        ];
      case ElementType.button:
        return [
          TextFormField(
            key: ValueKey('label-${e.id}'),
            initialValue: e.text,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: t(context, 'Buton Yazısı'),
              labelStyle: const TextStyle(color: Colors.white54),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
            onChanged: (v) => _mutate(() => e.text = v),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('link-${e.id}'),
            initialValue: e.link,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: t(context, 'Bağlantı (https:// veya https://wa.me/...)'),
              labelStyle: const TextStyle(color: Colors.white54),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
            onChanged: (v) => _mutate(() => e.link = v),
          ),
          const SizedBox(height: 10),
          Text(t(context, 'Buton Rengi'), style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 12)),
          const SizedBox(height: 6),
          _colorSwatchRow(e.fillColor, (c) => _mutate(() => e.fillColor = c)),
        ];
    }
  }

  Widget _labeled(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, label), style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 12)),
        child,
      ],
    );
  }

  Widget _toggleChip({required String label, required bool active, required VoidCallback onTap}) {
    return Material(
      color: active ? AppColors.accentCyan.withOpacity(0.2) : const Color(0xFF1C232E),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? AppColors.accentCyan : Colors.white24),
          ),
          child: Text(t(context, label),
              style: TextStyle(
                  color: active ? AppColors.accentCyan : Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 11.5)),
        ),
      ),
    );
  }

  Widget _alignBtn(CanvasElement e, TextAlign align, IconData icon) {
    final active = e.textAlign == align;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _mutate(() => e.textAlign = align),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.accentCyan.withOpacity(0.2) : const Color(0xFF1C232E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? AppColors.accentCyan : Colors.white24),
          ),
          child: Icon(icon, size: 16, color: active ? AppColors.accentCyan : Colors.white70),
        ),
      ),
    );
  }

  Widget _colorSwatchRow(Color current, ValueChanged<Color> onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _colorPalette.map((c) {
        final active = c.value == current.value;
        return GestureDetector(
          onTap: () => onPick(c),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: active ? AppColors.accentCyan : Colors.white24, width: active ? 2.4 : 1),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// index.html > #toolbar — Şablonlar / Çizim / Bölümler / Şekiller /
  /// Smart CTA / Yazı / Foto / WA / IG / TT / FB / Arka Plan.
  /// Not: HTML'deki 🔒 premium kilit rozetleri burada YOK.
  Widget _buildBottomToolbar() {
    return Container(
      color: const Color(0xFF141821),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolChip(emoji: '📑', label: t(context, 'Şablonlar'), onTap: _openTemplatesSheet),
            _toolChip(emoji: '✏️', label: t(context, 'Çizim'), onTap: _showDrawingDialog),
            _toolChip(emoji: '🧱', label: t(context, 'Bölümler'), onTap: _showSectionMenu),
            _toolChip(emoji: '📐', label: t(context, 'Şekiller'), onTap: _showShapeMenu),
            _toolChip(
              emoji: '⚡',
              label: t(context, 'Akıllı CTA'),
              onTap: () => _addButtonElement(label: t(context, 'Hemen İncele'), color: AppColors.accentBlue),
            ),
            _toolChip(emoji: '📝', label: t(context, 'Yazı'), onTap: _addTextElement),
            _toolChip(emoji: '🖼️', label: 'Foto', onTap: _addImageElement),
            _toolChip(
              emoji: '💬',
              label: 'WA',
              bg: const Color(0xFF25D366).withOpacity(0.15),
              onTap: () => _addSocialElement(SocialPlatform.whatsapp),
            ),
            _toolChip(
              emoji: '📸',
              label: 'IG',
              bg: const Color(0xFFE1306C).withOpacity(0.15),
              onTap: () => _addSocialElement(SocialPlatform.instagram),
            ),
            _toolChip(
              emoji: '🎵',
              label: 'TT',
              bg: Colors.white10,
              onTap: () => _addSocialElement(SocialPlatform.tiktok),
            ),
            _toolChip(
              emoji: '📘',
              label: 'FB',
              bg: const Color(0xFF1877F2).withOpacity(0.15),
              onTap: () => _addSocialElement(SocialPlatform.facebook),
            ),
            _toolChip(emoji: '🎨', label: 'Arka Plan', onTap: _openBackgroundPicker),
          ],
        ),
      ),
    );
  }

  Widget _toolChip({
    required String emoji,
    required String label,
    required VoidCallback onTap,
    Color? bg,
    Color? fg,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: bg ?? const Color(0xFF1C232E),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  t(context, label),
                  style: TextStyle(
                    color: fg ?? Colors.white70,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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

/// index.html > canvas.grid — basit ızgara görselleştirmesi.
class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GridPainter(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  static const double step = 20;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Üçgen şekil kırpıcı — HTML export'taki
/// `clip-path: polygon(50% 0%, 0% 100%, 100% 100%)` ile birebir aynı silüet.
class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Yıldız şekil kırpıcı — HTML export'taki 5 köşeli yıldız
/// `clip-path: polygon(...)` noktalarıyla birebir aynı silüet.
class _StarClipper extends CustomClipper<Path> {
  static const List<List<double>> _points = [
    [0.50, 0.00],
    [0.61, 0.35],
    [0.98, 0.35],
    [0.68, 0.57],
    [0.79, 0.91],
    [0.50, 0.70],
    [0.21, 0.91],
    [0.32, 0.57],
    [0.02, 0.35],
    [0.39, 0.35],
  ];

  @override
  Path getClip(Size size) {
    final path = Path();
    for (var i = 0; i < _points.length; i++) {
      final dx = _points[i][0] * size.width;
      final dy = _points[i][1] * size.height;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
