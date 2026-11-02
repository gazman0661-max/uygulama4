import 'dart:math' as math;

/// Sıralamadaki bir botun görünen kimliği (isim, avatar, seviye) ve oynama kişiliği.
/// Hepsi tohumdan ÜRETİLİR (saklanmaz): aynı koşu = aynı bot, ama her koşuda farklı kişiler.
class BotProfile {
  final String name;
  final int avatarColor; // ARGB
  final String avatarIcon; // boşsa avatarda isim baş harfi çizilir
  final int level;
  final double awakeAdj; // bu botun "uyanık olma" olasılığına eklenen fark (kişilik: -0.15 .. +0.15)
  const BotProfile({
    required this.name,
    required this.avatarColor,
    required this.avatarIcon,
    required this.level,
    required this.awakeAdj,
  });
}

/// İnandırıcı bot kimliği üretici. Tek tip "Elif, Mert, Zeynep..." listesi hemen belli oluyordu;
/// burada karışık dil + karışık yazım stilleri (düz isim, rakamlı, nokta/altçizgili, takma ad,
/// oyuncu/gamer kalıpları, klavye gelişigüzelliği...) kullanılır.
class BotIdentity {
  BotIdentity._();

  static const List<String> trNames = [
    'Elif', 'Mert', 'Zeynep', 'Burak', 'Selin', 'Can', 'Deniz', 'Aylin', 'Emre', 'Ece',
    'Kaan', 'Defne', 'Arda', 'Yaren', 'Onur', 'Ada', 'Cem', 'Ayşe', 'Fatma', 'Ahmet',
    'Mehmet', 'Gizem', 'Hakan', 'Merve', 'Berk', 'Esra', 'Tuna', 'Buse', 'Eren', 'İrem',
    'Oğuz', 'Sinem', 'Yiğit', 'Pınar', 'Barış', 'Damla', 'Umut', 'Nehir', 'Tolga', 'Duygu',
    'Kerem', 'Melis', 'Ozan', 'Seda', 'Furkan', 'Beyza', 'Efe', 'Ceren', 'Mina', 'Doruk',
    'Berkay', 'Gökhan', 'Tuğçe', 'Selçuk', 'Volkan', 'Büşra', 'Cansu', 'Ebru', 'Serkan', 'Özge',
    'Yasin', 'Hande', 'Murat', 'Derya', 'Kübra', 'Serhat', 'Rabia', 'Emirhan', 'Bengisu', 'Alperen',
    'Nisa', 'Talha', 'Zehra', 'Metin', 'Sevgi', 'Koray', 'Aslı', 'Batuhan', 'İpek', 'Taner',
    'Pelin', 'Mustafa', 'Hüseyin', 'Ali', 'Osman', 'Hasan', 'Leyla', 'Gül', 'Nur', 'Kadir',
    'Yusuf', 'İbrahim', 'Salih', 'Hilal', 'Rümeysa', 'Semih', 'Anıl', 'Caner', 'Çağla', 'Cihan',
    'Gamze', 'Tuğba', 'Ufuk', 'Ulaş', 'Vedat', 'Yunus', 'Zafer', 'Bora', 'Atakan', 'Egemen',
    'Lale', 'Sibel', 'Naz', 'Sude', 'Ecrin', 'Asya', 'Elvan', 'Mavi', 'Kağan', 'Alp',
    'Tarık', 'Cüneyt', 'Hatice', 'Sevda', 'Nazlı', 'Dilara', 'Gökçe', 'Orhan', 'Fırat', 'Rüzgar',
  ];

  static const List<String> intlNames = [
    'Alex', 'Mia', 'Liam', 'Sofia', 'Noah', 'Emma', 'Lucas', 'Anna', 'Leo', 'Nina',
    'Max', 'Julia', 'Ivan', 'Olga', 'Marco', 'Laura', 'Diego', 'Lena', 'Hugo', 'Chloe',
    'Ahmed', 'Layla', 'Omar', 'Sara', 'Jonas', 'Eva', 'Pablo', 'Ana', 'Luca', 'Maria',
    'Dmitri', 'Katya', 'Tom', 'Zoe', 'Yuki', 'Hana', 'Ravi', 'Maya', 'Felix', 'Lara',
    'Ben', 'Sam', 'Kate', 'Jack', 'Emily', 'Daniel', 'Ella', 'Oscar', 'Ruby', 'Adam',
    'Nick', 'Sophie', 'Pedro', 'Carlos', 'Lucia', 'Elena', 'Pavel', 'Sasha', 'Anton', 'Irina',
    'Mohamed', 'Fatima', 'Yusuf', 'Aisha', 'Wei', 'Kenji', 'Sakura', 'Arjun', 'Priya', 'Sven',
    'Ingrid', 'Lukas', 'Emil', 'Mateo', 'Valentina', 'Giulia', 'Andre', 'Bruno', 'Camila', 'Thiago',
  ];

  static const List<String> nickWords = [
    'Pixel', 'Nova', 'Maple', 'Turbo', 'Blaze', 'Lucky', 'Cosmo', 'Panda', 'Ninja', 'Rocket',
    'Mango', 'Storm', 'Shadow', 'Tiger', 'Comet', 'Berry', 'Pepper', 'Ziggy', 'Orbit', 'Echo',
    'Frost', 'Sunny', 'Bolt', 'Cookie', 'Gizmo', 'Wolf', 'Jelly', 'Cloud', 'Ember', 'Zen',
    'Dragon', 'Phoenix', 'Viper', 'Falcon', 'Hunter', 'King', 'Queen', 'Magic', 'Candy', 'Sugar',
    'Galaxy', 'Star', 'Moon', 'Lion', 'Bear', 'Owl', 'Hawk', 'Raven', 'Cyber', 'Alpha',
    'Mystic', 'Rebel', 'Joker', 'Sniper', 'Ghost', 'Spark', 'Thunder', 'Kara', 'Yildiz', 'Aslan',
    'Kurt', 'Bulut', 'Kedi', 'Gece', 'Deli', 'Tatli', 'Mavi', 'Sevimli', 'Bay', 'Dost',
  ];

  /// Soyadı (yalnızca "Mert Y." / "mert_yilmaz" kalıpları için).
  static const List<String> surnames = [
    'Yılmaz', 'Kaya', 'Demir', 'Çelik', 'Şahin', 'Yıldız', 'Öztürk', 'Aydın', 'Arslan', 'Doğan',
    'Kılıç', 'Çetin', 'Koç', 'Özkan', 'Polat', 'Erdem', 'Güneş', 'Acar',
  ];

  /// İki parçalı Türkçe adlar ("ElifNur", "AhmetCan").
  static const List<String> trCompound = [
    'ElifNur', 'AhmetCan', 'MehmetAli', 'ZeynepSu', 'AliCan', 'EceNur', 'BerkCan', 'NurSena',
    'AyşeNur', 'MuhammedAli', 'EmirCan', 'IrmakSu', 'YağmurSu', 'AsyaNur', 'KaanCan', 'Meryem',
  ];

  static const List<String> _plates = ['06', '34', '35', '16', '07', '61', '42', '01', '27', '33', '41', '55'];
  static const List<String> _clubNums = ['1905', '1907', '1903', '1967', '1923', '1453'];

  static const List<String> icons = ['🐱', '🐶', '🦊', '🐼', '🐸', '🦁', '🐯', '🐵', '🐧', '🦄', '🌟', '🔥', '🍀', '🎮', '🚀', '🌈'];

  static const List<int> colors = [
    0xFF5C6BC0, 0xFF26A69A, 0xFFEF5350, 0xFFFFA726, 0xFF8D6E63,
    0xFFAB47BC, 0xFF42A5F5, 0xFF66BB6A, 0xFFEC407A, 0xFF78909C,
  ];

  /// Türkçe harfleri ASCII'ye çevirir (takma ad / kullanıcı adı stilleri için).
  static String ascii(String s) {
    const from = 'çÇğĞıİöÖşŞüÜ';
    const to = 'cCgGiIoOsSuU';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  /// Rakam eki: rastgele 2 hane, il plakası, doğum yılı (2 hane) ya da 3 hane karışık.
  static String _digits(math.Random r) {
    final roll = r.nextDouble();
    if (roll < 0.40) return (1 + r.nextInt(99)).toString().padLeft(2, '0');
    if (roll < 0.58) return _plates[r.nextInt(_plates.length)];
    if (roll < 0.80) return ((r.nextBool() ? 85 : 0) + r.nextInt(r.nextBool() ? 15 : 10)).toString().padLeft(2, '0');
    return (100 + r.nextInt(900)).toString();
  }

  static String _baseName(math.Random r) {
    final roll = r.nextDouble();
    if (roll < 0.06) return trCompound[r.nextInt(trCompound.length)];
    return roll < 0.62 ? trNames[r.nextInt(trNames.length)] : intlNames[r.nextInt(intlNames.length)];
  }

  /// Klavyeye gelişigüzel basılmış gibi kısa kullanıcı adı ("kjhs23", "zxmbr").
  static String _mash(math.Random r) {
    const l = 'abcdefghijklmnoprstuvyz';
    final n = 3 + r.nextInt(4);
    final b = StringBuffer();
    for (var i = 0; i < n; i++) {
      b.write(l[r.nextInt(l.length)]);
    }
    if (r.nextBool()) b.write(r.nextInt(100));
    return b.toString();
  }

  static String _name(math.Random r) {
    final roll = r.nextDouble();
    if (roll < 0.15) return _baseName(r); // Elif
    if (roll < 0.29) return '${ascii(_baseName(r)).toLowerCase()}${_digits(r)}'; // emre34
    if (roll < 0.37) return ascii(_baseName(r)).toLowerCase(); // berk (rakamsuz, küçük harf)
    if (roll < 0.46) {
      final sep = r.nextBool() ? '_' : '.';
      final letter = String.fromCharCode(0x41 + r.nextInt(26));
      final n = ascii(_baseName(r));
      return sep == '_' ? '${n}_$letter' : '${n.toLowerCase()}.${letter.toLowerCase()}'; // Mert_B / zeynep.k
    }
    if (roll < 0.58) {
      final a = nickWords[r.nextInt(nickWords.length)];
      if (r.nextBool()) return '$a${_digits(r)}'; // Nova99
      var b = nickWords[r.nextInt(nickWords.length)];
      if (b == a) b = 'Fox';
      return '$a$b'; // PixelWolf
    }
    if (roll < 0.65) return '${ascii(_baseName(r)).toLowerCase()}_${1988 + r.nextInt(18)}'; // kaan_1998
    if (roll < 0.70) return '${_baseName(r)}${_digits(r)}'; // Elif07
    if (roll < 0.76) {
      // oyuncu / gamer kalıpları
      final nick = nickWords[r.nextInt(nickWords.length)];
      final base = ascii(_baseName(r)).toLowerCase();
      switch (r.nextInt(5)) {
        case 0:
          return 'xX${nick}Xx';
        case 1:
          return 'its_$base';
        case 2:
          return 'Mr$nick';
        case 3:
          return '${base}official';
        default:
          return 'The$nick';
      }
    }
    if (roll < 0.82) {
      final sur = surnames[r.nextInt(surnames.length)];
      if (r.nextBool()) return '${_baseName(r)} ${sur[0]}.'; // Mert Y.
      return '${ascii(_baseName(r)).toLowerCase()}_${ascii(sur).toLowerCase()}'; // mert_yilmaz
    }
    if (roll < 0.87) return '${ascii(_baseName(r)).toLowerCase()}${_clubNums[r.nextInt(_clubNums.length)]}'; // emre1905
    if (roll < 0.92) {
      switch (r.nextInt(4)) {
        case 0:
          return 'oyuncu${1 + r.nextInt(99999)}';
        case 1:
          return 'user${10000 + r.nextInt(89999)}';
        case 2:
          return 'player_${100 + r.nextInt(9899)}';
        default:
          return 'misafir${1 + r.nextInt(9999)}';
      }
    }
    if (roll < 0.96) return _mash(r); // kjhs23
    return _baseName(r); // son pay: düz isim
  }

  /// Tek bot kimliği üretir. [used] aynı sıralamada tekrarı önler (küçük/büyük harf farkı sayılmaz).
  ///
  /// [fast01]: botun hız sırası 0 (en yavaş) .. 1 (en hızlı). Verilirse SEVİYE hıza bağlanır
  /// (en hızlı botlar yüksek seviyeli olur, 1. sıradaki bot Lv.9 çıkmaz). Verilmezse (< 0) eski,
  /// hızdan bağımsız dağılım kullanılır.
  static BotProfile make(math.Random r, Set<String> used, {int minLevel = 7, double fast01 = -1}) {
    var name = _name(r);
    for (var i = 0; i < 20 && used.contains(name.toLowerCase()); i++) {
      name = _name(r);
    }
    while (used.contains(name.toLowerCase())) {
      name = '$name${r.nextInt(10)}';
    }
    used.add(name.toLowerCase());
    final color = colors[r.nextInt(colors.length)];
    final icon = r.nextDouble() < 0.55 ? icons[r.nextInt(icons.length)] : '';
    // Seviye (7 .. ~52). Oyuncunun seviyesine BAĞLI DEĞİL (koşu içinde değişmesin).
    final lv = r.nextDouble();
    final int level;
    if (fast01 < 0) {
      level = minLevel + (math.pow(lv, 1.6) * 45).floor();
    } else {
      final x = 0.7 * fast01.clamp(0.0, 1.0) + 0.3 * lv;
      level = minLevel + (math.pow(x, 1.5) * 45).floor();
    }
    final adj = (r.nextDouble() - 0.5) * 0.30;
    return BotProfile(name: name, avatarColor: color, avatarIcon: icon, level: level, awakeAdj: adj);
  }
}
