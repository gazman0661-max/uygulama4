import 'merge_board.dart';

/// MOD 2 HIKAYESI: "Kayip Tarif Defteri".
/// Saf mantik (UI yok): hangi sahne sirada, hangisi gorulmus sayilir.
/// Sahne metinleri Ingilizce kalip (AppStrings.lt anahtari). TR cevirisi:
/// lib/localization/story_strings.dart (kStoryTr). Diger diller simdilik Ingilizce.
/// Gorulen sahneler GameProgress.tutSeen('story_<id>') ile kaydedilir (bulutta birlesir).

enum StoryMood { normal, happy, shock, sad, think }

enum StoryKind { arrive, clue, finale }

class StoryLine {
  /// Konusan kisi (Ingilizce ad = ceviri anahtari).
  final String who;

  /// Misafir karakterin emojisi. Bos = konusan Sef.
  final String emoji;
  final StoryMood mood;
  final String text;
  const StoryLine(this.who, this.emoji, this.mood, this.text);

  bool get isChef => emoji.isEmpty;
}

class StoryScene {
  final String id;
  final StoryKind kind;

  /// Dunya indeksi (0..5). Finalde 5.
  final int world;
  final List<StoryLine> lines;
  const StoryScene(this.id, this.kind, this.world, this.lines);

  String get seenKey => 'story_$id';
}

const String _chef = 'Chef Mino';
const String _master = 'Master Caramel';

/// Sirali sahne listesi. Sira = oynanis sirasi.
const List<StoryScene> kStoryScenes = [
  // ── Dunya 1: Fast Food ──
  StoryScene('w0_a', StoryKind.arrive, 0, [
    StoryLine(_chef, '', StoryMood.shock, 'The storm wrecked my shop... and Master Caramel\'s Recipe Book is gone!'),
    StoryLine(_chef, '', StoryMood.sad, 'Its 6 pages flew off to 6 different worlds.'),
    StoryLine(_chef, '', StoryMood.happy, 'No panic! Orders pay coins, coins rebuild the town. Let\'s cook!'),
    StoryLine('Pickles', '🥒', StoryMood.normal, 'Burger orders first, mysteries later, Chef!'),
  ]),
  StoryScene('w0_b', StoryKind.clue, 0, [
    StoryLine('Pickles', '🥒', StoryMood.happy, 'Chef! Behind the last pickle jar... a page!'),
    StoryLine(_chef, '', StoryMood.think, 'It says: "Start with a pinch of coffee." That is Master\'s handwriting!'),
    StoryLine(_chef, '', StoryMood.happy, 'Next stop: the Cafe world!'),
  ]),
  // ── Dunya 2: Kafe ──
  StoryScene('w1_a', StoryKind.arrive, 1, [
    StoryLine('Madame Foam', '☕', StoryMood.happy, 'Welcome, darling! Our espresso machine is stuck on "dramatic".'),
    StoryLine(_chef, '', StoryMood.normal, 'Have you seen an old recipe page?'),
    StoryLine('Madame Foam', '☕', StoryMood.think, 'A page? A regular used to read one and mumble "too much sugar".'),
  ]),
  StoryScene('w1_b', StoryKind.clue, 1, [
    StoryLine('Madame Foam', '☕', StoryMood.happy, 'Found it! It was holding up the wobbly table.'),
    StoryLine(_chef, '', StoryMood.think, 'Page 2: "Magic is just cooking with extra sparkle."'),
    StoryLine(_chef, '', StoryMood.shock, 'Master Caramel was into magic?!'),
  ]),
  // ── Dunya 3: Buyu ──
  StoryScene('w2_a', StoryKind.arrive, 2, [
    StoryLine('Wizard Mira', '🧙', StoryMood.happy, 'Greetings, Chef! Careful, the soup here talks back.'),
    StoryLine(_chef, '', StoryMood.shock, 'The soup TALKS?!'),
    StoryLine('Wizard Mira', '🧙', StoryMood.normal, 'Only when it is too salty. About your page: ask the cauldron.'),
  ]),
  StoryScene('w2_b', StoryKind.clue, 2, [
    StoryLine('Wizard Mira', '🧙', StoryMood.happy, 'The cauldron coughed it up! Page 3!'),
    StoryLine(_chef, '', StoryMood.think, '"The sea hides the sweetest ingredient." Pirates, here we come!'),
  ]),
  // ── Dunya 4: Korsan ──
  StoryScene('w3_a', StoryKind.arrive, 3, [
    StoryLine('Captain Crumb', '🏴‍☠️', StoryMood.happy, 'Ahoy! Best crew in the seven seas, and none of us can cook!'),
    StoryLine(_chef, '', StoryMood.happy, 'Then you came to the right chef.'),
    StoryLine('Captain Crumb', '🏴‍☠️', StoryMood.think, 'A page washed ashore. We buried it. Forgot where. Feed us and we dig!'),
  ]),
  StoryScene('w3_b', StoryKind.clue, 3, [
    StoryLine('Captain Crumb', '🏴‍☠️', StoryMood.happy, 'X marks the spot, right under the soup pot! Page 4!'),
    StoryLine(_chef, '', StoryMood.think, '"Chill your heart, not your food." Off to the frozen lands!'),
  ]),
  // ── Dunya 5: Buz ──
  StoryScene('w4_a', StoryKind.arrive, 4, [
    StoryLine('Yeti Frosty', '🧊', StoryMood.sad, 'Brrr... everything I cook turns into ice cream. Even the soup.'),
    StoryLine(_chef, '', StoryMood.happy, 'Honestly? Sounds amazing.'),
    StoryLine('Yeti Frosty', '🧊', StoryMood.happy, 'Hehe. A page is frozen in the giant ice block. Good orders will melt it!'),
  ]),
  StoryScene('w4_b', StoryKind.clue, 4, [
    StoryLine('Yeti Frosty', '🧊', StoryMood.happy, 'It melted! Page 5, still a little cold.'),
    StoryLine(_chef, '', StoryMood.shock, 'It ends with: "The last page is where I wait." WHERE HE WAITS?'),
    StoryLine(_chef, '', StoryMood.happy, 'Master Caramel is alive! Space, here we come!'),
  ]),
  // ── Dunya 6: Uzay ──
  StoryScene('w5_a', StoryKind.arrive, 5, [
    StoryLine('Commander Zorp', '👽', StoryMood.normal, 'Greetings, Earth chef. Your Master has lived on our moon for months.'),
    StoryLine(_chef, '', StoryMood.shock, 'WHAT?! Is he okay?'),
    StoryLine('Commander Zorp', '👽', StoryMood.happy, 'He taught us pancakes. Now we worship breakfast. Finish the orders and we fly you in.'),
  ]),
  StoryScene('w5_b', StoryKind.clue, 5, [
    StoryLine('Commander Zorp', '👽', StoryMood.happy, 'Last page secured. Engines hot!'),
    StoryLine(_chef, '', StoryMood.happy, 'Six pages... all together at last!'),
  ]),
  // ── Final ──
  StoryScene('fin', StoryKind.finale, 5, [
    StoryLine(_master, '👨‍🍳', StoryMood.happy, 'Mino! My boy! You found all six pages!'),
    StoryLine(_chef, '', StoryMood.happy, 'Master! You were teaching pancakes to aliens this whole time?!'),
    StoryLine(_master, '👨‍🍳', StoryMood.normal, 'The storm was my portal soup boiling over. Oops.'),
    StoryLine(_chef, '', StoryMood.shock, 'OOPS?! You wrecked the whole town!'),
    StoryLine(_master, '👨‍🍳', StoryMood.happy, 'Then let us rebuild it bigger. Together, across all six worlds.'),
    StoryLine(_chef, '', StoryMood.happy, 'Deal. But no more portal soup!'),
  ]),
];

/// Sahne secimi ve "gecmisi sessizce gorulmus say" kurali.
class MbStory {
  MbStory._();

  static String keyFor(String id) => 'story_$id';

  /// Bu bolum numarasinda sahne acilmis mi?
  /// arrive: dunyanin ilk bolumune girildi; clue: dunyanin son bolumu bitti;
  /// finale: 6. dunyanin son bolumu bitti.
  static bool eligible(StoryScene s, int chapter) {
    const cpw = MbState.chaptersPerWorld;
    switch (s.kind) {
      case StoryKind.arrive:
        return chapter > s.world * cpw;
      case StoryKind.clue:
        return chapter > (s.world + 1) * cpw;
      case StoryKind.finale:
        return chapter > MbState.worlds * cpw;
    }
  }

  /// Gorulmemis ve acilmis tum sahneler (oynanis sirasinda).
  static List<StoryScene> pending(int chapter, bool Function(String id) seen) => [
        for (final s in kStoryScenes)
          if (eligible(s, chapter) && !seen(s.id)) s,
      ];

  /// Sirada gosterilecek sahne (yoksa null).
  static StoryScene? next(int chapter, bool Function(String id) seen) {
    final p = pending(chapter, seen);
    return p.isEmpty ? null : p.first;
  }

  /// Hikaye sistemi yokken ilerlemis oyuncu: onune sahne yigilmasin.
  /// 2'den fazla bekleyen varsa ILK (hikayenin kurulusu) ve SON (bulundugu dunya)
  /// gosterilir, aradakiler sessizce gorulmus sayilir.
  static List<String> catchUpSkips(int chapter, bool Function(String id) seen) {
    final p = pending(chapter, seen);
    if (p.length <= 2) return const [];
    return [for (var i = 1; i < p.length - 1; i++) p[i].id];
  }

  /// Dunya basina arka plan vurgu rengi (ARGB).
  static const List<int> accents = [
    0xFFFF8A3D, // fast food
    0xFF8D6E63, // kafe
    0xFF7E57C2, // buyu
    0xFF1E88E5, // korsan
    0xFF4FC3F7, // buz
    0xFF5C6BC0, // uzay
  ];
  static const int finaleAccent = 0xFFFFC107;

  static int accentFor(StoryScene s) => s.kind == StoryKind.finale ? finaleAccent : accents[s.world.clamp(0, 5)];
}
