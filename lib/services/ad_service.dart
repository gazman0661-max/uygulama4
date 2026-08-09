/// Ödüllü reklam gösterimini soyutlayan servis.
///
/// ÖNEMLİ: Bu projeye şu an GERÇEK bir reklam SDK'sı (Unity LevelPlay,
/// Yandex Ads vb.) bağlı değil (pubspec.yaml'da ilgili paket yok). Bu yüzden
/// [showRewardedAd] şimdilik dürüst bir STUB: her zaman "reklam bulunamadı"
/// (no-fill) anlamına gelen `false` döner — sahte/otomatik puan verilmez.
///
/// Gerçek SDK entegre edilince yapılması gereken TEK şey: bu fonksiyonun
/// gövdesini gerçek SDK çağrısıyla değiştirmek —
///   - Reklam yüklenip SONUNA KADAR izlenip ödül sinyali geldiyse -> true
///   - Reklam yüklenemediyse (no-fill), hata verdiyse, veya kullanıcı
///     ödül kazanmadan yarıda kapattıysa -> false
/// Çağıran taraf (home_screen.dart _buildAdButton) hiç değişmeden çalışmaya
/// devam eder: true -> +5 puan ekle, false -> "Reklam Bulunamadı" popup'ı.
class AdService {
  AdService._();

  static Future<bool> showRewardedAd() async {
    // TODO: Gerçek reklam SDK'sı buraya bağlanacak, örn.:
    //   Unity LevelPlay (IronSource): IronSource.loadRewardedVideo(...) +
    //     onRewardedVideoAdRewarded callback'i true, onRewardedVideoAdShowFailed
    //     veya isRewardedVideoAvailable()==false false döndürmeli.
    //   Yandex Ads: RewardedAdLoader ile yükleyip onAdLoaded/onAdFailedToLoad
    //     ve onRewarded/onAdShowFailed sinyallerine göre true/false.
    await Future.delayed(const Duration(milliseconds: 400));
    return false;
  }
}
