import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Builder Pro canvas motorunun temel veri modeli.
///
/// Konum/boyut değerleri (x, y, width, height) canvas'a göre 0..1 arası
/// ORAN olarak tutulur (piksel değil). Böylece:
/// - Farklı ekran boyutlarında canvas widget'ı yeniden boyutlandığında
///   elemanlar orantılı kalır.
/// - HTML'e export ederken doğrudan % tabanlı `left/top/width/height`
///   olarak yazılabilir; responsive bir sonuç üretir.
enum ElementType { text, image, shape, button, social }

enum ShapeKind { rectangle, circle, triangle, star }

enum SocialPlatform { whatsapp, instagram, tiktok, facebook }

class CanvasElement {
  final String id;
  ElementType type;

  double x;
  double y;
  double width;
  double height;
  int zIndex;

  /// 360° döndürme açısı (derece, 0-360). HTML index.html'deki referans
  /// implementasyonla birebir aynı mantık: eleman merkezine göre saat
  /// yönünde açı.
  double rotation;

  // --- metin ---
  String text;
  double fontSize;
  Color color;
  FontWeight fontWeight;
  TextAlign textAlign;

  // --- şekil / buton dolgusu ---
  Color fillColor;
  double borderRadius;
  ShapeKind shapeKind;

  // --- görsel (image tipi VEYA şeklin içine yerleştirilen foto) ---
  Uint8List? imageBytes;
  String imageExt;

  // --- buton / link ---
  String link;

  // --- sosyal medya ikonu ---
  SocialPlatform? socialPlatform;

  CanvasElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.zIndex = 0,
    this.rotation = 0,
    this.text = '',
    this.fontSize = 16,
    this.color = Colors.black87,
    this.fontWeight = FontWeight.normal,
    this.textAlign = TextAlign.center,
    this.fillColor = const Color(0xFF26C6DA),
    this.borderRadius = 8,
    this.shapeKind = ShapeKind.rectangle,
    this.imageBytes,
    this.imageExt = 'jpg',
    this.link = '',
    this.socialPlatform,
  });

  /// Undo/redo geçmişi için bağımsız bir kopya üretir (referans paylaşımı
  /// olursa geçmiş anlık görüntüleri de canlı elemanla birlikte değişir,
  /// bu yüzden her mutasyondan önce derin kopya alınır).
  CanvasElement clone() => CanvasElement(
        id: id,
        type: type,
        x: x,
        y: y,
        width: width,
        height: height,
        zIndex: zIndex,
        rotation: rotation,
        text: text,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        textAlign: textAlign,
        fillColor: fillColor,
        borderRadius: borderRadius,
        shapeKind: shapeKind,
        imageBytes: imageBytes,
        imageExt: imageExt,
        link: link,
        socialPlatform: socialPlatform,
      );

  /// Uygulama kapatılıp açıldığında canvas içeriğinin kaybolmaması için
  /// bu elemanı JSON'a (SharedPreferences'ta saklanabilir bir Map'e) çevirir.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'zIndex': zIndex,
        'rotation': rotation,
        'text': text,
        'fontSize': fontSize,
        'color': color.value,
        'fontWeight': fontWeight.index,
        'textAlign': textAlign.name,
        'fillColor': fillColor.value,
        'borderRadius': borderRadius,
        'shapeKind': shapeKind.name,
        'imageBytes': imageBytes == null ? null : base64Encode(imageBytes!),
        'imageExt': imageExt,
        'link': link,
        'socialPlatform': socialPlatform?.name,
      };

  /// [toJson] ile üretilen Map'ten geri kurulum yapar. Bilinmeyen/eksik
  /// alanlar için makul varsayılanlara düşer, böylece eski/az farklı bir
  /// kayıt formatı bile kurtarma sırasında uygulamayı çökertmez.
  factory CanvasElement.fromJson(Map<String, dynamic> json) {
    ElementType parseType(String? v) => ElementType.values.firstWhere(
          (e) => e.name == v,
          orElse: () => ElementType.text,
        );
    TextAlign parseAlign(String? v) => TextAlign.values.firstWhere(
          (e) => e.name == v,
          orElse: () => TextAlign.center,
        );
    ShapeKind parseShape(String? v) => ShapeKind.values.firstWhere(
          (e) => e.name == v,
          orElse: () => ShapeKind.rectangle,
        );
    SocialPlatform? parseSocial(String? v) {
      if (v == null) return null;
      for (final p in SocialPlatform.values) {
        if (p.name == v) return p;
      }
      return null;
    }

    final imgB64 = json['imageBytes'] as String?;
    return CanvasElement(
      id: json['id'] as String,
      type: parseType(json['type'] as String?),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      text: json['text'] as String? ?? '',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
      color: json['color'] != null ? Color(json['color'] as int) : Colors.black87,
      fontWeight: FontWeight.values[(json['fontWeight'] as num?)?.toInt() ?? 3],
      textAlign: parseAlign(json['textAlign'] as String?),
      fillColor: json['fillColor'] != null
          ? Color(json['fillColor'] as int)
          : const Color(0xFF26C6DA),
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 8,
      shapeKind: parseShape(json['shapeKind'] as String?),
      imageBytes: imgB64 == null ? null : base64Decode(imgB64),
      imageExt: json['imageExt'] as String? ?? 'jpg',
      link: json['link'] as String? ?? '',
      socialPlatform: parseSocial(json['socialPlatform'] as String?),
    );
  }
}
