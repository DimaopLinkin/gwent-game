import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/tutorial/domain/hint_target.dart';
import 'package:gwent/src/features/tutorial/domain/scenario_beat.dart';
import 'package:gwent/src/features/tutorial/domain/tutorial_move.dart';
import 'package:gwent/src/features/tutorial/domain/tutorial_step.dart';
import 'package:gwent_engine/gwent_engine.dart' show Row;

/// Сценарий «Первой партии» (ADR 0034, миссия 0 кампании): Королевства Севера против Скеллиге, 15 шагов.
///
/// Сценарий состоит из данных: сид, две колоды и последовательность звеньев ([beats]). Сид подобран так, чтобы
/// раздача положила в руки игрока и бота нужные карты, а первым ходил игрок; если случайность движка изменится,
/// тест `first_match_script_test.dart` скажет, что сид надо подобрать заново (перебором сидов тем же прогоном сценария).
/// Карты и лидеры названы UUID пакета контента, как в колодах и протоколе.
abstract final class FirstMatchScript {
  /// Сид партии: раздача и порядок колод.
  static const int seed = 46664;

  /// Идентификатор колоды игрока; в хранилище её нет.
  static const String playerDeckId = 'tutorial-first-match-player';

  /// Идентификатор колоды бота; в хранилище её нет.
  static const String opponentDeckId = 'tutorial-first-match-opponent';

  /// Колода игрока: Королевства Севера, лидер «Фольтест: Завоеватель», 22 отряда и 3 особые карты.
  static final Deck playerDeck = Deck(
    id: playerDeckId,
    name: 'first-match-player',
    factionId: _northernRealms,
    leaderId: _foltestConqueror,
    cards: const {
      _vernon: 1,
      _redanianInfantry: 2,
      _keira: 1,
      _sheala: 1,
      _blueStripes: 3,
      _ballista: 2,
      _thaler: 1,
      _crinfridReavers: 3,
      _poorFuckingInfantry: 3,
      _dethmold: 1,
      _bianca: 1,
      _yarpen: 1,
      _sabrina: 1,
      _sheldon: 1,
      _frost: 1,
      _horn: 1,
      _clearWeather: 1,
    },
    updatedAt: _epoch,
  );

  /// Колода бота: Скеллиге, лидер «Крах ан Крайт», 24 отряда без особых карт.
  static final Deck opponentDeck = Deck(
    id: opponentDeckId,
    name: 'first-match-opponent',
    factionId: _skellige,
    leaderId: _crachAnCraite,
    cards: const {
      _anCraiteWarrior: 3,
      _brokvarArcher: 3,
      _youngBerserker: 3,
      _drummondWarrior: 3,
      _warLongship: 3,
      _donar: 1,
      _tordarrochSmith: 1,
      _svanrige: 1,
      _skald: 1,
      _udalryk: 1,
      _holger: 1,
      _blueLugos: 1,
      _madLugos: 1,
      _olaf: 1,
    },
    updatedAt: _epoch,
  );

  /// Счёт игрока и бота в конце второго раунда: по нему тест проверяет, что сценарий сошёлся с движком.
  static const (int, int) finalScore = (23, 5);

  /// Звенья по порядку. Игрок ходит первым в обоих раундах: первый раунд определяет раздача, во второй начинает
  /// победитель.
  static const List<Beat> beats = [
    ShowBeat(TutorialStep.goal, [GemsHint()]),
    ShowBeat(TutorialStep.handAndDeck, [HandHint(), PilesHint()]),
    ShowBeat(TutorialStep.cardPower, [HandCardHint(_redanianInfantry)]),
    PlayerBeat(
      PlayMove(_redanianInfantry, row: Row.melee, destination: RowHint(Row.melee, mine: true)),
      step: TutorialStep.firstCard,
    ),
    BotBeat(PlayMove(_anCraiteWarrior)),
    ShowBeat(TutorialStep.score, [RowScoreHint(Row.melee, mine: true), ScoreHint(mine: true), ScoreHint(mine: false)]),
    ShowBeat(TutorialStep.opponentMove, [RowHint(Row.melee, mine: false), ScoreHint(mine: false)]),
    PlayerBeat(
      PlayMove(_keira, row: Row.ranged, destination: RowHint(Row.ranged, mine: true)),
      step: TutorialStep.rows,
    ),
    BotBeat(PlayMove(_brokvarArcher)),
    PlayerBeat(
      PlayMove(_vernon, row: Row.melee, destination: RowHint(Row.melee, mine: true)),
      step: TutorialStep.hero,
    ),
    BotBeat(PlayMove(_youngBerserker)),
    ShowBeat(TutorialStep.passIntro, [PassHint(), ScoreHint(mine: true), ScoreHint(mine: false)]),
    PlayerBeat(
      PassMove(),
      step: TutorialStep.passHold,
      targets: [PassHint(), ScoreHint(mine: true), ScoreHint(mine: false)],
    ),
    BotBeat(PassMove()),
    ShowBeat(TutorialStep.roundResult, [GemsHint()]),
    PlayerBeat(PlayMove(_sheala, row: Row.ranged, destination: RowHint(Row.ranged, mine: true))),
    BotBeat(PlayMove(_drummondWarrior)),
    PlayerBeat(PlayMove(_frost, destination: StripHint()), step: TutorialStep.weather),
    BotBeat(PlayMove(_drummondWarrior)),
    PlayerBeat(
      PlayMove(_thaler, row: Row.siege, destination: RowHint(Row.siege, mine: false)),
      step: TutorialStep.spy,
    ),
    BotBeat(PassMove()),
    PlayerBeat(
      PlayMove(_horn, row: Row.ranged, destination: RowHint(Row.ranged, mine: true)),
      step: TutorialStep.horn,
    ),
    PlayerBeat(PlayMove(_blueStripes, row: Row.melee, destination: RowHint(Row.melee, mine: true))),
    PlayerBeat(PlayMove(_ballista, row: Row.siege, destination: RowHint(Row.siege, mine: true))),
    PlayerBeat(LeaderMove(), step: TutorialStep.leader, targets: [LeaderHint()]),
    PlayerBeat(
      PassMove(),
      step: TutorialStep.finalPass,
      targets: [PassHint(), ScoreHint(mine: true), ScoreHint(mine: false)],
    ),
  ];

  static final DateTime _epoch = DateTime.utc(2026, 10, 26);

  // Фракции и лидеры.
  static const String _northernRealms = '57845d37-a89d-4340-a670-5f52be61c0c7';
  static const String _skellige = '166a05e0-36f0-4e16-a250-9c3bccf64b62';
  static const String _foltestConqueror = 'd8c7de0f-b935-47b6-a32d-2cc1c63326f3';
  static const String _crachAnCraite = '485d32b3-cf8c-4732-a0eb-9ff0ebedfdfc';

  // Королевства Севера и особые карты.
  static const String _vernon = '0025d364-b039-4807-a33b-73ce5cf6c767'; // Вернон Роше
  static const String _redanianInfantry = '2c855539-3b40-4c18-9f8c-f4943a0bb1f2'; // Реданский пехотинец
  static const String _keira = 'dcdef72f-f08d-48db-8b10-795122652e14'; // Кейра Мец
  static const String _sheala = '9d1974eb-9968-4e14-a2cc-4771ef9b4ac0'; // Шеала де Тансервиль
  static const String _blueStripes = '9c77cdbb-2bc9-4485-870f-67b2fd40e0a5'; // Боец Синих Полосок
  static const String _ballista = '5b89b34c-561f-4a1d-b272-91daef135ec5'; // Баллиста
  static const String _thaler = '4a1311b2-4c5c-47b6-95c6-f5202ba77b53'; // Талер
  static const String _crinfridReavers = '282914c3-63db-4f34-8361-88548f8769e3'; // Рубайлы из Кринфрида
  static const String _poorFuckingInfantry = '98eec06b-0d09-4601-841a-fdda5e94d420'; // Гребаная пехтура
  static const String _dethmold = '5306db76-b30f-45f0-8ba6-4770a03bce40'; // Детмольд
  static const String _bianca = '8d667c98-81e0-4f72-80dd-d6202c7a0ea3'; // Бьянка
  static const String _yarpen = 'f686b43a-b4ea-4448-b2d1-08247e142f46'; // Ярпен Зигрин
  static const String _sabrina = '6d3972bb-0752-4dc7-8c63-5709d136c395'; // Сабрина Глевиссиг
  static const String _sheldon = '67e9961e-2cdf-4152-a917-de7c83cbbac6'; // Шелдон Скаггс
  static const String _frost = 'c858b281-84d5-410a-9e63-45f9e61d6825'; // Мороз
  static const String _horn = '47d44246-c663-4218-b537-b81929c5caf0'; // Командирский рог
  static const String _clearWeather = '9454833b-22f2-4989-b039-2d0eee81ff1a'; // Ясное небо

  // Скеллиге.
  static const String _anCraiteWarrior = 'ad488479-9da6-4bcc-9281-a86046bf4b8f'; // Воин клана ан Крайт
  static const String _brokvarArcher = '16ec260f-9fb7-4e5e-ad3e-9573cbd11aa4'; // Лучник клана Броквар
  static const String _youngBerserker = '837d214d-3aa8-4c07-9306-2be475816551'; // Молодой берсерк
  static const String _drummondWarrior = 'e60e46fa-ffca-469e-8167-10d9c463ad41'; // Воительница клана Друммонд
  static const String _warLongship = '594461d9-bcf3-463c-93ff-14b77ea82481'; // Военный драккар
  static const String _donar = 'e720d334-263b-4286-abe9-dcf984c40321'; // Донар ан Хиндар
  static const String _tordarrochSmith = 'c81ad6e5-8e0f-4072-b007-d0cd995f5275'; // Кузнец клана Тордаррох
  static const String _svanrige = 'f58d992a-df1f-4935-ab00-5f9f841a6f75'; // Сванриге
  static const String _skald = '0ebc93aa-2cc0-432d-92f1-74e594cfb745'; // Скальд клана Хэймэй
  static const String _udalryk = '5689b42e-cf77-45ed-a78a-78f41c08be58'; // Удальрик
  static const String _holger = 'cf7e54cb-d0c8-4106-8616-b3d7cbf512e3'; // Хольгер Чернорукий
  static const String _blueLugos = '53ce6462-074d-482d-a720-c87e0b2deac6'; // Лугос Синий
  static const String _madLugos = 'd29088db-aca1-4112-a9d0-fd9690f64260'; // Лугос Безумный
  static const String _olaf = '64f78581-914d-4793-a755-670bd63118e3'; // Олаф
}
