// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'AlienMatch';

  @override
  String get tagline => 'Citas sin palabras.';

  @override
  String get start => 'Aterrizar';

  @override
  String get adultConfirm => 'Tengo 18 años o más';

  @override
  String get moodConsentTitle => 'Señal de ánimo de la cara y la voz';

  @override
  String get moodConsentBody =>
      'Opcional. Tu check-in diario se evalúa en nuestros propios servidores en la UE; el vídeo y el audio se borran justo después. Sin consentimiento solo te valoras tú.';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get next => 'Siguiente';

  @override
  String get back => 'Atrás';

  @override
  String get captureHint => 'Cara en el óvalo, nariz en la línea';

  @override
  String get capture => 'Capturar';

  @override
  String get retake => 'Otra vez';

  @override
  String get cameraUnavailable =>
      'La cámara no está disponible. La foto de perfil solo se puede hacer en vivo.';

  @override
  String get pickVariant => '¿Qué alien eres tú?';

  @override
  String get variantNote =>
      'Solo el que elijas sale de tu móvil. El original nunca.';

  @override
  String get generationTitle => 'Tu generación';

  @override
  String get statusTitle => 'Estado';

  @override
  String get kidsTitle => 'Hijos (opcional)';

  @override
  String get intentsTitle => '¿Qué te apetece?';

  @override
  String get seekTitle => '¿A quién buscas?';

  @override
  String get modesTitle => 'Faro';

  @override
  String get beaconSwitch => 'Puedo ser un faro para alguien que está bajo';

  @override
  String get encourageSwitch => 'Quiero que alguien me anime';

  @override
  String get beaconOnlySwitch => 'No busco pareja, solo brillo';

  @override
  String get nicknameTitle => 'Apodo';

  @override
  String get nicknameHint => 'hasta 12 caracteres';

  @override
  String get finish => 'Listo';

  @override
  String get errorGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get retry => 'Reintentar';

  @override
  String get checkinTitle => '¿Cómo estás hoy?';

  @override
  String get checkinSend => 'Enviar señal';

  @override
  String get checkinDone => 'Señal recibida. Hasta mañana.';

  @override
  String get checkinSelfOnly =>
      'Por ahora solo se envía tu propia valoración. La señal de cara y voz llegará pronto.';

  @override
  String get supportTitle => '¿Unos días difíciles?';

  @override
  String supportBody(String phone) {
    return 'No tienes que estar solo con esto. Línea de ayuda: $phone. El radar romántico está en pausa; los faros siguen disponibles.';
  }

  @override
  String get askAgain =>
      'Tu señal y tu valoración difieren un poco. Preguntaremos de nuevo mañana.';

  @override
  String get radarTitle => 'Radar';

  @override
  String get offRadar =>
      'Estás fuera del radar. Envía la señal de hoy para aparecer.';

  @override
  String get radarEmpty => 'Cielo vacío por ahora. Vuelve más tarde.';

  @override
  String get planetMatch => 'Señal de match';

  @override
  String get planetEncourage => 'Faro';

  @override
  String get sharedStar => 'Compartís una estrella';

  @override
  String get weakSignal => 'Señal compartida débil';

  @override
  String get placesTitle => 'Mis estrellas';

  @override
  String get placesSearchHint => 'Parada, línea, café, campus…';

  @override
  String placesLimit(int max) {
    return 'Como máximo $max lugares';
  }

  @override
  String get placesSaved => 'Estrellas guardadas';

  @override
  String get save => 'Guardar';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get locationDataTitle => 'Lo que sabemos de tu ubicación';

  @override
  String get locationDataBody =>
      'Esto es todo. Nunca recibimos coordenadas GPS.';

  @override
  String activeKeys(int count) {
    return 'Claves de encuentro activas: $count';
  }

  @override
  String venueCheckins(int count) {
    return 'Check-ins en locales: $count';
  }

  @override
  String get noPlaces => 'Ningún lugar elegido';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteConfirmTitle => '¿Borrarlo todo?';

  @override
  String get deleteConfirmBody =>
      'Tu foto, perfil, señales y muros se borrarán al instante. No se puede deshacer.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get navRadar => 'Radar';

  @override
  String get navCheckin => 'Señal';

  @override
  String get navPlaces => 'Estrellas';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get genGenz => 'Gen Z';

  @override
  String get genMillennial => 'Millennial';

  @override
  String get genGenx => 'Gen X';

  @override
  String get genBoomer => 'Baby boomer';

  @override
  String get statusSingle => 'Soltero/a';

  @override
  String get statusMarried => 'Casado/a';

  @override
  String get statusDivorced => 'Divorciado/a';

  @override
  String get statusComplicated => 'Es complicado';

  @override
  String get intentFlirt => 'Flirteo';

  @override
  String get intentSex => 'Sexo';

  @override
  String get intentChat => 'Charla';

  @override
  String get intentCoffee => 'Café';

  @override
  String get intentBeer => 'Cerveza';

  @override
  String get intentWine => 'Vino';

  @override
  String get intentTea => 'Té';

  @override
  String get intentWalk => 'Paseo';

  @override
  String get intentPlay => 'Jugar';

  @override
  String get kidsBoys => 'Niños';

  @override
  String get kidsGirls => 'Niñas';

  @override
  String get kidsTwins => 'Gemelos';

  @override
  String get kidsTriplets => 'Trillizos';

  @override
  String get navWalls => 'Muros';

  @override
  String get wave => 'Saludar';

  @override
  String get waveSent =>
      'Saludo enviado. Si te devuelve el saludo, se abre vuestro muro.';

  @override
  String get matched => '¡Es mutuo! Vuestro muro está abierto.';

  @override
  String get waveLimit => 'Ya no te quedan saludos por hoy.';

  @override
  String get wallsEmpty => 'Aún no hay muros. Saluda a alguien del radar.';

  @override
  String get youShare => 'Los dos vais a';

  @override
  String get draw => 'Dibujar sticker';

  @override
  String get undo => 'Deshacer';

  @override
  String get stick => 'Pegar';

  @override
  String get report => 'Denunciar';

  @override
  String get reportBlock => 'Denunciar y bloquear';

  @override
  String get peel => 'Despegar';

  @override
  String get wallEnded => 'Este muro ha terminado.';

  @override
  String get pendingSync => 'Esperando conexión';

  @override
  String get encouragementWall => 'Muro del faro';
}
