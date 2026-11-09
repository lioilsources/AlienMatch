// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'AlienMatch';

  @override
  String get tagline => 'Dating ohne Worte.';

  @override
  String get start => 'Landen';

  @override
  String get adultConfirm => 'Ich bin 18 oder älter';

  @override
  String get moodConsentTitle => 'Stimmungssignal aus Gesicht und Stimme';

  @override
  String get moodConsentBody =>
      'Optional. Dein täglicher Check-in wird auf unseren eigenen Servern in der EU ausgewertet; Video und Ton werden direkt danach gelöscht. Ohne Zustimmung bewertest du dich nur selbst.';

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get next => 'Weiter';

  @override
  String get back => 'Zurück';

  @override
  String get captureHint => 'Gesicht ins Oval, Nase auf die Linie';

  @override
  String get capture => 'Aufnehmen';

  @override
  String get retake => 'Nochmal';

  @override
  String get cameraUnavailable =>
      'Die Kamera ist nicht verfügbar. Das Profilfoto kann nur live aufgenommen werden.';

  @override
  String get pickVariant => 'Welcher Alien bist du?';

  @override
  String get variantNote =>
      'Nur der gewählte verlässt dein Handy. Das Original nie.';

  @override
  String get generationTitle => 'Deine Generation';

  @override
  String get statusTitle => 'Status';

  @override
  String get kidsTitle => 'Kinder (optional)';

  @override
  String get intentsTitle => 'Worauf hast du Lust?';

  @override
  String get seekTitle => 'Wen suchst du?';

  @override
  String get modesTitle => 'Leuchtturm';

  @override
  String get beaconSwitch =>
      'Ich kann ein Leuchtturm für jemanden sein, dem es nicht gut geht';

  @override
  String get encourageSwitch => 'Ich möchte, dass mich jemand aufmuntert';

  @override
  String get beaconOnlySwitch => 'Ich suche keine Beziehung, ich leuchte nur';

  @override
  String get nicknameTitle => 'Spitzname';

  @override
  String get nicknameHint => 'bis zu 12 Zeichen';

  @override
  String get finish => 'Fertig';

  @override
  String get errorGeneric => 'Etwas ist schiefgelaufen. Versuch es nochmal.';

  @override
  String get retry => 'Nochmal versuchen';

  @override
  String get checkinTitle => 'Wie geht es dir heute?';

  @override
  String get checkinSend => 'Signal senden';

  @override
  String get checkinDone => 'Signal empfangen. Bis morgen.';

  @override
  String get checkinSelfOnly =>
      'Vorerst wird nur deine eigene Bewertung gesendet. Das Signal aus Gesicht und Stimme kommt bald.';

  @override
  String get supportTitle => 'Ein paar schwere Tage?';

  @override
  String supportBody(String phone) {
    return 'Du musst damit nicht allein sein. Krisentelefon: $phone. Romantisches Matching ist pausiert, Leuchttürme bleiben verfügbar.';
  }

  @override
  String get askAgain =>
      'Dein Signal und deine Bewertung weichen etwas ab. Wir fragen morgen nochmal.';

  @override
  String get radarTitle => 'Radar';

  @override
  String get offRadar =>
      'Du bist nicht auf dem Radar. Sende das heutige Signal, um zu erscheinen.';

  @override
  String get radarEmpty => 'Noch leerer Himmel. Schau später wieder vorbei.';

  @override
  String get planetMatch => 'Match-Signal';

  @override
  String get planetEncourage => 'Leuchtturm';

  @override
  String get sharedStar => 'Ihr teilt einen Stern';

  @override
  String get weakSignal => 'Schwaches gemeinsames Signal';

  @override
  String get placesTitle => 'Meine Sterne';

  @override
  String get placesSearchHint => 'Haltestelle, Linie, Café, Campus…';

  @override
  String placesLimit(int max) {
    return 'Höchstens $max Orte';
  }

  @override
  String get placesSaved => 'Sterne gespeichert';

  @override
  String get save => 'Speichern';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get locationDataTitle => 'Was wir über deinen Standort wissen';

  @override
  String get locationDataBody =>
      'Das ist alles. GPS-Koordinaten erhalten wir nie.';

  @override
  String activeKeys(int count) {
    return 'Aktive Begegnungsschlüssel: $count';
  }

  @override
  String venueCheckins(int count) {
    return 'Check-ins in Lokalen: $count';
  }

  @override
  String get noPlaces => 'Keine Orte gewählt';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteConfirmTitle => 'Alles löschen?';

  @override
  String get deleteConfirmBody =>
      'Foto, Profil, Signale und Wände werden sofort gelöscht. Das kann nicht rückgängig gemacht werden.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get navRadar => 'Radar';

  @override
  String get navCheckin => 'Signal';

  @override
  String get navPlaces => 'Sterne';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get genGenz => 'Gen Z';

  @override
  String get genMillennial => 'Millennial';

  @override
  String get genGenx => 'Gen X';

  @override
  String get genBoomer => 'Babyboomer';

  @override
  String get statusSingle => 'Single';

  @override
  String get statusMarried => 'Verheiratet';

  @override
  String get statusDivorced => 'Geschieden';

  @override
  String get statusComplicated => 'Es ist kompliziert';

  @override
  String get intentFlirt => 'Flirt';

  @override
  String get intentSex => 'Sex';

  @override
  String get intentChat => 'Plaudern';

  @override
  String get intentCoffee => 'Kaffee';

  @override
  String get intentBeer => 'Bier';

  @override
  String get intentWine => 'Wein';

  @override
  String get intentTea => 'Tee';

  @override
  String get intentWalk => 'Spaziergang';

  @override
  String get intentPlay => 'Spielen';

  @override
  String get kidsBoys => 'Jungen';

  @override
  String get kidsGirls => 'Mädchen';

  @override
  String get kidsTwins => 'Zwillinge';

  @override
  String get kidsTriplets => 'Drillinge';

  @override
  String get navWalls => 'Wände';

  @override
  String get wave => 'Winken';

  @override
  String get waveSent =>
      'Gewinkt. Winkt die Person zurück, öffnet sich eure Wand.';

  @override
  String get matched => 'Es ist gegenseitig! Eure Wand ist offen.';

  @override
  String get waveLimit => 'Für heute hast du alle Winker verbraucht.';

  @override
  String get wallsEmpty => 'Noch keine Wände. Winke jemandem auf dem Radar.';

  @override
  String get youShare => 'Ihr geht beide zu';

  @override
  String get draw => 'Sticker zeichnen';

  @override
  String get undo => 'Rückgängig';

  @override
  String get stick => 'Aufkleben';

  @override
  String get report => 'Melden';

  @override
  String get reportBlock => 'Melden und blockieren';

  @override
  String get peel => 'Abziehen';

  @override
  String get wallEnded => 'Diese Wand ist beendet.';

  @override
  String get pendingSync => 'Warte auf Verbindung';

  @override
  String get encouragementWall => 'Leuchtturm-Wand';

  @override
  String get flybyTitle => 'Vorbeiflug';

  @override
  String get flybyBody =>
      'Dein Handy erkennt andere AlienMatch-Handys in der Nähe per Bluetooth, etwa in derselben Tram. Kein Standort. Wer es war, erfährst du nur, wenn ihr beide winkt.';

  @override
  String get flybyRadioOff => 'Bluetooth ist aus oder die Berechtigung fehlt.';

  @override
  String get flybyVehicle => 'dieselbe Fahrt';

  @override
  String get flybyStop => 'dieselbe Haltestelle';

  @override
  String get flybyVenue => 'derselbe Ort';

  @override
  String flybyMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String get flybyComet => 'Ihr habt euch getroffen';

  @override
  String get flybyStrip => 'Vorbeiflüge';
}
