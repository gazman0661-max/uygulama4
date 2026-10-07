import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';

/// Ekran görüntülerindeki oval, renkli çerçeveli butonlar
/// (Kılavuz, Puan Ver, ÖN İZLEME, DÜZENLE, İNDİR vb.) için ortak widget.
///
/// Boyu her zaman [height] ile sabittir ve etiket [FittedBox] ile
/// otomatik küçültülür; böylece hem cihazın sistem yazı tipi boyutundan
/// hem de ekran genişliğinden etkilenmeden tüm butonlar aynı, stabil
/// yükseklikte kalır ve hiçbir zaman taşmaz.
class PillButton extends StatelessWidget {
  final String label;
  final String? emoji;
  final Color borderColor;
  final Color textColor;
  final VoidCallback? onTap;
  final bool filled;
  final Color? fillColor;
  final EdgeInsetsGeometry padding;
  final double height;
  final double fontSize;

  const PillButton({
    super.key,
    required this.label,
    this.emoji,
    required this.borderColor,
    required this.textColor,
    this.onTap,
    this.filled = false,
    this.fillColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    this.height = 40,
    this.fontSize = 12.5,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? (fillColor ?? borderColor) : Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          height: height,
          padding: padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    t(context, label),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: filled ? Colors.white : textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize,
                      fontFamily: 'monospace',
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
}

/// Sağ üst köşedeki TR/EN dil değiştirme butonu. Tek dokunuşla aktif dili
/// diğerine çevirir (uygulama genelinde tüm ekranlar anında güncellenir).
class LanguageToggleButton extends StatelessWidget {
  final Color background;
  final bool isDark;
  final double size;

  const LanguageToggleButton({
    super.key,
    required this.background,
    required this.isDark,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>();
    final label = locale.isEnglish ? 'EN' : 'TR';
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => locale.toggleLanguage(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yuvarlak ikon butonları (tema, ayarlar, çöp) için ortak widget.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color iconColor;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double size;
  final double iconSize;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.background,
    required this.iconColor,
    this.onTap,
    this.borderColor,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: CircleBorder(
        side: borderColor != null
            ? BorderSide(color: borderColor!, width: 1.4)
            : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all((size - iconSize) / 2),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}
