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
  String get captureHint => 'Vnitřní kruh otáčí zrcadlem, vnější celým obrazem';

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

  @override
  String get navWalls => 'Zdi';

  @override
  String get wave => 'Zamávat';

  @override
  String get waveSent => 'Zamáváno. Když zamává taky, otevře se vám zeď.';

  @override
  String get matched => 'Je to vzájemné! Vaše zeď je otevřená.';

  @override
  String get waveLimit => 'Na dnešek máš zamávání vyčerpaná.';

  @override
  String get wallsEmpty => 'Zatím žádné zdi. Zamávej někomu na radaru.';

  @override
  String get youShare => 'Oba chodíte';

  @override
  String get draw => 'Nakreslit sticker';

  @override
  String get undo => 'Zpět';

  @override
  String get stick => 'Nalepit';

  @override
  String get report => 'Nahlásit';

  @override
  String get reportBlock => 'Nahlásit a zablokovat';

  @override
  String get peel => 'Odlepit';

  @override
  String get wallEnded => 'Tahle zeď skončila.';

  @override
  String get pendingSync => 'Čeká na připojení';

  @override
  String get encouragementWall => 'Zeď majáku';

  @override
  String get flybyTitle => 'Průlet';

  @override
  String get flybyBody =>
      'Telefon přes Bluetooth pozná jiné AlienMatch telefony poblíž, třeba ve stejné tramvaji. Polohu nepoužívá. Kdo to byl, se dozvíš, jen když zamáváte oba.';

  @override
  String get flybyRadioOff => 'Bluetooth je vypnutý nebo chybí povolení.';

  @override
  String get flybyVehicle => 'stejný spoj';

  @override
  String get flybyStop => 'stejná zastávka';

  @override
  String get flybyVenue => 'stejný podnik';

  @override
  String flybyMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get flybyComet => 'Potkali jste se';

  @override
  String get flybyStrip => 'Průlety';

  @override
  String get checkinVideo => 'Video + hlas';

  @override
  String get checkinVoice => 'Jen hlas';

  @override
  String get checkinNoRecording => 'Jen moje hodnocení';

  @override
  String get checkinPrompt1 => 'Řekni, jak ti dnes je.';

  @override
  String get checkinPrompt2 => 'Co tě dnes čeká?';

  @override
  String get checkinRateNow => 'A teď to ohodnoť sám/sama:';

  @override
  String get checkinSignalUsed =>
      'Signál z tváře a hlasu započítán. Tvoje hodnocení má pořád větší váhu.';

  @override
  String get checkinMediaNote => 'Nahrávka se hned po vyhodnocení smaže.';

  @override
  String get checkinNoPermission => 'Chybí povolení ke kameře nebo mikrofonu.';

  @override
  String get checkinSignalPending =>
      'Signál z tváře a hlasu se připravuje, dopočítá se za pár minut.';

  @override
  String get usePhoto => 'Tohle jsem já';

  @override
  String get switchSide => 'Druhá polovina';

  @override
  String get switchCamera => 'Přepnout kameru';

  @override
  String filterLabel(String name) {
    return 'Filtr $name';
  }

  @override
  String get filterNone => 'Žádný';

  @override
  String get filterGlow => 'Záře';

  @override
  String get filterSlim => 'Štíhlost';

  @override
  String get filterDoll => 'Panenka';

  @override
  String get filterChibi => 'Chibi';

  @override
  String get filterLips => 'Rty';

  @override
  String get filterBigNose => 'Nos';

  @override
  String get filterAlien => 'Ufon';

  @override
  String get filterMelt => 'Tání';

  @override
  String get filterBigEars => 'Uši';

  @override
  String get filterLongNeck => 'Krk';

  @override
  String get filterPencil => 'Tužka';

  @override
  String get filterComic => 'Komiks';

  @override
  String get filterGlitch => 'Glitch';

  @override
  String get filterNeon => 'Neon';

  @override
  String get filterThermal => 'Teplo';

  @override
  String get filterOil => 'Olej';

  @override
  String get filterCrt => 'CRT';

  @override
  String get filterPopArt => 'Pop';

  @override
  String get filterVampire => 'Upír';

  @override
  String get filterZombie => 'Zombie';

  @override
  String get filterGhost => 'Duch';

  @override
  String get filterDemon => 'Démon';

  @override
  String get filterCyborg => 'Kyborg';

  @override
  String get filterFrozen => 'Mráz';

  @override
  String get collectionPretty => 'Krása';

  @override
  String get collectionUgly => 'Ošklivost';

  @override
  String get collectionArt => 'Umění';

  @override
  String get collectionFantasy => 'Fantasy';

  @override
  String get albumTitle => 'Moje tváře';

  @override
  String get albumNote =>
      'Tváře zůstávají jen v telefonu. Server dostane jen tu, kterou máš jako profilovku.';

  @override
  String get newFace => 'Nová tvář';

  @override
  String get keepShooting => 'Uložit a fotit dál';

  @override
  String get albumFull => 'Album je plné (12). Nejdřív nějakou tvář smaž.';

  @override
  String get faceActive => 'Profilovka';

  @override
  String get setAsProfile => 'Nastavit jako profilovku';

  @override
  String get deleteFace => 'Smazat tvář';

  @override
  String get starsTitle => 'Nejzářivější hvězdy';

  @override
  String get starsHint => 'Do stran listuješ, nahoru se ti líbí, dolů nelíbí';

  @override
  String get like => 'Líbí';

  @override
  String get dislike => 'Nelíbí';

  @override
  String get ratedSeen => 'Přeskočeno';

  @override
  String get starsEmpty =>
      'Teď tu nesvítí žádná zářivá hvězda. Zkus to později.';

  @override
  String get starsDone =>
      'Tohle byly všechny hvězdy. Vrať se doleva, jestli chceš něco změnit.';

  @override
  String get likedTitle => 'Oblíbení mimozemšťané';

  @override
  String get likedEmpty => 'Zatím nikdo. Koho dáš nahoru, uloží se sem.';

  @override
  String get notOnRadarNow => 'Teď není na tvém radaru';

  @override
  String get feedbackTitle => 'Ohlas vesmíru';

  @override
  String get feedbackNote =>
      'Kolik hvězd tvou tvář vidělo a jak ji ohodnotily. Kdo hodnotil, se nedozvíš.';

  @override
  String get feedbackEmpty => 'Zatím tvou tvář nikdo nehodnotil.';

  @override
  String get dislikesHidden =>
      'Teď ukazujeme jen to dobré. Zbytek uvidíš, až budeš mít víc energie.';

  @override
  String get olderFace => 'Starší tvář';
}
