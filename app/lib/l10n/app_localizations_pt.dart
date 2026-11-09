// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'AlienMatch';

  @override
  String get tagline => 'Encontros sem palavras.';

  @override
  String get start => 'Aterrar';

  @override
  String get adultConfirm => 'Tenho 18 anos ou mais';

  @override
  String get moodConsentTitle => 'Sinal de humor do rosto e da voz';

  @override
  String get moodConsentBody =>
      'Opcional. O teu check-in diário é avaliado nos nossos próprios servidores na UE; vídeo e áudio são apagados logo a seguir. Sem consentimento avalias-te só tu.';

  @override
  String get privacyPolicy => 'Política de privacidade';

  @override
  String get next => 'Seguinte';

  @override
  String get back => 'Voltar';

  @override
  String get captureHint => 'Rosto no oval, nariz na linha';

  @override
  String get capture => 'Capturar';

  @override
  String get retake => 'De novo';

  @override
  String get cameraUnavailable =>
      'A câmara não está disponível. A foto de perfil só pode ser tirada ao vivo.';

  @override
  String get pickVariant => 'Que alien és tu?';

  @override
  String get variantNote =>
      'Só o que escolheres sai do telemóvel. O original nunca.';

  @override
  String get generationTitle => 'A tua geração';

  @override
  String get statusTitle => 'Estado';

  @override
  String get kidsTitle => 'Filhos (opcional)';

  @override
  String get intentsTitle => 'O que te apetece?';

  @override
  String get seekTitle => 'Quem procuras?';

  @override
  String get modesTitle => 'Farol';

  @override
  String get beaconSwitch => 'Posso ser um farol para quem está em baixo';

  @override
  String get encourageSwitch => 'Quero que alguém me anime';

  @override
  String get beaconOnlySwitch => 'Não procuro relação, só brilho';

  @override
  String get nicknameTitle => 'Alcunha';

  @override
  String get nicknameHint => 'até 12 caracteres';

  @override
  String get finish => 'Concluído';

  @override
  String get errorGeneric => 'Algo correu mal. Tenta de novo.';

  @override
  String get retry => 'Tentar de novo';

  @override
  String get checkinTitle => 'Como estás hoje?';

  @override
  String get checkinSend => 'Enviar sinal';

  @override
  String get checkinDone => 'Sinal recebido. Até amanhã.';

  @override
  String get checkinSelfOnly =>
      'Por agora só é enviada a tua própria avaliação. O sinal do rosto e da voz vem a caminho.';

  @override
  String get supportTitle => 'Uns dias pesados?';

  @override
  String supportBody(String phone) {
    return 'Não tens de estar sozinho com isto. Linha de apoio: $phone. O radar romântico está em pausa; os faróis continuam disponíveis.';
  }

  @override
  String get askAgain =>
      'O teu sinal e a tua avaliação diferem um pouco. Voltamos a perguntar amanhã.';

  @override
  String get radarTitle => 'Radar';

  @override
  String get offRadar =>
      'Estás fora do radar. Envia o sinal de hoje para apareceres.';

  @override
  String get radarEmpty => 'Céu vazio por agora. Volta mais tarde.';

  @override
  String get planetMatch => 'Sinal de match';

  @override
  String get planetEncourage => 'Farol';

  @override
  String get sharedStar => 'Partilham uma estrela';

  @override
  String get weakSignal => 'Sinal comum fraco';

  @override
  String get placesTitle => 'As minhas estrelas';

  @override
  String get placesSearchHint => 'Paragem, linha, café, campus…';

  @override
  String placesLimit(int max) {
    return 'No máximo $max lugares';
  }

  @override
  String get placesSaved => 'Estrelas guardadas';

  @override
  String get save => 'Guardar';

  @override
  String get settingsTitle => 'Definições';

  @override
  String get locationDataTitle => 'O que sabemos da tua localização';

  @override
  String get locationDataBody => 'É tudo. Nunca recebemos coordenadas GPS.';

  @override
  String activeKeys(int count) {
    return 'Chaves de encontro ativas: $count';
  }

  @override
  String venueCheckins(int count) {
    return 'Check-ins em locais: $count';
  }

  @override
  String get noPlaces => 'Nenhum lugar escolhido';

  @override
  String get deleteAccount => 'Eliminar conta';

  @override
  String get deleteConfirmTitle => 'Apagar tudo?';

  @override
  String get deleteConfirmBody =>
      'Foto, perfil, sinais e murais serão apagados de imediato. Não é possível anular.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get navRadar => 'Radar';

  @override
  String get navCheckin => 'Sinal';

  @override
  String get navPlaces => 'Estrelas';

  @override
  String get navSettings => 'Definições';

  @override
  String get genGenz => 'Gen Z';

  @override
  String get genMillennial => 'Millennial';

  @override
  String get genGenx => 'Gen X';

  @override
  String get genBoomer => 'Baby boomer';

  @override
  String get statusSingle => 'Solteiro/a';

  @override
  String get statusMarried => 'Casado/a';

  @override
  String get statusDivorced => 'Divorciado/a';

  @override
  String get statusComplicated => 'É complicado';

  @override
  String get intentFlirt => 'Flirt';

  @override
  String get intentSex => 'Sexo';

  @override
  String get intentChat => 'Conversa';

  @override
  String get intentCoffee => 'Café';

  @override
  String get intentBeer => 'Cerveja';

  @override
  String get intentWine => 'Vinho';

  @override
  String get intentTea => 'Chá';

  @override
  String get intentWalk => 'Passeio';

  @override
  String get intentPlay => 'Jogar';

  @override
  String get kidsBoys => 'Rapazes';

  @override
  String get kidsGirls => 'Raparigas';

  @override
  String get kidsTwins => 'Gémeos';

  @override
  String get kidsTriplets => 'Trigémeos';
}
