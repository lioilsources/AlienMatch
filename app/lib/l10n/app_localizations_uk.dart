// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'AlienMatch';

  @override
  String get tagline => 'Знайомства без слів.';

  @override
  String get start => 'Приземлитися';

  @override
  String get adultConfirm => 'Мені 18 або більше';

  @override
  String get moodConsentTitle => 'Сигнал настрою з обличчя та голосу';

  @override
  String get moodConsentBody =>
      'Необов\'язково. Щоденний check-in оцінюють наші власні сервери в ЄС; відео й звук видаляються одразу після оцінки. Без згоди ти оцінюєш себе сам.';

  @override
  String get privacyPolicy => 'Політика конфіденційності';

  @override
  String get next => 'Далі';

  @override
  String get back => 'Назад';

  @override
  String get captureHint => 'Обличчя в овал, ніс на лінію';

  @override
  String get capture => 'Зняти';

  @override
  String get retake => 'Ще раз';

  @override
  String get cameraUnavailable =>
      'Камера недоступна. Фото профілю можна зробити лише наживо.';

  @override
  String get pickVariant => 'Який ти прибулець?';

  @override
  String get variantNote =>
      'Телефон залишає лише той, кого ти обереш. Оригінал — ніколи.';

  @override
  String get generationTitle => 'Твоє покоління';

  @override
  String get statusTitle => 'Статус';

  @override
  String get kidsTitle => 'Діти (необов\'язково)';

  @override
  String get intentsTitle => 'Чого тобі хочеться?';

  @override
  String get seekTitle => 'Кого ти шукаєш?';

  @override
  String get modesTitle => 'Маяк';

  @override
  String get beaconSwitch => 'Я можу бути маяком для когось, кому погано';

  @override
  String get encourageSwitch => 'Хочу, щоб мене хтось підбадьорив';

  @override
  String get beaconOnlySwitch => 'Не шукаю стосунків, просто свічу';

  @override
  String get nicknameTitle => 'Псевдонім';

  @override
  String get nicknameHint => 'до 12 символів';

  @override
  String get finish => 'Готово';

  @override
  String get errorGeneric => 'Щось пішло не так. Спробуй ще раз.';

  @override
  String get retry => 'Спробувати ще';

  @override
  String get checkinTitle => 'Як ти сьогодні?';

  @override
  String get checkinSend => 'Надіслати сигнал';

  @override
  String get checkinDone => 'Сигнал отримано. До завтра.';

  @override
  String get checkinSelfOnly =>
      'Поки що надсилається лише твоя власна оцінка. Сигнал з обличчя та голосу готується.';

  @override
  String get supportTitle => 'Кілька важких днів?';

  @override
  String supportBody(String phone) {
    return 'Ти не мусиш бути з цим сам. Лінія підтримки: $phone. Романтичний радар призупинено, маяки лишаються доступні.';
  }

  @override
  String get askAgain =>
      'Твій сигнал і оцінка трохи різняться. Завтра запитаємо знову.';

  @override
  String get radarTitle => 'Радар';

  @override
  String get offRadar =>
      'Ти поза радаром. Надішли сьогоднішній сигнал, щоб з\'явитися.';

  @override
  String get radarEmpty => 'Поки що небо порожнє. Повертайся пізніше.';

  @override
  String get planetMatch => 'Сигнал на метч';

  @override
  String get planetEncourage => 'Маяк';

  @override
  String get sharedStar => 'Ви поділяєте зірку';

  @override
  String get weakSignal => 'Слабкий спільний сигнал';

  @override
  String get placesTitle => 'Мої зірки';

  @override
  String get placesSearchHint => 'Зупинка, лінія, кав\'ярня, кампус…';

  @override
  String placesLimit(int max) {
    return 'Не більше $max місць';
  }

  @override
  String get placesSaved => 'Зірки збережено';

  @override
  String get save => 'Зберегти';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get locationDataTitle => 'Що ми знаємо про твоє місцезнаходження';

  @override
  String get locationDataBody =>
      'Це все. Ми ніколи не отримуємо GPS-координат.';

  @override
  String activeKeys(int count) {
    return 'Активні ключі зустрічей: $count';
  }

  @override
  String venueCheckins(int count) {
    return 'Check-in у закладах: $count';
  }

  @override
  String get noPlaces => 'Місця не вибрано';

  @override
  String get deleteAccount => 'Видалити акаунт';

  @override
  String get deleteConfirmTitle => 'Видалити все?';

  @override
  String get deleteConfirmBody =>
      'Фото, профіль, сигнали та стіни буде видалено одразу. Це не можна скасувати.';

  @override
  String get cancel => 'Скасувати';

  @override
  String get delete => 'Видалити';

  @override
  String get navRadar => 'Радар';

  @override
  String get navCheckin => 'Сигнал';

  @override
  String get navPlaces => 'Зірки';

  @override
  String get navSettings => 'Налаштування';

  @override
  String get genGenz => 'Покоління Z';

  @override
  String get genMillennial => 'Мілленіал';

  @override
  String get genGenx => 'Покоління X';

  @override
  String get genBoomer => 'Бебі-бумер';

  @override
  String get statusSingle => 'Неодружений/а';

  @override
  String get statusMarried => 'Одружений/а';

  @override
  String get statusDivorced => 'Розлучений/а';

  @override
  String get statusComplicated => 'Усе складно';

  @override
  String get intentFlirt => 'Флірт';

  @override
  String get intentSex => 'Секс';

  @override
  String get intentChat => 'Балачки';

  @override
  String get intentCoffee => 'Кава';

  @override
  String get intentBeer => 'Пиво';

  @override
  String get intentWine => 'Вино';

  @override
  String get intentTea => 'Чай';

  @override
  String get intentWalk => 'Прогулянка';

  @override
  String get intentPlay => 'Ігри';

  @override
  String get kidsBoys => 'Хлопчики';

  @override
  String get kidsGirls => 'Дівчатка';

  @override
  String get kidsTwins => 'Близнюки';

  @override
  String get kidsTriplets => 'Трійнята';

  @override
  String get navWalls => 'Стіни';

  @override
  String get wave => 'Помахати';

  @override
  String get waveSent =>
      'Помахано. Якщо помахає у відповідь, відкриється ваша стіна.';

  @override
  String get matched => 'Це взаємно! Ваша стіна відкрита.';

  @override
  String get waveLimit => 'На сьогодні помахи закінчилися.';

  @override
  String get wallsEmpty => 'Ще немає стін. Помахай комусь на радарі.';

  @override
  String get youShare => 'Ви обоє ходите до';

  @override
  String get draw => 'Намалювати стікер';

  @override
  String get undo => 'Скасувати';

  @override
  String get stick => 'Наліпити';

  @override
  String get report => 'Поскаржитися';

  @override
  String get reportBlock => 'Поскаржитися й заблокувати';

  @override
  String get peel => 'Відліпити';

  @override
  String get wallEnded => 'Ця стіна завершилася.';

  @override
  String get pendingSync => 'Очікує з\'єднання';

  @override
  String get encouragementWall => 'Стіна маяка';
}
