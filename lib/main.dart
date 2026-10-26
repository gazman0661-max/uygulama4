import 'widgets/guided_tour.dart';
import 'localization/app_strings.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/game_progress.dart';
import 'services/analytics_service.dart';
import 'models/season.dart';
import 'models/mb_missions.dart';
import 'models/piggy.dart';
import 'models/engage.dart';
import 'models/weekly_event.dart';
import 'services/notification_service.dart';
import 'services/sfx_service.dart';
import 'services/music_service.dart';
import 'services/time_service.dart';
import 'services/cloud_save_service.dart';
import 'services/merge_board_service.dart';
import 'services/billing_service.dart';
import 'services/inbox_service.dart';
import 'services/legal_consent_service.dart';
import 'screens/splash_screen.dart';
import 'widgets/no_internet_dialog.dart';

import 'services/log_service.dart';
Future<void> main() async {
  // Kayitli ilerlemeyi (varsa) uygulama acilmadan once diskten okuyoruz -
  // boylece ana menu ilk karesinden itibaren dogru coin/enerji/gorev
  // durumunu gosterir.
  WidgetsFlutterBinding.ensureInitialized();
  // HATA GUNLUGU: en basta kur (Ayarlar > Hata Kayitlari'ndan gorulur).
  await AppLog.instance.init();
  AppLog.instance.installHandlers();
  // Oyun dikey (portrait) oynanir.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  // Internet saati: enerji/gorev/gunluk odul artik cihaz saatine degil
  // sunucu saatine bakar. En fazla ~3 sn bekler, sonra oyun acilir.
  await AppStrings.instance.load(); // kayitli/cihaz dili
  await TimeService.instance.init();
  AppLog.i('boot', 'dil/saat tamam');
  await AppLog.instance.storageDiagnostics('acilis'); // kayit kalici mi?
  await LegalConsentService.instance.load();
  AppLog.i('boot', 'onay yuklendi: kabul=${LegalConsentService.instance.accepted}');
  await GameProgress.instance.load();
  AppLog.i('boot', 'ilerleme yuklendi: bolum=${GameProgress.instance.maxUnlockedChapter} seviye=${GameProgress.instance.playerLevel} coin=${GameProgress.instance.coins}');
  await AnalyticsService.instance.load(); // ogretici hunisi sayaclari
  await SeasonService.instance.load();
  await MbMissions.instance.load(); // Mod 2 gorevleri (cihaza ozel kayit)
  await PiggyService.instance.load();
  await WeeklyEvent.instance.load();
  await EngageService.instance.load();
  await InboxService.instance.load(); // gelen kutusu / davet kimligi (ag istegi yok)
  EngageService.instance.skipWelcomeForExistingPlayer();
  EngageService.instance.onAppOpen();
  await NotificationService.instance.init();
  // Ses efektlerini arka planda yukle (BEKLEMEDEN) - oyun acilisini
  // geciktirmez; yukleme bitene kadar gelen sesler sessizce atlanir.
  SfxService.instance.init();
  MusicService.instance.start();
  // Play Games bulut yedegi: acilista sessiz oturum kontrolu (BEKLENMEZ),
  // yerel kayit yazildikca (45 sn'de bir) buluta yukle.
  GameProgress.onSaved = CloudSaveService.instance.scheduleUpload;
  MergeBoardService.onSaved = CloudSaveService.instance.scheduleUpload; // Mod 2 ilerlemesi de buluta gider
  MbMissions.onSaved = CloudSaveService.instance.scheduleUpload; // Mod 2 gorevleri de buluta gider
  // Davet edilen oyuncu hedef seviyeye (7) ulasinca sunucuya haber ver (baska seviye atlamada istek yok).
  GameProgress.onLevelUp = InboxService.instance.onPlayerLevelUp;
  CloudSaveService.instance.init();
  AppLog.i('boot', 'runApp');
  runApp(const FastFoodMergeApp());
  // Reklam SDK'si: arayuz ekrandayken, BEKLENMEDEN kurulur (SDK sorun cikarsa
  // oyun acilisi etkilenmesin). Anahtar girilene kadar reklamlar simule edilir.
  // Play Billing: urunleri/fiyatlari yukler, yarim kalan satin almalari teslim eder.
  unawaited(BillingService.instance.init());
  // Push bildirimi (gelen kutusu): Firebase bilgileri girilene kadar hicbir sey yapmaz.
  // Reklam SDK'si + push: SADECE kullanici ilk acilis onayini (Sartlar/Gizlilik/GDPR)
  // verdiyse burada baslar; ilk kez acan oyuncuda onaydan hemen sonra baslatilir.
  LegalConsentService.instance.startConsentGatedServices();
}

class FastFoodMergeApp extends StatefulWidget {
  const FastFoodMergeApp({super.key});

  @override
  State<FastFoodMergeApp> createState() => _FastFoodMergeAppState();
}

class _FastFoodMergeAppState extends State<FastFoodMergeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    AppLog.w('sistem', 'BELLEK BASKISI (Android bellek az uyarisi)');
  }

  @override
  void didChangeMetrics() {
    final v = WidgetsBinding.instance.platformDispatcher.views;
    if (v.isNotEmpty) {
      final f = v.first;
      AppLog.i('sistem', 'ekran olcusu: ${f.physicalSize.width.round()}x${f.physicalSize.height.round()} dpr=${f.devicePixelRatio.toStringAsFixed(2)}');
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    AppLog.i('sistem', 'dil degisti: $locales');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLog.i('lifecycle', '$state');
    // Uygulama arka plana alinirken ya da kapanirken bekleyen (debounce
    // edilmis) kayit varsa hemen diske yaz - son saniyedeki coin/enerji
    // degisikligi kaybolmasin.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      AppLog.instance.flush();
      GameProgress.instance.flush();
      CloudSaveService.instance.flushUpload();
      MusicService.instance.onPaused();
      EngageService.instance.touch();
      if (state == AppLifecycleState.paused) NotificationService.instance.scheduleAll();
      TimeService.instance.onPaused();
    } else if (state == AppLifecycleState.resumed) {
      // Arka plandan donunce sunucu saatiyle yeniden senkron ol.
      TimeService.instance.syncWithServer();
      CloudSaveService.instance.onResumed();
      BillingService.instance.onResumed();
      if (LegalConsentService.instance.accepted) InboxService.instance.maybeSync(); // onaydan once kimlik/istek yok
      MusicService.instance.onResumed();
      EngageService.instance.onAppOpen();
      NotificationService.instance.cancelAll();
      // Arka plandan donunce internet yeniden kontrol edilir (yoksa uyari -> cikis).
      NoInternetDialog.recheckOnResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: GuidedTour.navKey ??= GlobalKey<NavigatorState>(),
      navigatorObservers: [AppNavLogger()],
      title: 'Worlds Merge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Baloo2',
        colorSchemeSeed: Colors.deepOrange,
        scaffoldBackgroundColor: Colors.orange.shade50,
      ),
      // Her dokunusta muzigi (gerekirse) baslat - web'de autoplay engelini asar.
      // v176: cihazin yazi tipi boyutu (Ayarlar > Ekran > Yazi boyutu) oyunu ETKILEMESIN:
      // tum uygulama icin yazi olcegi sabit 1.0. Boylece her cihazda ayni yerlesim gorunur.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            MusicService.instance.kickstart();
            AppLog.i('dokunus', 'x=${e.position.dx.round()} y=${e.position.dy.round()}');
          },
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}


/// Her ekran gecisini (acilan/kapanan/degisen rota, bottom sheet, dialog dahil) loglar.
class AppNavLogger extends NavigatorObserver {
  String _n(Route<dynamic>? r) {
    if (r == null) return '-';
    final n = r.settings.name;
    return (n != null && n.isNotEmpty) ? n : r.runtimeType.toString();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppLog.i('rota', 'PUSH ${_n(route)} (onceki: ${_n(previousRoute)})');

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppLog.i('rota', 'POP ${_n(route)} (donulen: ${_n(previousRoute)})');

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      AppLog.i('rota', 'REPLACE ${_n(oldRoute)} -> ${_n(newRoute)}');

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppLog.i('rota', 'REMOVE ${_n(route)}');
}
