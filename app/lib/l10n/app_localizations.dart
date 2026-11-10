import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_sk.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pl'),
    Locale('pt'),
    Locale('sk'),
    Locale('uk'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AlienMatch'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Dating without words.'**
  String get tagline;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Land'**
  String get start;

  /// No description provided for @adultConfirm.
  ///
  /// In en, this message translates to:
  /// **'I am 18 or older'**
  String get adultConfirm;

  /// No description provided for @moodConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Mood signal from face and voice'**
  String get moodConsentTitle;

  /// No description provided for @moodConsentBody.
  ///
  /// In en, this message translates to:
  /// **'Optional. Your daily check-in is scored on our own servers in the EU; video and audio are deleted right after scoring. Without it you rate yourself only.'**
  String get moodConsentBody;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @captureHint.
  ///
  /// In en, this message translates to:
  /// **'Inner ring turns the mirror, outer ring turns the picture'**
  String get captureHint;

  /// No description provided for @capture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get capture;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get retake;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera is not available. The profile photo can only be taken live.'**
  String get cameraUnavailable;

  /// No description provided for @pickVariant.
  ///
  /// In en, this message translates to:
  /// **'Which alien are you?'**
  String get pickVariant;

  /// No description provided for @variantNote.
  ///
  /// In en, this message translates to:
  /// **'Only the one you pick leaves your phone. The original never does.'**
  String get variantNote;

  /// No description provided for @generationTitle.
  ///
  /// In en, this message translates to:
  /// **'Your generation'**
  String get generationTitle;

  /// No description provided for @statusTitle.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusTitle;

  /// No description provided for @kidsTitle.
  ///
  /// In en, this message translates to:
  /// **'Kids (optional)'**
  String get kidsTitle;

  /// No description provided for @intentsTitle.
  ///
  /// In en, this message translates to:
  /// **'What are you up for?'**
  String get intentsTitle;

  /// No description provided for @seekTitle.
  ///
  /// In en, this message translates to:
  /// **'Who are you looking for?'**
  String get seekTitle;

  /// No description provided for @modesTitle.
  ///
  /// In en, this message translates to:
  /// **'Beacon'**
  String get modesTitle;

  /// No description provided for @beaconSwitch.
  ///
  /// In en, this message translates to:
  /// **'I can be a beacon for someone feeling low'**
  String get beaconSwitch;

  /// No description provided for @encourageSwitch.
  ///
  /// In en, this message translates to:
  /// **'I\'d like someone to cheer me up'**
  String get encourageSwitch;

  /// No description provided for @beaconOnlySwitch.
  ///
  /// In en, this message translates to:
  /// **'I\'m not looking for a relationship, I just shine'**
  String get beaconOnlySwitch;

  /// No description provided for @nicknameTitle.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nicknameTitle;

  /// No description provided for @nicknameHint.
  ///
  /// In en, this message translates to:
  /// **'up to 12 characters'**
  String get nicknameHint;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get finish;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorGeneric;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @checkinTitle.
  ///
  /// In en, this message translates to:
  /// **'How are you today?'**
  String get checkinTitle;

  /// No description provided for @checkinSend.
  ///
  /// In en, this message translates to:
  /// **'Send signal'**
  String get checkinSend;

  /// No description provided for @checkinDone.
  ///
  /// In en, this message translates to:
  /// **'Signal received. See you tomorrow.'**
  String get checkinDone;

  /// No description provided for @checkinSelfOnly.
  ///
  /// In en, this message translates to:
  /// **'For now only your own rating is sent. Face and voice signal is coming.'**
  String get checkinSelfOnly;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'A few heavy days?'**
  String get supportTitle;

  /// No description provided for @supportBody.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have to be alone with it. Crisis line: {phone}. Romantic matching is paused for now; beacons stay available.'**
  String supportBody(String phone);

  /// No description provided for @askAgain.
  ///
  /// In en, this message translates to:
  /// **'Your signal and your rating differ a bit. We\'ll ask again tomorrow.'**
  String get askAgain;

  /// No description provided for @radarTitle.
  ///
  /// In en, this message translates to:
  /// **'Radar'**
  String get radarTitle;

  /// No description provided for @offRadar.
  ///
  /// In en, this message translates to:
  /// **'You are off the radar. Send today\'s signal to appear.'**
  String get offRadar;

  /// No description provided for @radarEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty sky for now. Come back later.'**
  String get radarEmpty;

  /// No description provided for @planetMatch.
  ///
  /// In en, this message translates to:
  /// **'Match signal'**
  String get planetMatch;

  /// No description provided for @planetEncourage.
  ///
  /// In en, this message translates to:
  /// **'Beacon'**
  String get planetEncourage;

  /// No description provided for @sharedStar.
  ///
  /// In en, this message translates to:
  /// **'You share a star'**
  String get sharedStar;

  /// No description provided for @weakSignal.
  ///
  /// In en, this message translates to:
  /// **'Weak shared signal'**
  String get weakSignal;

  /// No description provided for @placesTitle.
  ///
  /// In en, this message translates to:
  /// **'My stars'**
  String get placesTitle;

  /// No description provided for @placesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Stop, line, café, campus…'**
  String get placesSearchHint;

  /// No description provided for @placesLimit.
  ///
  /// In en, this message translates to:
  /// **'At most {max} places'**
  String placesLimit(int max);

  /// No description provided for @placesSaved.
  ///
  /// In en, this message translates to:
  /// **'Stars saved'**
  String get placesSaved;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @locationDataTitle.
  ///
  /// In en, this message translates to:
  /// **'What we know about your location'**
  String get locationDataTitle;

  /// No description provided for @locationDataBody.
  ///
  /// In en, this message translates to:
  /// **'This is everything. We never receive GPS coordinates.'**
  String get locationDataBody;

  /// No description provided for @activeKeys.
  ///
  /// In en, this message translates to:
  /// **'Active encounter keys: {count}'**
  String activeKeys(int count);

  /// No description provided for @venueCheckins.
  ///
  /// In en, this message translates to:
  /// **'Venue check-ins: {count}'**
  String venueCheckins(int count);

  /// No description provided for @noPlaces.
  ///
  /// In en, this message translates to:
  /// **'No places chosen'**
  String get noPlaces;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete everything?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your photo, profile, signals and walls will be deleted right away. This cannot be undone.'**
  String get deleteConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @navRadar.
  ///
  /// In en, this message translates to:
  /// **'Radar'**
  String get navRadar;

  /// No description provided for @navCheckin.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get navCheckin;

  /// No description provided for @navPlaces.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get navPlaces;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @genGenz.
  ///
  /// In en, this message translates to:
  /// **'Gen Z'**
  String get genGenz;

  /// No description provided for @genMillennial.
  ///
  /// In en, this message translates to:
  /// **'Millennial'**
  String get genMillennial;

  /// No description provided for @genGenx.
  ///
  /// In en, this message translates to:
  /// **'Gen X'**
  String get genGenx;

  /// No description provided for @genBoomer.
  ///
  /// In en, this message translates to:
  /// **'Baby boomer'**
  String get genBoomer;

  /// No description provided for @statusSingle.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get statusSingle;

  /// No description provided for @statusMarried.
  ///
  /// In en, this message translates to:
  /// **'Married'**
  String get statusMarried;

  /// No description provided for @statusDivorced.
  ///
  /// In en, this message translates to:
  /// **'Divorced'**
  String get statusDivorced;

  /// No description provided for @statusComplicated.
  ///
  /// In en, this message translates to:
  /// **'It\'s complicated'**
  String get statusComplicated;

  /// No description provided for @intentFlirt.
  ///
  /// In en, this message translates to:
  /// **'Flirt'**
  String get intentFlirt;

  /// No description provided for @intentSex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get intentSex;

  /// No description provided for @intentChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get intentChat;

  /// No description provided for @intentCoffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get intentCoffee;

  /// No description provided for @intentBeer.
  ///
  /// In en, this message translates to:
  /// **'Beer'**
  String get intentBeer;

  /// No description provided for @intentWine.
  ///
  /// In en, this message translates to:
  /// **'Wine'**
  String get intentWine;

  /// No description provided for @intentTea.
  ///
  /// In en, this message translates to:
  /// **'Tea'**
  String get intentTea;

  /// No description provided for @intentWalk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get intentWalk;

  /// No description provided for @intentPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get intentPlay;

  /// No description provided for @kidsBoys.
  ///
  /// In en, this message translates to:
  /// **'Boys'**
  String get kidsBoys;

  /// No description provided for @kidsGirls.
  ///
  /// In en, this message translates to:
  /// **'Girls'**
  String get kidsGirls;

  /// No description provided for @kidsTwins.
  ///
  /// In en, this message translates to:
  /// **'Twins'**
  String get kidsTwins;

  /// No description provided for @kidsTriplets.
  ///
  /// In en, this message translates to:
  /// **'Triplets'**
  String get kidsTriplets;

  /// No description provided for @navWalls.
  ///
  /// In en, this message translates to:
  /// **'Walls'**
  String get navWalls;

  /// No description provided for @wave.
  ///
  /// In en, this message translates to:
  /// **'Wave'**
  String get wave;

  /// No description provided for @waveSent.
  ///
  /// In en, this message translates to:
  /// **'Waved. If they wave back, a wall opens for you two.'**
  String get waveSent;

  /// No description provided for @matched.
  ///
  /// In en, this message translates to:
  /// **'It\'s mutual! Your wall is open.'**
  String get matched;

  /// No description provided for @waveLimit.
  ///
  /// In en, this message translates to:
  /// **'That\'s all your waves for today.'**
  String get waveLimit;

  /// No description provided for @wallsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No walls yet. Wave at someone on the radar.'**
  String get wallsEmpty;

  /// No description provided for @youShare.
  ///
  /// In en, this message translates to:
  /// **'You both go to'**
  String get youShare;

  /// No description provided for @draw.
  ///
  /// In en, this message translates to:
  /// **'Draw a sticker'**
  String get draw;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @stick.
  ///
  /// In en, this message translates to:
  /// **'Stick it'**
  String get stick;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @reportBlock.
  ///
  /// In en, this message translates to:
  /// **'Report and block'**
  String get reportBlock;

  /// No description provided for @peel.
  ///
  /// In en, this message translates to:
  /// **'Peel off'**
  String get peel;

  /// No description provided for @wallEnded.
  ///
  /// In en, this message translates to:
  /// **'This wall has ended.'**
  String get wallEnded;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'Waiting for connection'**
  String get pendingSync;

  /// No description provided for @encouragementWall.
  ///
  /// In en, this message translates to:
  /// **'Beacon wall'**
  String get encouragementWall;

  /// No description provided for @flybyTitle.
  ///
  /// In en, this message translates to:
  /// **'Fly-by'**
  String get flybyTitle;

  /// No description provided for @flybyBody.
  ///
  /// In en, this message translates to:
  /// **'Your phone notices other AlienMatch phones nearby over Bluetooth, for example on the same tram. No location is used. You only learn who it was if you both wave.'**
  String get flybyBody;

  /// No description provided for @flybyRadioOff.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is off or permission is missing.'**
  String get flybyRadioOff;

  /// No description provided for @flybyVehicle.
  ///
  /// In en, this message translates to:
  /// **'same ride'**
  String get flybyVehicle;

  /// No description provided for @flybyStop.
  ///
  /// In en, this message translates to:
  /// **'same stop'**
  String get flybyStop;

  /// No description provided for @flybyVenue.
  ///
  /// In en, this message translates to:
  /// **'same place'**
  String get flybyVenue;

  /// No description provided for @flybyMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String flybyMinutes(int minutes);

  /// No description provided for @flybyComet.
  ///
  /// In en, this message translates to:
  /// **'You met'**
  String get flybyComet;

  /// No description provided for @flybyStrip.
  ///
  /// In en, this message translates to:
  /// **'Fly-bys'**
  String get flybyStrip;

  /// No description provided for @checkinVideo.
  ///
  /// In en, this message translates to:
  /// **'Video + voice'**
  String get checkinVideo;

  /// No description provided for @checkinVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice only'**
  String get checkinVoice;

  /// No description provided for @checkinNoRecording.
  ///
  /// In en, this message translates to:
  /// **'Just my rating'**
  String get checkinNoRecording;

  /// No description provided for @checkinPrompt1.
  ///
  /// In en, this message translates to:
  /// **'Say how you feel today.'**
  String get checkinPrompt1;

  /// No description provided for @checkinPrompt2.
  ///
  /// In en, this message translates to:
  /// **'What\'s ahead of you today?'**
  String get checkinPrompt2;

  /// No description provided for @checkinRateNow.
  ///
  /// In en, this message translates to:
  /// **'Now rate it yourself:'**
  String get checkinRateNow;

  /// No description provided for @checkinSignalUsed.
  ///
  /// In en, this message translates to:
  /// **'Signal from face and voice counted. Your rating still weighs more.'**
  String get checkinSignalUsed;

  /// No description provided for @checkinMediaNote.
  ///
  /// In en, this message translates to:
  /// **'The recording is deleted right after scoring.'**
  String get checkinMediaNote;

  /// No description provided for @checkinNoPermission.
  ///
  /// In en, this message translates to:
  /// **'Camera or microphone permission is missing.'**
  String get checkinNoPermission;

  /// No description provided for @checkinSignalPending.
  ///
  /// In en, this message translates to:
  /// **'The face and voice signal is being prepared; it will be added in a few minutes.'**
  String get checkinSignalPending;

  /// No description provided for @usePhoto.
  ///
  /// In en, this message translates to:
  /// **'This is me'**
  String get usePhoto;

  /// No description provided for @switchSide.
  ///
  /// In en, this message translates to:
  /// **'Other half'**
  String get switchSide;

  /// No description provided for @switchCamera.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get switchCamera;

  /// No description provided for @filterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter {name}'**
  String filterLabel(String name);

  /// No description provided for @filterNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get filterNone;

  /// No description provided for @filterGlow.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get filterGlow;

  /// No description provided for @filterSlim.
  ///
  /// In en, this message translates to:
  /// **'Slim'**
  String get filterSlim;

  /// No description provided for @filterDoll.
  ///
  /// In en, this message translates to:
  /// **'Doll'**
  String get filterDoll;

  /// No description provided for @filterChibi.
  ///
  /// In en, this message translates to:
  /// **'Chibi'**
  String get filterChibi;

  /// No description provided for @filterLips.
  ///
  /// In en, this message translates to:
  /// **'Lips'**
  String get filterLips;

  /// No description provided for @filterBigNose.
  ///
  /// In en, this message translates to:
  /// **'Nose'**
  String get filterBigNose;

  /// No description provided for @filterAlien.
  ///
  /// In en, this message translates to:
  /// **'Alien'**
  String get filterAlien;

  /// No description provided for @filterMelt.
  ///
  /// In en, this message translates to:
  /// **'Melt'**
  String get filterMelt;

  /// No description provided for @filterBigEars.
  ///
  /// In en, this message translates to:
  /// **'Ears'**
  String get filterBigEars;

  /// No description provided for @filterLongNeck.
  ///
  /// In en, this message translates to:
  /// **'Neck'**
  String get filterLongNeck;

  /// No description provided for @filterPencil.
  ///
  /// In en, this message translates to:
  /// **'Pencil'**
  String get filterPencil;

  /// No description provided for @filterComic.
  ///
  /// In en, this message translates to:
  /// **'Comic'**
  String get filterComic;

  /// No description provided for @filterGlitch.
  ///
  /// In en, this message translates to:
  /// **'Glitch'**
  String get filterGlitch;

  /// No description provided for @filterNeon.
  ///
  /// In en, this message translates to:
  /// **'Neon'**
  String get filterNeon;

  /// No description provided for @filterThermal.
  ///
  /// In en, this message translates to:
  /// **'Heat'**
  String get filterThermal;

  /// No description provided for @filterOil.
  ///
  /// In en, this message translates to:
  /// **'Oil'**
  String get filterOil;

  /// No description provided for @filterCrt.
  ///
  /// In en, this message translates to:
  /// **'CRT'**
  String get filterCrt;

  /// No description provided for @filterPopArt.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get filterPopArt;

  /// No description provided for @filterVampire.
  ///
  /// In en, this message translates to:
  /// **'Vamp'**
  String get filterVampire;

  /// No description provided for @filterZombie.
  ///
  /// In en, this message translates to:
  /// **'Zombie'**
  String get filterZombie;

  /// No description provided for @filterGhost.
  ///
  /// In en, this message translates to:
  /// **'Ghost'**
  String get filterGhost;

  /// No description provided for @filterDemon.
  ///
  /// In en, this message translates to:
  /// **'Demon'**
  String get filterDemon;

  /// No description provided for @filterCyborg.
  ///
  /// In en, this message translates to:
  /// **'Cyborg'**
  String get filterCyborg;

  /// No description provided for @filterFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frost'**
  String get filterFrozen;

  /// No description provided for @collectionPretty.
  ///
  /// In en, this message translates to:
  /// **'Pretty'**
  String get collectionPretty;

  /// No description provided for @collectionUgly.
  ///
  /// In en, this message translates to:
  /// **'Ugly'**
  String get collectionUgly;

  /// No description provided for @collectionArt.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get collectionArt;

  /// No description provided for @collectionFantasy.
  ///
  /// In en, this message translates to:
  /// **'Fantasy'**
  String get collectionFantasy;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'cs',
    'de',
    'en',
    'es',
    'fr',
    'it',
    'pl',
    'pt',
    'sk',
    'uk',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'sk':
      return AppLocalizationsSk();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
