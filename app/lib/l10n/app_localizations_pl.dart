// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'AlienMatch';

  @override
  String get tagline => 'Randki bez słów.';

  @override
  String get start => 'Wyląduj';

  @override
  String get adultConfirm => 'Mam 18 lat lub więcej';

  @override
  String get moodConsentTitle => 'Sygnał nastroju z twarzy i głosu';

  @override
  String get moodConsentBody =>
      'Opcjonalne. Codzienny check-in oceniają nasze własne serwery w UE; wideo i dźwięk są usuwane zaraz po ocenie. Bez zgody oceniasz się tylko sam.';

  @override
  String get privacyPolicy => 'Polityka prywatności';

  @override
  String get next => 'Dalej';

  @override
  String get back => 'Wstecz';

  @override
  String get captureHint =>
      'Wewnętrzny pierścień obraca lustro, zewnętrzny cały obraz';

  @override
  String get capture => 'Zrób zdjęcie';

  @override
  String get retake => 'Jeszcze raz';

  @override
  String get cameraUnavailable =>
      'Aparat jest niedostępny. Zdjęcie profilowe można zrobić tylko na żywo.';

  @override
  String get pickVariant => 'Którym kosmitą jesteś?';

  @override
  String get variantNote => 'Telefon opuszcza tylko wybrany. Oryginał nigdy.';

  @override
  String get generationTitle => 'Twoje pokolenie';

  @override
  String get statusTitle => 'Status';

  @override
  String get kidsTitle => 'Dzieci (opcjonalnie)';

  @override
  String get intentsTitle => 'Na co masz ochotę?';

  @override
  String get seekTitle => 'Kogo szukasz?';

  @override
  String get modesTitle => 'Latarnia';

  @override
  String get beaconSwitch => 'Mogę być latarnią dla kogoś, komu jest ciężko';

  @override
  String get encourageSwitch => 'Chcę, żeby ktoś mnie podniósł na duchu';

  @override
  String get beaconOnlySwitch => 'Nie szukam związku, tylko świecę';

  @override
  String get nicknameTitle => 'Pseudonim';

  @override
  String get nicknameHint => 'do 12 znaków';

  @override
  String get finish => 'Gotowe';

  @override
  String get errorGeneric => 'Coś poszło nie tak. Spróbuj ponownie.';

  @override
  String get retry => 'Spróbuj ponownie';

  @override
  String get checkinTitle => 'Jak się dziś czujesz?';

  @override
  String get checkinSend => 'Wyślij sygnał';

  @override
  String get checkinDone => 'Sygnał odebrany. Do jutra.';

  @override
  String get checkinSelfOnly =>
      'Na razie wysyłana jest tylko twoja własna ocena. Sygnał z twarzy i głosu jest w przygotowaniu.';

  @override
  String get supportTitle => 'Kilka cięższych dni?';

  @override
  String supportBody(String phone) {
    return 'Nie musisz być z tym sam. Telefon wsparcia: $phone. Romantyczny radar jest wstrzymany, latarnie pozostają.';
  }

  @override
  String get askAgain =>
      'Twój sygnał i ocena trochę się różnią. Zapytamy jutro ponownie.';

  @override
  String get radarTitle => 'Radar';

  @override
  String get offRadar =>
      'Jesteś poza radarem. Wyślij dzisiejszy sygnał, aby się pojawić.';

  @override
  String get radarEmpty => 'Na razie puste niebo. Wróć później.';

  @override
  String get planetMatch => 'Sygnał na match';

  @override
  String get planetEncourage => 'Latarnia';

  @override
  String get sharedStar => 'Dzielicie gwiazdę';

  @override
  String get weakSignal => 'Słaby wspólny sygnał';

  @override
  String get placesTitle => 'Moje gwiazdy';

  @override
  String get placesSearchHint => 'Przystanek, linia, kawiarnia, uczelnia…';

  @override
  String placesLimit(int max) {
    return 'Najwyżej $max miejsc';
  }

  @override
  String get placesSaved => 'Gwiazdy zapisane';

  @override
  String get save => 'Zapisz';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get locationDataTitle => 'Co wiemy o twojej lokalizacji';

  @override
  String get locationDataBody =>
      'To wszystko. Nigdy nie otrzymujemy współrzędnych GPS.';

  @override
  String activeKeys(int count) {
    return 'Aktywne klucze spotkań: $count';
  }

  @override
  String venueCheckins(int count) {
    return 'Check-iny w lokalach: $count';
  }

  @override
  String get noPlaces => 'Brak wybranych miejsc';

  @override
  String get deleteAccount => 'Usuń konto';

  @override
  String get deleteConfirmTitle => 'Usunąć wszystko?';

  @override
  String get deleteConfirmBody =>
      'Zdjęcie, profil, sygnały i ściany zostaną natychmiast usunięte. Nie da się tego cofnąć.';

  @override
  String get cancel => 'Anuluj';

  @override
  String get delete => 'Usuń';

  @override
  String get navRadar => 'Radar';

  @override
  String get navCheckin => 'Sygnał';

  @override
  String get navPlaces => 'Gwiazdy';

  @override
  String get navSettings => 'Ustawienia';

  @override
  String get genGenz => 'Pokolenie Z';

  @override
  String get genMillennial => 'Milenials';

  @override
  String get genGenx => 'Pokolenie X';

  @override
  String get genBoomer => 'Baby boomer';

  @override
  String get statusSingle => 'Singiel';

  @override
  String get statusMarried => 'W związku małżeńskim';

  @override
  String get statusDivorced => 'Rozwiedziony / a';

  @override
  String get statusComplicated => 'To skomplikowane';

  @override
  String get intentFlirt => 'Flirt';

  @override
  String get intentSex => 'Seks';

  @override
  String get intentChat => 'Pogaduszki';

  @override
  String get intentCoffee => 'Kawa';

  @override
  String get intentBeer => 'Piwo';

  @override
  String get intentWine => 'Wino';

  @override
  String get intentTea => 'Herbata';

  @override
  String get intentWalk => 'Spacer';

  @override
  String get intentPlay => 'Gry';

  @override
  String get kidsBoys => 'Chłopcy';

  @override
  String get kidsGirls => 'Dziewczynki';

  @override
  String get kidsTwins => 'Bliźnięta';

  @override
  String get kidsTriplets => 'Trojaczki';

  @override
  String get navWalls => 'Ściany';

  @override
  String get wave => 'Pomachaj';

  @override
  String get waveSent => 'Pomachano. Jeśli odmacha, otworzy się wasza ściana.';

  @override
  String get matched => 'To wzajemne! Wasza ściana jest otwarta.';

  @override
  String get waveLimit => 'Na dziś wykorzystano wszystkie machnięcia.';

  @override
  String get wallsEmpty => 'Brak ścian. Pomachaj komuś na radarze.';

  @override
  String get youShare => 'Oboje chodzicie do';

  @override
  String get draw => 'Narysuj naklejkę';

  @override
  String get undo => 'Cofnij';

  @override
  String get stick => 'Przyklej';

  @override
  String get report => 'Zgłoś';

  @override
  String get reportBlock => 'Zgłoś i zablokuj';

  @override
  String get peel => 'Odklej';

  @override
  String get wallEnded => 'Ta ściana się zakończyła.';

  @override
  String get pendingSync => 'Czeka na połączenie';

  @override
  String get encouragementWall => 'Ściana latarni';

  @override
  String get flybyTitle => 'Przelot';

  @override
  String get flybyBody =>
      'Telefon przez Bluetooth zauważa inne telefony z AlienMatch w pobliżu, np. w tym samym tramwaju. Bez lokalizacji. Kto to był, dowiesz się tylko, gdy oboje pomachacie.';

  @override
  String get flybyRadioOff => 'Bluetooth jest wyłączony lub brak uprawnień.';

  @override
  String get flybyVehicle => 'ten sam kurs';

  @override
  String get flybyStop => 'ten sam przystanek';

  @override
  String get flybyVenue => 'to samo miejsce';

  @override
  String flybyMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get flybyComet => 'Spotkaliście się';

  @override
  String get flybyStrip => 'Przeloty';

  @override
  String get checkinVideo => 'Wideo + głos';

  @override
  String get checkinVoice => 'Tylko głos';

  @override
  String get checkinNoRecording => 'Tylko moja ocena';

  @override
  String get checkinPrompt1 => 'Powiedz, jak się dziś czujesz.';

  @override
  String get checkinPrompt2 => 'Co cię dziś czeka?';

  @override
  String get checkinRateNow => 'A teraz oceń sam/sama:';

  @override
  String get checkinSignalUsed =>
      'Sygnał z twarzy i głosu uwzględniony. Twoja ocena nadal waży więcej.';

  @override
  String get checkinMediaNote => 'Nagranie jest usuwane zaraz po ocenie.';

  @override
  String get checkinNoPermission => 'Brak uprawnień do kamery lub mikrofonu.';

  @override
  String get checkinSignalPending =>
      'Sygnał z twarzy i głosu jest przygotowywany, zostanie dodany za kilka minut.';

  @override
  String get usePhoto => 'To ja';

  @override
  String get switchSide => 'Druga połowa';

  @override
  String get switchCamera => 'Zmień kamerę';

  @override
  String filterLabel(String name) {
    return 'Filtr $name';
  }

  @override
  String get filterNone => 'Brak';

  @override
  String get filterGlow => 'Blask';

  @override
  String get filterSlim => 'Smukłość';

  @override
  String get filterDoll => 'Lalka';

  @override
  String get filterChibi => 'Chibi';

  @override
  String get filterLips => 'Usta';

  @override
  String get filterBigNose => 'Nos';

  @override
  String get filterAlien => 'Ufoludek';

  @override
  String get filterMelt => 'Topnienie';

  @override
  String get filterBigEars => 'Uszy';

  @override
  String get filterLongNeck => 'Szyja';

  @override
  String get filterPencil => 'Ołówek';

  @override
  String get filterComic => 'Komiks';

  @override
  String get filterGlitch => 'Glitch';

  @override
  String get filterNeon => 'Neon';

  @override
  String get filterThermal => 'Ciepło';

  @override
  String get filterOil => 'Olej';

  @override
  String get filterCrt => 'CRT';

  @override
  String get filterPopArt => 'Pop';

  @override
  String get filterVampire => 'Wampir';

  @override
  String get filterZombie => 'Zombie';

  @override
  String get filterGhost => 'Duch';

  @override
  String get filterDemon => 'Demon';

  @override
  String get filterCyborg => 'Cyborg';

  @override
  String get filterFrozen => 'Mróz';

  @override
  String get collectionPretty => 'Piękno';

  @override
  String get collectionUgly => 'Brzydota';

  @override
  String get collectionArt => 'Sztuka';

  @override
  String get collectionFantasy => 'Fantasy';
}
