import 'dart:convert';

import '../config/app_config.dart';

class WatermarkService {
  WatermarkService._();

  static const String _marker = '<!--k9x2-4qz7-vt31-->';

  static const String _badgeTextTr = 'MySitora ile üretildi — kullanıcı ürünüdür';
  static const String _badgeTextEn = 'Made with MySitora — user-generated content';

  static String _badgeScript(bool isEnglish) {
    final text = isEnglish ? _badgeTextEn : _badgeTextTr;
    final encoded = base64Encode(utf8.encode(text));
    final encodedUrl = base64Encode(utf8.encode(AppConfig.badgePlayStoreUrl));
    return '''
$_marker
<script>(function(){try{var bin=atob("$encoded");var bytes=new Uint8Array(bin.length);for(var i=0;i<bin.length;i++){bytes[i]=bin.charCodeAt(i);}var t=new TextDecoder("utf-8").decode(bytes);var url=atob("$encodedUrl");var a=document.createElement("a");a.href=url;a.target="_blank";a.rel="noopener noreferrer";a.textContent=t;a.className="k9zbadge";a.style.cssText="position:fixed;bottom:10px;right:10px;z-index:999999;font-family:Arial,Helvetica,sans-serif;font-size:11px;line-height:1;background:rgba(17,17,17,.72);color:#fff;padding:6px 12px;border-radius:999px;text-decoration:none;cursor:pointer;user-select:none;box-shadow:0 2px 6px rgba(0,0,0,.25)";if(!document.getElementById("k9zbadge-style")){var st=document.createElement("style");st.id="k9zbadge-style";st.textContent="@media(max-width:600px){.k9zbadge{font-size:13px !important;padding:9px 16px !important;bottom:14px !important;right:14px !important;box-shadow:0 3px 8px rgba(0,0,0,.3) !important}}";(document.head||document.documentElement).appendChild(st);}(document.body||document.documentElement).appendChild(a);}catch(e){}})();</script>''';
  }

  static String apply(String html, {bool isEnglish = false}) {
    if (html.trim().isEmpty) return html;
    if (html.contains(_marker)) return html;

    final badge = _badgeScript(isEnglish);
    final bodyCloseIndex = _lastIndexOfIgnoreCase(html, '</body>');
    if (bodyCloseIndex != -1) {
      return html.substring(0, bodyCloseIndex) +
          badge +
          '\n' +
          html.substring(bodyCloseIndex);
    }
    return '$html\n$badge';
  }

  static Map<String, String> applyToFiles(Map<String, String> files, {bool isEnglish = false}) {
    return files.map((name, content) {
      if (name.toLowerCase().endsWith('.html')) {
        return MapEntry(name, apply(content, isEnglish: isEnglish));
      }
      return MapEntry(name, content);
    });
  }

  static int _lastIndexOfIgnoreCase(String source, String target) {
    final lower = source.toLowerCase();
    return lower.lastIndexOf(target.toLowerCase());
  }

  static String strip(String html) {
    if (!html.contains(_marker)) return html;
    final markerIndex = html.indexOf(_marker);
    final closeScriptIndex = html.indexOf('</script>', markerIndex);
    if (closeScriptIndex == -1) return html;
    final blockEnd = closeScriptIndex + '</script>'.length;
    final trailingNewline =
        html.startsWith('\n', blockEnd) ? blockEnd + 1 : blockEnd;
    return html.substring(0, markerIndex) + html.substring(trailingNewline);
  }

  static Map<String, String> stripFromFiles(Map<String, String> files) {
    return files.map((name, content) {
      if (name.toLowerCase().endsWith('.html')) {
        return MapEntry(name, strip(content));
      }
      return MapEntry(name, content);
    });
  }
}
