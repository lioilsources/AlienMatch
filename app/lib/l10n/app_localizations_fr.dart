// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'AlienMatch';

  @override
  String get tagline => 'Rencontres sans mots.';

  @override
  String get start => 'Atterrir';

  @override
  String get adultConfirm => 'J\'ai 18 ans ou plus';

  @override
  String get moodConsentTitle => 'Signal d\'humeur du visage et de la voix';

  @override
  String get moodConsentBody =>
      'Facultatif. Ton check-in quotidien est évalué sur nos propres serveurs dans l\'UE ; la vidéo et le son sont supprimés juste après. Sans consentement, tu t\'évalues seul.';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get next => 'Suivant';

  @override
  String get back => 'Retour';

  @override
  String get captureHint => 'Visage dans l\'ovale, nez sur la ligne';

  @override
  String get capture => 'Capturer';

  @override
  String get retake => 'Encore';

  @override
  String get cameraUnavailable =>
      'La caméra n\'est pas disponible. La photo de profil ne peut être prise qu\'en direct.';

  @override
  String get pickVariant => 'Quel alien es-tu ?';

  @override
  String get variantNote =>
      'Seul celui que tu choisis quitte ton téléphone. Jamais l\'original.';

  @override
  String get generationTitle => 'Ta génération';

  @override
  String get statusTitle => 'Statut';

  @override
  String get kidsTitle => 'Enfants (facultatif)';

  @override
  String get intentsTitle => 'De quoi as-tu envie ?';

  @override
  String get seekTitle => 'Qui cherches-tu ?';

  @override
  String get modesTitle => 'Phare';

  @override
  String get beaconSwitch => 'Je peux être un phare pour quelqu\'un qui va mal';

  @override
  String get encourageSwitch =>
      'J\'aimerais que quelqu\'un me remonte le moral';

  @override
  String get beaconOnlySwitch =>
      'Je ne cherche pas de relation, je brille juste';

  @override
  String get nicknameTitle => 'Pseudo';

  @override
  String get nicknameHint => 'jusqu\'à 12 caractères';

  @override
  String get finish => 'Terminé';

  @override
  String get errorGeneric => 'Un problème est survenu. Réessaie.';

  @override
  String get retry => 'Réessayer';

  @override
  String get checkinTitle => 'Comment vas-tu aujourd\'hui ?';

  @override
  String get checkinSend => 'Envoyer le signal';

  @override
  String get checkinDone => 'Signal reçu. À demain.';

  @override
  String get checkinSelfOnly =>
      'Pour l\'instant, seule ta propre évaluation est envoyée. Le signal du visage et de la voix arrive.';

  @override
  String get supportTitle => 'Quelques jours difficiles ?';

  @override
  String supportBody(String phone) {
    return 'Tu n\'as pas à rester seul avec ça. Ligne d\'écoute : $phone. Le radar romantique est en pause ; les phares restent disponibles.';
  }

  @override
  String get askAgain =>
      'Ton signal et ton évaluation diffèrent un peu. Nous redemanderons demain.';

  @override
  String get radarTitle => 'Radar';

  @override
  String get offRadar =>
      'Tu es hors radar. Envoie le signal du jour pour apparaître.';

  @override
  String get radarEmpty => 'Ciel vide pour l\'instant. Reviens plus tard.';

  @override
  String get planetMatch => 'Signal de match';

  @override
  String get planetEncourage => 'Phare';

  @override
  String get sharedStar => 'Vous partagez une étoile';

  @override
  String get weakSignal => 'Signal commun faible';

  @override
  String get placesTitle => 'Mes étoiles';

  @override
  String get placesSearchHint => 'Arrêt, ligne, café, campus…';

  @override
  String placesLimit(int max) {
    return 'Au plus $max lieux';
  }

  @override
  String get placesSaved => 'Étoiles enregistrées';

  @override
  String get save => 'Enregistrer';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get locationDataTitle => 'Ce que nous savons de ta position';

  @override
  String get locationDataBody =>
      'C\'est tout. Nous ne recevons jamais de coordonnées GPS.';

  @override
  String activeKeys(int count) {
    return 'Clés de rencontre actives : $count';
  }

  @override
  String venueCheckins(int count) {
    return 'Check-ins dans des lieux : $count';
  }

  @override
  String get noPlaces => 'Aucun lieu choisi';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteConfirmTitle => 'Tout supprimer ?';

  @override
  String get deleteConfirmBody =>
      'Ta photo, ton profil, tes signaux et tes murs seront supprimés immédiatement. C\'est irréversible.';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get navRadar => 'Radar';

  @override
  String get navCheckin => 'Signal';

  @override
  String get navPlaces => 'Étoiles';

  @override
  String get navSettings => 'Réglages';

  @override
  String get genGenz => 'Gen Z';

  @override
  String get genMillennial => 'Millennial';

  @override
  String get genGenx => 'Gen X';

  @override
  String get genBoomer => 'Baby-boomer';

  @override
  String get statusSingle => 'Célibataire';

  @override
  String get statusMarried => 'Marié·e';

  @override
  String get statusDivorced => 'Divorcé·e';

  @override
  String get statusComplicated => 'C\'est compliqué';

  @override
  String get intentFlirt => 'Flirt';

  @override
  String get intentSex => 'Sexe';

  @override
  String get intentChat => 'Discuter';

  @override
  String get intentCoffee => 'Café';

  @override
  String get intentBeer => 'Bière';

  @override
  String get intentWine => 'Vin';

  @override
  String get intentTea => 'Thé';

  @override
  String get intentWalk => 'Balade';

  @override
  String get intentPlay => 'Jouer';

  @override
  String get kidsBoys => 'Garçons';

  @override
  String get kidsGirls => 'Filles';

  @override
  String get kidsTwins => 'Jumeaux';

  @override
  String get kidsTriplets => 'Triplés';

  @override
  String get navWalls => 'Murs';

  @override
  String get wave => 'Faire coucou';

  @override
  String get waveSent => 'Coucou envoyé. S\'il te répond, votre mur s\'ouvre.';

  @override
  String get matched => 'C\'est réciproque ! Votre mur est ouvert.';

  @override
  String get waveLimit => 'Tu as utilisé tous tes coucous du jour.';

  @override
  String get wallsEmpty =>
      'Pas encore de murs. Fais coucou à quelqu\'un sur le radar.';

  @override
  String get youShare => 'Vous allez tous les deux à';

  @override
  String get draw => 'Dessiner un sticker';

  @override
  String get undo => 'Annuler';

  @override
  String get stick => 'Coller';

  @override
  String get report => 'Signaler';

  @override
  String get reportBlock => 'Signaler et bloquer';

  @override
  String get peel => 'Décoller';

  @override
  String get wallEnded => 'Ce mur est terminé.';

  @override
  String get pendingSync => 'En attente de connexion';

  @override
  String get encouragementWall => 'Mur du phare';

  @override
  String get flybyTitle => 'Croisement';

  @override
  String get flybyBody =>
      'Ton téléphone repère par Bluetooth les autres téléphones AlienMatch à proximité, par exemple dans le même tram. Aucune position. Tu ne sauras qui c\'était que si vous faites coucou tous les deux.';

  @override
  String get flybyRadioOff =>
      'Le Bluetooth est désactivé ou l\'autorisation manque.';

  @override
  String get flybyVehicle => 'même trajet';

  @override
  String get flybyStop => 'même arrêt';

  @override
  String get flybyVenue => 'même lieu';

  @override
  String flybyMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get flybyComet => 'Vous vous êtes croisés';

  @override
  String get flybyStrip => 'Croisements';

  @override
  String get checkinVideo => 'Vidéo + voix';

  @override
  String get checkinVoice => 'Voix seulement';

  @override
  String get checkinNoRecording => 'Juste mon évaluation';

  @override
  String get checkinPrompt1 => 'Dis comment tu vas aujourd\'hui.';

  @override
  String get checkinPrompt2 => 'Qu\'est-ce qui t\'attend aujourd\'hui ?';

  @override
  String get checkinRateNow => 'Maintenant, évalue toi-même :';

  @override
  String get checkinSignalUsed =>
      'Signal du visage et de la voix pris en compte. Ton évaluation compte toujours plus.';

  @override
  String get checkinMediaNote =>
      'L\'enregistrement est supprimé juste après l\'évaluation.';

  @override
  String get checkinNoPermission => 'Autorisation caméra ou micro manquante.';

  @override
  String get checkinSignalPending =>
      'Le signal du visage et de la voix est en préparation ; il sera ajouté dans quelques minutes.';
}
