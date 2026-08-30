import '../models/canvas_element.dart';

/// index.html > addSocial() içindeki `svgs` sözlüğünden birebir taşınan
/// marka SVG'leri. Builder Pro'da WA/IG/TT/FB elemanları artık renkli
/// metin rozetleri değil, HTML referansındaki gerçek logo vektörleridir.
class SocialIcons {
  static const String whatsapp = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512" fill="#25D366"><path d="M380.9 97.1C339 55.1 283.2 32 223.9 32c-122.4 0-222 99.6-222 222 0 39.1 10.2 77.3 29.6 111L0 480l117.7-30.9c32.4 17.7 68.9 27 106.1 27h.1c122.3 0 224.1-99.6 224.1-222 0-59.3-25.2-115-67.1-157.1zm-157 341.6c-33.2 0-65.7-8.9-94-25.7l-6.7-4-69.8 18.3L72 359.2l-4.4-7c-18.5-29.4-28.2-63.3-28.2-98.2 0-101.7 82.8-184.5 184.6-184.5 49.3 0 95.6 19.2 130.4 54.1 34.8 34.9 56.2 81.2 56.1 130.5 0 101.8-84.9 184.6-186.6 184.6zm101.2-138.2c-5.5-2.8-32.8-16.2-37.9-18-5.1-1.9-8.8-2.8-12.5 2.8-3.7 5.6-14.3 18-17.6 21.8-3.2 3.7-6.5 4.2-12 1.4-32.6-16.3-54-29.1-75.5-66-5.7-9.8 5.7-9.1 16.3-30.3 1.8-3.7.9-6.9-.5-9.7-1.4-2.8-12.5-30.1-17.1-41.2-4.5-10.8-9.1-9.3-12.5-9.5-3.2-.2-6.9-.2-10.6-.2-3.7 0-9.7 1.4-14.8 6.9-5.1 5.6-19.4 19-19.4 46.3 0 27.3 19.9 53.7 22.6 57.4 2.8 3.7 39.1 59.7 94.8 83.8 35.2 15.2 49 16.5 66.6 13.9 10.7-1.6 32.8-13.4 37.4-26.4 4.6-13 4.6-24.1 3.2-26.4-1.3-2.5-5-3.9-10.5-6.6z"/></svg>
''';

  static const String instagram = '''
<svg xmlns="http://www.w3.org/2000/svg" fill="#E1306C" viewBox="0 0 24 24"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644-.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z"/></svg>
''';

  static const String facebook = '''
<svg xmlns="http://www.w3.org/2000/svg" fill="#1877F2" viewBox="0 0 24 24"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.469h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.469h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/></svg>
''';

  static const String tiktok = '''
<svg xmlns="http://www.w3.org/2000/svg" fill="#000000" viewBox="0 0 24 24"><path d="M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.02 1.59 4.23.95.83 2.15 1.34 3.4 1.48v3.91c-1.3-.08-2.58-.51-3.67-1.25-.33-.24-.63-.51-.9-.81-.04 2.11-.02 4.22-.03 6.33-.04 1.25-.36 2.5-.96 3.61-.83 1.37-2.22 2.37-3.8 2.72-1.42.34-2.95.14-4.25-.56-1.63-.88-2.73-2.61-2.88-4.47-.19-1.92.64-3.85 2.15-5.04 1.21-.97 2.76-1.42 4.31-1.26.01 1.37.01 2.74.01 4.11-1.04-.3-2.18-.08-3.03.58-.7.54-1.08 1.41-1.01 2.3.06.94.62 1.79 1.45 2.22.84.44 1.86.39 2.65-.12.69-.47 1.09-1.26 1.09-2.09V.02z"/></svg>
''';

  static String forPlatform(SocialPlatform p) {
    switch (p) {
      case SocialPlatform.whatsapp:
        return whatsapp;
      case SocialPlatform.instagram:
        return instagram;
      case SocialPlatform.facebook:
        return facebook;
      case SocialPlatform.tiktok:
        return tiktok;
    }
  }

  static String labelFor(SocialPlatform p) {
    switch (p) {
      case SocialPlatform.whatsapp:
        return 'WhatsApp';
      case SocialPlatform.instagram:
        return 'Instagram';
      case SocialPlatform.facebook:
        return 'Facebook';
      case SocialPlatform.tiktok:
        return 'TikTok';
    }
  }

  static String defaultLinkFor(SocialPlatform p) {
    switch (p) {
      case SocialPlatform.whatsapp:
        return 'https://wa.me/90';
      case SocialPlatform.instagram:
        return 'https://instagram.com/';
      case SocialPlatform.facebook:
        return 'https://facebook.com/';
      case SocialPlatform.tiktok:
        return 'https://tiktok.com/';
    }
  }
}
