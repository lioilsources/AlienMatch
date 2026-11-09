// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AlienMatch';

  @override
  String get tagline => 'Dating without words.';

  @override
  String get start => 'Land';

  @override
  String get adultConfirm => 'I am 18 or older';

  @override
  String get moodConsentTitle => 'Mood signal from face and voice';

  @override
  String get moodConsentBody =>
      'Optional. Your daily check-in is scored on our own servers in the EU; video and audio are deleted right after scoring. Without it you rate yourself only.';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get captureHint => 'Face in the oval, nose on the line';

  @override
  String get capture => 'Capture';

  @override
  String get retake => 'Again';

  @override
  String get cameraUnavailable =>
      'Camera is not available. The profile photo can only be taken live.';

  @override
  String get pickVariant => 'Which alien are you?';

  @override
  String get variantNote =>
      'Only the one you pick leaves your phone. The original never does.';

  @override
  String get generationTitle => 'Your generation';

  @override
  String get statusTitle => 'Status';

  @override
  String get kidsTitle => 'Kids (optional)';

  @override
  String get intentsTitle => 'What are you up for?';

  @override
  String get seekTitle => 'Who are you looking for?';

  @override
  String get modesTitle => 'Beacon';

  @override
  String get beaconSwitch => 'I can be a beacon for someone feeling low';

  @override
  String get encourageSwitch => 'I\'d like someone to cheer me up';

  @override
  String get beaconOnlySwitch =>
      'I\'m not looking for a relationship, I just shine';

  @override
  String get nicknameTitle => 'Nickname';

  @override
  String get nicknameHint => 'up to 12 characters';

  @override
  String get finish => 'Done';

  @override
  String get errorGeneric => 'Something went wrong. Try again.';

  @override
  String get retry => 'Try again';

  @override
  String get checkinTitle => 'How are you today?';

  @override
  String get checkinSend => 'Send signal';

  @override
  String get checkinDone => 'Signal received. See you tomorrow.';

  @override
  String get checkinSelfOnly =>
      'For now only your own rating is sent. Face and voice signal is coming.';

  @override
  String get supportTitle => 'A few heavy days?';

  @override
  String supportBody(String phone) {
    return 'You don\'t have to be alone with it. Crisis line: $phone. Romantic matching is paused for now; beacons stay available.';
  }

  @override
  String get askAgain =>
      'Your signal and your rating differ a bit. We\'ll ask again tomorrow.';

  @override
  String get radarTitle => 'Radar';

  @override
  String get offRadar =>
      'You are off the radar. Send today\'s signal to appear.';

  @override
  String get radarEmpty => 'Empty sky for now. Come back later.';

  @override
  String get planetMatch => 'Match signal';

  @override
  String get planetEncourage => 'Beacon';

  @override
  String get sharedStar => 'You share a star';

  @override
  String get weakSignal => 'Weak shared signal';

  @override
  String get placesTitle => 'My stars';

  @override
  String get placesSearchHint => 'Stop, line, café, campus…';

  @override
  String placesLimit(int max) {
    return 'At most $max places';
  }

  @override
  String get placesSaved => 'Stars saved';

  @override
  String get save => 'Save';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get locationDataTitle => 'What we know about your location';

  @override
  String get locationDataBody =>
      'This is everything. We never receive GPS coordinates.';

  @override
  String activeKeys(int count) {
    return 'Active encounter keys: $count';
  }

  @override
  String venueCheckins(int count) {
    return 'Venue check-ins: $count';
  }

  @override
  String get noPlaces => 'No places chosen';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteConfirmTitle => 'Delete everything?';

  @override
  String get deleteConfirmBody =>
      'Your photo, profile, signals and walls will be deleted right away. This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get navRadar => 'Radar';

  @override
  String get navCheckin => 'Signal';

  @override
  String get navPlaces => 'Stars';

  @override
  String get navSettings => 'Settings';

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
  String get statusMarried => 'Married';

  @override
  String get statusDivorced => 'Divorced';

  @override
  String get statusComplicated => 'It\'s complicated';

  @override
  String get intentFlirt => 'Flirt';

  @override
  String get intentSex => 'Sex';

  @override
  String get intentChat => 'Chat';

  @override
  String get intentCoffee => 'Coffee';

  @override
  String get intentBeer => 'Beer';

  @override
  String get intentWine => 'Wine';

  @override
  String get intentTea => 'Tea';

  @override
  String get intentWalk => 'Walk';

  @override
  String get intentPlay => 'Play';

  @override
  String get kidsBoys => 'Boys';

  @override
  String get kidsGirls => 'Girls';

  @override
  String get kidsTwins => 'Twins';

  @override
  String get kidsTriplets => 'Triplets';

  @override
  String get navWalls => 'Walls';

  @override
  String get wave => 'Wave';

  @override
  String get waveSent => 'Waved. If they wave back, a wall opens for you two.';

  @override
  String get matched => 'It\'s mutual! Your wall is open.';

  @override
  String get waveLimit => 'That\'s all your waves for today.';

  @override
  String get wallsEmpty => 'No walls yet. Wave at someone on the radar.';

  @override
  String get youShare => 'You both go to';

  @override
  String get draw => 'Draw a sticker';

  @override
  String get undo => 'Undo';

  @override
  String get stick => 'Stick it';

  @override
  String get report => 'Report';

  @override
  String get reportBlock => 'Report and block';

  @override
  String get peel => 'Peel off';

  @override
  String get wallEnded => 'This wall has ended.';

  @override
  String get pendingSync => 'Waiting for connection';

  @override
  String get encouragementWall => 'Beacon wall';

  @override
  String get flybyTitle => 'Fly-by';

  @override
  String get flybyBody =>
      'Your phone notices other AlienMatch phones nearby over Bluetooth, for example on the same tram. No location is used. You only learn who it was if you both wave.';

  @override
  String get flybyRadioOff => 'Bluetooth is off or permission is missing.';

  @override
  String get flybyVehicle => 'same ride';

  @override
  String get flybyStop => 'same stop';

  @override
  String get flybyVenue => 'same place';

  @override
  String flybyMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get flybyComet => 'You met';

  @override
  String get flybyStrip => 'Fly-bys';

  @override
  String get checkinVideo => 'Video + voice';

  @override
  String get checkinVoice => 'Voice only';

  @override
  String get checkinNoRecording => 'Just my rating';

  @override
  String get checkinPrompt1 => 'Say how you feel today.';

  @override
  String get checkinPrompt2 => 'What\'s ahead of you today?';

  @override
  String get checkinRateNow => 'Now rate it yourself:';

  @override
  String get checkinSignalUsed =>
      'Signal from face and voice counted. Your rating still weighs more.';

  @override
  String get checkinMediaNote =>
      'The recording is deleted right after scoring.';

  @override
  String get checkinNoPermission =>
      'Camera or microphone permission is missing.';

  @override
  String get checkinSignalPending =>
      'The face and voice signal is being prepared; it will be added in a few minutes.';
}
