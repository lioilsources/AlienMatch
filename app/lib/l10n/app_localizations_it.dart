// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'AlienMatch';

  @override
  String get tagline => 'Incontri senza parole.';

  @override
  String get start => 'Atterra';

  @override
  String get adultConfirm => 'Ho 18 anni o più';

  @override
  String get moodConsentTitle => 'Segnale dell\'umore da viso e voce';

  @override
  String get moodConsentBody =>
      'Facoltativo. Il check-in giornaliero viene valutato sui nostri server nell\'UE; video e audio vengono cancellati subito dopo. Senza consenso ti valuti solo da te.';

  @override
  String get privacyPolicy => 'Informativa sulla privacy';

  @override
  String get next => 'Avanti';

  @override
  String get back => 'Indietro';

  @override
  String get captureHint => 'Viso nell\'ovale, naso sulla linea';

  @override
  String get capture => 'Scatta';

  @override
  String get retake => 'Di nuovo';

  @override
  String get cameraUnavailable =>
      'La fotocamera non è disponibile. La foto profilo si può fare solo dal vivo.';

  @override
  String get pickVariant => 'Quale alieno sei?';

  @override
  String get variantNote =>
      'Solo quello che scegli lascia il telefono. L\'originale mai.';

  @override
  String get generationTitle => 'La tua generazione';

  @override
  String get statusTitle => 'Stato';

  @override
  String get kidsTitle => 'Figli (facoltativo)';

  @override
  String get intentsTitle => 'Di cosa hai voglia?';

  @override
  String get seekTitle => 'Chi cerchi?';

  @override
  String get modesTitle => 'Faro';

  @override
  String get beaconSwitch => 'Posso essere un faro per chi è giù';

  @override
  String get encourageSwitch => 'Vorrei che qualcuno mi tirasse su';

  @override
  String get beaconOnlySwitch => 'Non cerco una relazione, brillo e basta';

  @override
  String get nicknameTitle => 'Soprannome';

  @override
  String get nicknameHint => 'fino a 12 caratteri';

  @override
  String get finish => 'Fatto';

  @override
  String get errorGeneric => 'Qualcosa è andato storto. Riprova.';

  @override
  String get retry => 'Riprova';

  @override
  String get checkinTitle => 'Come stai oggi?';

  @override
  String get checkinSend => 'Invia segnale';

  @override
  String get checkinDone => 'Segnale ricevuto. A domani.';

  @override
  String get checkinSelfOnly =>
      'Per ora viene inviata solo la tua valutazione. Il segnale da viso e voce è in arrivo.';

  @override
  String get supportTitle => 'Qualche giorno pesante?';

  @override
  String supportBody(String phone) {
    return 'Non devi affrontarlo da solo. Linea di ascolto: $phone. Il radar romantico è in pausa; i fari restano disponibili.';
  }

  @override
  String get askAgain =>
      'Il tuo segnale e la tua valutazione differiscono un po\'. Te lo richiederemo domani.';

  @override
  String get radarTitle => 'Radar';

  @override
  String get offRadar =>
      'Sei fuori dal radar. Invia il segnale di oggi per comparire.';

  @override
  String get radarEmpty => 'Cielo vuoto per ora. Torna più tardi.';

  @override
  String get planetMatch => 'Segnale di match';

  @override
  String get planetEncourage => 'Faro';

  @override
  String get sharedStar => 'Condividete una stella';

  @override
  String get weakSignal => 'Segnale comune debole';

  @override
  String get placesTitle => 'Le mie stelle';

  @override
  String get placesSearchHint => 'Fermata, linea, bar, campus…';

  @override
  String placesLimit(int max) {
    return 'Al massimo $max luoghi';
  }

  @override
  String get placesSaved => 'Stelle salvate';

  @override
  String get save => 'Salva';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get locationDataTitle => 'Cosa sappiamo della tua posizione';

  @override
  String get locationDataBody =>
      'Questo è tutto. Non riceviamo mai coordinate GPS.';

  @override
  String activeKeys(int count) {
    return 'Chiavi di incontro attive: $count';
  }

  @override
  String venueCheckins(int count) {
    return 'Check-in nei locali: $count';
  }

  @override
  String get noPlaces => 'Nessun luogo scelto';

  @override
  String get deleteAccount => 'Elimina account';

  @override
  String get deleteConfirmTitle => 'Eliminare tutto?';

  @override
  String get deleteConfirmBody =>
      'Foto, profilo, segnali e muri verranno eliminati subito. Non si può annullare.';

  @override
  String get cancel => 'Annulla';

  @override
  String get delete => 'Elimina';

  @override
  String get navRadar => 'Radar';

  @override
  String get navCheckin => 'Segnale';

  @override
  String get navPlaces => 'Stelle';

  @override
  String get navSettings => 'Impostazioni';

  @override
  String get genGenz => 'Gen Z';

  @override
  String get genMillennial => 'Millennial';

  @override
  String get genGenx => 'Gen X';

  @override
  String get genBoomer => 'Baby boomer';

  @override
  String get statusSingle => 'Single';

  @override
  String get statusMarried => 'Sposato/a';

  @override
  String get statusDivorced => 'Divorziato/a';

  @override
  String get statusComplicated => 'È complicato';

  @override
  String get intentFlirt => 'Flirt';

  @override
  String get intentSex => 'Sesso';

  @override
  String get intentChat => 'Chiacchiere';

  @override
  String get intentCoffee => 'Caffè';

  @override
  String get intentBeer => 'Birra';

  @override
  String get intentWine => 'Vino';

  @override
  String get intentTea => 'Tè';

  @override
  String get intentWalk => 'Passeggiata';

  @override
  String get intentPlay => 'Giocare';

  @override
  String get kidsBoys => 'Maschi';

  @override
  String get kidsGirls => 'Femmine';

  @override
  String get kidsTwins => 'Gemelli';

  @override
  String get kidsTriplets => 'Tre gemelli';

  @override
  String get navWalls => 'Muri';

  @override
  String get wave => 'Saluta';

  @override
  String get waveSent => 'Saluto inviato. Se ricambia, si apre il vostro muro.';

  @override
  String get matched => 'È reciproco! Il vostro muro è aperto.';

  @override
  String get waveLimit => 'Per oggi hai finito i saluti.';

  @override
  String get wallsEmpty => 'Ancora nessun muro. Saluta qualcuno sul radar.';

  @override
  String get youShare => 'Andate entrambi a';

  @override
  String get draw => 'Disegna uno sticker';

  @override
  String get undo => 'Annulla';

  @override
  String get stick => 'Attacca';

  @override
  String get report => 'Segnala';

  @override
  String get reportBlock => 'Segnala e blocca';

  @override
  String get peel => 'Stacca';

  @override
  String get wallEnded => 'Questo muro è terminato.';

  @override
  String get pendingSync => 'In attesa di connessione';

  @override
  String get encouragementWall => 'Muro del faro';

  @override
  String get flybyTitle => 'Incrocio';

  @override
  String get flybyBody =>
      'Il telefono rileva via Bluetooth altri telefoni con AlienMatch vicini, per esempio sullo stesso tram. Nessuna posizione. Saprai chi era solo se vi salutate entrambi.';

  @override
  String get flybyRadioOff => 'Il Bluetooth è spento o manca il permesso.';

  @override
  String get flybyVehicle => 'stessa corsa';

  @override
  String get flybyStop => 'stessa fermata';

  @override
  String get flybyVenue => 'stesso locale';

  @override
  String flybyMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get flybyComet => 'Vi siete incrociati';

  @override
  String get flybyStrip => 'Incroci';
}
