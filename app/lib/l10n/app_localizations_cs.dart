// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'AlienMatch';

  @override
  String get tagline => 'Seznamka beze slov.';

  @override
  String get start => 'Přistát';

  @override
  String get adultConfirm => 'Je mi 18 nebo víc';

  @override
  String get moodConsentTitle => 'Signál nálady z tváře a hlasu';

  @override
  String get moodConsentBody =>
      'Volitelné. Denní check-in vyhodnotí naše vlastní servery v EU; video a zvuk se hned po vyhodnocení smažou. Bez souhlasu se hodnotíš jen sám.';

  @override
  String get privacyPolicy => 'Zásady ochrany soukromí';

  @override
  String get next => 'Dál';

  @override
  String get back => 'Zpět';

  @override
  String get captureHint => 'Obličej do oválu, nos na čáru';

  @override
  String get capture => 'Vyfotit';

  @override
  String get retake => 'Znovu';

  @override
  String get cameraUnavailable =>
      'Kamera není dostupná. Profilovou fotku jde pořídit jen živě.';

  @override
  String get pickVariant => 'Který mimozemšťan jsi ty?';

  @override
  String get variantNote =>
      'Telefon opustí jen ten, kterého vybereš. Originál nikdy.';

  @override
  String get generationTitle => 'Tvoje generace';

  @override
  String get statusTitle => 'Status';

  @override
  String get kidsTitle => 'Děti (volitelné)';

  @override
  String get intentsTitle => 'Na co máš chuť?';

  @override
  String get seekTitle => 'Koho hledáš?';

  @override
  String get modesTitle => 'Maják';

  @override
  String get beaconSwitch => 'Můžu být majákem pro někoho, komu není dobře';

  @override
  String get encourageSwitch => 'Chci, aby mě někdo povzbudil';

  @override
  String get beaconOnlySwitch => 'Nehledám vztah, jen svítím';

  @override
  String get nicknameTitle => 'Přezdívka';

  @override
  String get nicknameHint => 'až 12 znaků';

  @override
  String get finish => 'Hotovo';

  @override
  String get errorGeneric => 'Něco se pokazilo. Zkus to znovu.';

  @override
  String get retry => 'Zkusit znovu';

  @override
  String get checkinTitle => 'Jak ti dnes je?';

  @override
  String get checkinSend => 'Vyslat signál';

  @override
  String get checkinDone => 'Signál přijat. Zítra zas.';

  @override
  String get checkinSelfOnly =>
      'Zatím se posílá jen tvoje vlastní hodnocení. Signál z tváře a hlasu se připravuje.';

  @override
  String get supportTitle => 'Pár těžších dní?';

  @override
  String supportBody(String phone) {
    return 'Nemusíš na to být sám. Linka první psychické pomoci: $phone. Romantický radar je teď pozastavený, majáky zůstávají.';
  }

  @override
  String get askAgain =>
      'Tvůj signál a hodnocení se trochu liší. Zítra se zeptáme znovu.';

  @override
  String get radarTitle => 'Radar';

  @override
  String get offRadar => 'Jsi mimo radar. Pošli dnešní signál a objevíš se.';

  @override
  String get radarEmpty => 'Zatím prázdná obloha. Zkus to později.';

  @override
  String get planetMatch => 'Signál na match';

  @override
  String get planetEncourage => 'Maják';

  @override
  String get sharedStar => 'Sdílíte hvězdu';

  @override
  String get weakSignal => 'Slabý společný signál';

  @override
  String get placesTitle => 'Moje hvězdy';

  @override
  String get placesSearchHint => 'Zastávka, linka, kavárna, škola…';

  @override
  String placesLimit(int max) {
    return 'Nejvýš $max míst';
  }

  @override
  String get placesSaved => 'Hvězdy uloženy';

  @override
  String get save => 'Uložit';

  @override
  String get settingsTitle => 'Nastavení';

  @override
  String get locationDataTitle => 'Co o tvé poloze víme';

  @override
  String get locationDataBody =>
      'Tohle je všechno. GPS souřadnice nikdy nedostáváme.';

  @override
  String activeKeys(int count) {
    return 'Aktivní klíče potkání: $count';
  }

  @override
  String venueCheckins(int count) {
    return 'Check-iny v podnicích: $count';
  }

  @override
  String get noPlaces => 'Žádná vybraná místa';

  @override
  String get deleteAccount => 'Smazat účet';

  @override
  String get deleteConfirmTitle => 'Smazat všechno?';

  @override
  String get deleteConfirmBody =>
      'Fotka, profil, signály i zdi se hned smažou. Nejde to vrátit.';

  @override
  String get cancel => 'Zrušit';

  @override
  String get delete => 'Smazat';

  @override
  String get navRadar => 'Radar';

  @override
  String get navCheckin => 'Signál';

  @override
  String get navPlaces => 'Hvězdy';

  @override
  String get navSettings => 'Nastavení';

  @override
  String get genGenz => 'Gen Z';

  @override
  String get genMillennial => 'Mileniál';

  @override
  String get genGenx => 'Gen X';

  @override
  String get genBoomer => 'Baby boomer';

  @override
  String get statusSingle => 'Single';

  @override
  String get statusMarried => 'Ženatý / vdaná';

  @override
  String get statusDivorced => 'Rozvedený / á';

  @override
  String get statusComplicated => 'Je to složité';

  @override
  String get intentFlirt => 'Flirt';

  @override
  String get intentSex => 'Sex';

  @override
  String get intentChat => 'Pokec';

  @override
  String get intentCoffee => 'Kafe';

  @override
  String get intentBeer => 'Pivo';

  @override
  String get intentWine => 'Víno';

  @override
  String get intentTea => 'Čaj';

  @override
  String get intentWalk => 'Procházka';

  @override
  String get intentPlay => 'Hraní';

  @override
  String get kidsBoys => 'Kluci';

  @override
  String get kidsGirls => 'Holky';

  @override
  String get kidsTwins => 'Dvojčata';

  @override
  String get kidsTriplets => 'Trojčata';
}
