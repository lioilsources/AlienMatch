// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Slovak (`sk`).
class AppLocalizationsSk extends AppLocalizations {
  AppLocalizationsSk([String locale = 'sk']) : super(locale);

  @override
  String get appTitle => 'AlienMatch';

  @override
  String get tagline => 'Zoznamka bez slov.';

  @override
  String get start => 'Pristáť';

  @override
  String get adultConfirm => 'Mám 18 alebo viac';

  @override
  String get moodConsentTitle => 'Signál nálady z tváre a hlasu';

  @override
  String get moodConsentBody =>
      'Voliteľné. Denný check-in vyhodnotia naše vlastné servery v EÚ; video a zvuk sa hneď po vyhodnotení zmažú. Bez súhlasu sa hodnotíš len sám.';

  @override
  String get privacyPolicy => 'Zásady ochrany súkromia';

  @override
  String get next => 'Ďalej';

  @override
  String get back => 'Späť';

  @override
  String get captureHint =>
      'Vnútorný kruh otáča zrkadlom, vonkajší celým obrazom';

  @override
  String get capture => 'Odfotiť';

  @override
  String get retake => 'Znova';

  @override
  String get cameraUnavailable =>
      'Kamera nie je dostupná. Profilovú fotku možno urobiť len naživo.';

  @override
  String get pickVariant => 'Ktorý mimozemšťan si ty?';

  @override
  String get variantNote =>
      'Telefón opustí len ten, ktorého vyberieš. Originál nikdy.';

  @override
  String get generationTitle => 'Tvoja generácia';

  @override
  String get statusTitle => 'Status';

  @override
  String get kidsTitle => 'Deti (voliteľné)';

  @override
  String get intentsTitle => 'Na čo máš chuť?';

  @override
  String get seekTitle => 'Koho hľadáš?';

  @override
  String get modesTitle => 'Maják';

  @override
  String get beaconSwitch => 'Môžem byť majákom pre niekoho, komu nie je dobre';

  @override
  String get encourageSwitch => 'Chcem, aby ma niekto povzbudil';

  @override
  String get beaconOnlySwitch => 'Nehľadám vzťah, len svietim';

  @override
  String get nicknameTitle => 'Prezývka';

  @override
  String get nicknameHint => 'až 12 znakov';

  @override
  String get finish => 'Hotovo';

  @override
  String get errorGeneric => 'Niečo sa pokazilo. Skús to znova.';

  @override
  String get retry => 'Skúsiť znova';

  @override
  String get checkinTitle => 'Ako sa dnes máš?';

  @override
  String get checkinSend => 'Vyslať signál';

  @override
  String get checkinDone => 'Signál prijatý. Zajtra zas.';

  @override
  String get checkinSelfOnly =>
      'Zatiaľ sa posiela len tvoje vlastné hodnotenie. Signál z tváre a hlasu sa pripravuje.';

  @override
  String get supportTitle => 'Pár ťažších dní?';

  @override
  String supportBody(String phone) {
    return 'Nemusíš na to byť sám. Linka pomoci: $phone. Romantický radar je teraz pozastavený, majáky zostávajú.';
  }

  @override
  String get askAgain =>
      'Tvoj signál a hodnotenie sa trochu líšia. Zajtra sa spýtame znova.';

  @override
  String get radarTitle => 'Radar';

  @override
  String get offRadar => 'Si mimo radaru. Pošli dnešný signál a objavíš sa.';

  @override
  String get radarEmpty => 'Zatiaľ prázdna obloha. Skús to neskôr.';

  @override
  String get planetMatch => 'Signál na match';

  @override
  String get planetEncourage => 'Maják';

  @override
  String get sharedStar => 'Zdieľate hviezdu';

  @override
  String get weakSignal => 'Slabý spoločný signál';

  @override
  String get placesTitle => 'Moje hviezdy';

  @override
  String get placesSearchHint => 'Zastávka, linka, kaviareň, škola…';

  @override
  String placesLimit(int max) {
    return 'Najviac $max miest';
  }

  @override
  String get placesSaved => 'Hviezdy uložené';

  @override
  String get save => 'Uložiť';

  @override
  String get settingsTitle => 'Nastavenia';

  @override
  String get locationDataTitle => 'Čo o tvojej polohe vieme';

  @override
  String get locationDataBody =>
      'Toto je všetko. GPS súradnice nikdy nedostávame.';

  @override
  String activeKeys(int count) {
    return 'Aktívne kľúče stretnutí: $count';
  }

  @override
  String venueCheckins(int count) {
    return 'Check-iny v podnikoch: $count';
  }

  @override
  String get noPlaces => 'Žiadne vybrané miesta';

  @override
  String get deleteAccount => 'Zmazať účet';

  @override
  String get deleteConfirmTitle => 'Zmazať všetko?';

  @override
  String get deleteConfirmBody =>
      'Fotka, profil, signály aj steny sa hneď zmažú. Nedá sa to vrátiť.';

  @override
  String get cancel => 'Zrušiť';

  @override
  String get delete => 'Zmazať';

  @override
  String get navRadar => 'Radar';

  @override
  String get navCheckin => 'Signál';

  @override
  String get navPlaces => 'Hviezdy';

  @override
  String get navSettings => 'Nastavenia';

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
  String get statusMarried => 'Ženatý / vydatá';

  @override
  String get statusDivorced => 'Rozvedený / á';

  @override
  String get statusComplicated => 'Je to zložité';

  @override
  String get intentFlirt => 'Flirt';

  @override
  String get intentSex => 'Sex';

  @override
  String get intentChat => 'Pokec';

  @override
  String get intentCoffee => 'Káva';

  @override
  String get intentBeer => 'Pivo';

  @override
  String get intentWine => 'Víno';

  @override
  String get intentTea => 'Čaj';

  @override
  String get intentWalk => 'Prechádzka';

  @override
  String get intentPlay => 'Hranie';

  @override
  String get kidsBoys => 'Chlapci';

  @override
  String get kidsGirls => 'Dievčatá';

  @override
  String get kidsTwins => 'Dvojčatá';

  @override
  String get kidsTriplets => 'Trojčatá';

  @override
  String get navWalls => 'Steny';

  @override
  String get wave => 'Zamávať';

  @override
  String get waveSent => 'Zamávané. Keď zamáva aj on/ona, otvorí sa vám stena.';

  @override
  String get matched => 'Je to vzájomné! Vaša stena je otvorená.';

  @override
  String get waveLimit => 'Na dnes máš zamávania vyčerpané.';

  @override
  String get wallsEmpty => 'Zatiaľ žiadne steny. Zamávaj niekomu na radare.';

  @override
  String get youShare => 'Obaja chodíte';

  @override
  String get draw => 'Nakresliť sticker';

  @override
  String get undo => 'Späť';

  @override
  String get stick => 'Nalepiť';

  @override
  String get report => 'Nahlásiť';

  @override
  String get reportBlock => 'Nahlásiť a zablokovať';

  @override
  String get peel => 'Odlepiť';

  @override
  String get wallEnded => 'Táto stena skončila.';

  @override
  String get pendingSync => 'Čaká na pripojenie';

  @override
  String get encouragementWall => 'Stena majáka';

  @override
  String get flybyTitle => 'Prelet';

  @override
  String get flybyBody =>
      'Telefón cez Bluetooth spozná iné telefóny s AlienMatch nablízku, napríklad v tej istej električke. Polohu nepoužíva. Kto to bol, sa dozvieš, len keď zamávate obaja.';

  @override
  String get flybyRadioOff => 'Bluetooth je vypnutý alebo chýba povolenie.';

  @override
  String get flybyVehicle => 'rovnaký spoj';

  @override
  String get flybyStop => 'rovnaká zastávka';

  @override
  String get flybyVenue => 'rovnaký podnik';

  @override
  String flybyMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get flybyComet => 'Stretli ste sa';

  @override
  String get flybyStrip => 'Prelety';

  @override
  String get checkinVideo => 'Video + hlas';

  @override
  String get checkinVoice => 'Len hlas';

  @override
  String get checkinNoRecording => 'Len moje hodnotenie';

  @override
  String get checkinPrompt1 => 'Povedz, ako sa dnes máš.';

  @override
  String get checkinPrompt2 => 'Čo ťa dnes čaká?';

  @override
  String get checkinRateNow => 'A teraz to ohodnoť sám/sama:';

  @override
  String get checkinSignalUsed =>
      'Signál z tváre a hlasu započítaný. Tvoje hodnotenie má stále väčšiu váhu.';

  @override
  String get checkinMediaNote => 'Nahrávka sa hneď po vyhodnotení zmaže.';

  @override
  String get checkinNoPermission =>
      'Chýba povolenie ku kamere alebo mikrofónu.';

  @override
  String get checkinSignalPending =>
      'Signál z tváre a hlasu sa pripravuje, dopočíta sa o pár minút.';

  @override
  String get usePhoto => 'Toto som ja';

  @override
  String get switchSide => 'Druhá polovica';

  @override
  String get switchCamera => 'Prepnúť kameru';

  @override
  String filterLabel(String name) {
    return 'Filter $name';
  }

  @override
  String get filterNone => 'Žiadny';

  @override
  String get filterGlow => 'Žiara';

  @override
  String get filterSlim => 'Štíhlosť';

  @override
  String get filterDoll => 'Bábika';

  @override
  String get filterChibi => 'Chibi';

  @override
  String get filterLips => 'Pery';

  @override
  String get filterBigNose => 'Nos';

  @override
  String get filterAlien => 'Ufón';

  @override
  String get filterMelt => 'Topenie';

  @override
  String get filterBigEars => 'Uši';

  @override
  String get filterLongNeck => 'Krk';

  @override
  String get filterPencil => 'Ceruzka';

  @override
  String get filterComic => 'Komiks';

  @override
  String get filterGlitch => 'Glitch';

  @override
  String get filterNeon => 'Neón';

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
  String get collectionUgly => 'Škaredosť';

  @override
  String get collectionArt => 'Umenie';

  @override
  String get collectionFantasy => 'Fantasy';

  @override
  String get albumTitle => 'Moje tváre';

  @override
  String get albumNote =>
      'Tváre zostávajú len v telefóne. Server dostane len tú, ktorú máš ako profilovku.';

  @override
  String get newFace => 'Nová tvár';

  @override
  String get keepShooting => 'Uložiť a fotiť ďalej';

  @override
  String get albumFull => 'Album je plné (12). Najprv nejakú tvár zmaž.';

  @override
  String get faceActive => 'Profilovka';

  @override
  String get setAsProfile => 'Nastaviť ako profilovku';

  @override
  String get deleteFace => 'Zmazať tvár';

  @override
  String get starsTitle => 'Najžiarivejšie hviezdy';

  @override
  String get starsHint => 'Do strán listuješ, hore sa ti páči, dole nie';

  @override
  String get like => 'Páči sa';

  @override
  String get dislike => 'Nepáči sa';

  @override
  String get ratedSeen => 'Preskočené';

  @override
  String get starsEmpty =>
      'Teraz tu nesvieti žiadna žiarivá hviezda. Skús to neskôr.';

  @override
  String get starsDone =>
      'To boli všetky hviezdy. Vráť sa doľava, ak chceš niečo zmeniť.';

  @override
  String get likedTitle => 'Obľúbení mimozemšťania';

  @override
  String get likedEmpty => 'Zatiaľ nikto. Koho dáš hore, uloží sa sem.';

  @override
  String get notOnRadarNow => 'Teraz nie je na tvojom radare';

  @override
  String get feedbackTitle => 'Ohlas vesmíru';

  @override
  String get feedbackNote =>
      'Koľko hviezd tvoju tvár videlo a ako ju ohodnotili. Kto hodnotil, sa nedozvieš.';

  @override
  String get feedbackEmpty => 'Zatiaľ tvoju tvár nikto nehodnotil.';

  @override
  String get dislikesHidden =>
      'Teraz ukazujeme len to dobré. Zvyšok uvidíš, keď budeš mať viac energie.';

  @override
  String get olderFace => 'Staršia tvár';

  @override
  String get statsTitle => 'Anonymné štatistiky';

  @override
  String get statsBody =>
      'Ktoré obrazovky a funkcie sa používajú, aby sme appku zlepšili. Nie sú prepojené s tvojím účtom: nič z profilu, stien ani signálu. Vypnutie zmaže neodoslané záznamy.';
}
