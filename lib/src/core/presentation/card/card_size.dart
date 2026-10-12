/// Размер карты (макет карты, «Варианты × размеры»).
///
/// Размеры не масштабируются линейно: медальон силы и кегль заданы на каждый размер, чтобы на ряду 52×74
/// число оставалось 14 pt. Таблица чисел — [CardMetrics].
enum CardSize {
  /// 309×444: полный просмотр, 1:1 с артом.
  full(CardMetrics.full),

  /// 103×148: сетка конструктора колоды.
  grid(CardMetrics.grid),

  /// 77×111: рука.
  hand(CardMetrics.hand),

  /// 52×74: ряд на поле.
  row(CardMetrics.row),

  /// 31×44: мини-карта (лидер, колода, сброс, слот рога).
  mini(CardMetrics.mini)
  ;

  const CardSize(this.metrics);

  /// Размеры элементов карты.
  final CardMetrics metrics;

  /// Есть ли пергаментная плашка с названием.
  bool get hasPlaque => this == full || this == grid || this == hand;

  /// Можно ли переносить название на вторую строку. На руке и меньше остаётся многоточие.
  bool get wrapsName => this == full || this == grid;

  /// Рисуется ли колонка медальонов слева сверху. На мини-карте эффект и герб стоят по центру.
  bool get hasColumn => this != mini;
}

/// Размеры элементов карты в pt (макет карты, «Спецификация» и компонент `gwentCard`).
final class CardMetrics {
  const CardMetrics._({
    required this.width,
    required this.height,
    required this.radius,
    required this.innerRadius,
    required this.frameWidth,
    required this.stateOffset,
    required this.disc,
    required this.powerFontSize,
    required this.columnInset,
    required this.columnGap,
    required this.discPadding,
    required this.arrowGap,
    required this.arrow,
    required this.coin,
    required this.coinIcon,
    required this.effect,
    required this.effectIcon,
    required this.crest,
    required this.plaqueHeight,
    required this.stripe,
    required this.plaquePaddingX,
    required this.nameFontSize,
    required this.nameUsesTitleFont,
    required this.ornament,
    required this.ornamentInset,
    required this.glow,
    required this.shadowY,
    required this.shadowBlur,
    required this.lift,
    required this.ribbon,
    required this.leaderMarker,
    required this.leaderMarkerInset,
    required this.leaderLabelFontSize,
    required this.stitchInset,
    required this.rings,
  });

  /// Полный просмотр.
  static const CardMetrics full = CardMetrics._(
    width: 309,
    height: 444,
    radius: 10,
    innerRadius: 7,
    frameWidth: 3,
    stateOffset: 4,
    disc: 64,
    powerFontSize: 34,
    columnInset: 14,
    columnGap: 10,
    discPadding: 12,
    arrowGap: 3,
    arrow: 16,
    coin: 40,
    coinIcon: 24,
    effect: 76,
    effectIcon: 44,
    crest: 84,
    plaqueHeight: 76,
    stripe: 4,
    plaquePaddingX: 16,
    nameFontSize: 26,
    nameUsesTitleFont: true,
    ornament: 10,
    ornamentInset: 10,
    glow: 28,
    shadowY: 8,
    shadowBlur: 22,
    lift: 0,
    ribbon: 30,
    leaderMarker: 16,
    leaderMarkerInset: 16,
    leaderLabelFontSize: 13,
    stitchInset: 10,
    rings: (2, 4.5, 6),
  );

  /// Сетка конструктора.
  static const CardMetrics grid = CardMetrics._(
    width: 103,
    height: 148,
    radius: 5,
    innerRadius: 3.5,
    frameWidth: 1.5,
    stateOffset: 3,
    disc: 30,
    powerFontSize: 17,
    columnInset: 5,
    columnGap: 4,
    discPadding: 5,
    arrowGap: 1,
    arrow: 9,
    coin: 19,
    coinIcon: 12,
    effect: 38,
    effectIcon: 22,
    crest: 40,
    plaqueHeight: 24,
    stripe: 2,
    plaquePaddingX: 5,
    nameFontSize: 11.5,
    nameUsesTitleFont: false,
    ornament: 5,
    ornamentInset: 5,
    glow: 12,
    shadowY: 3,
    shadowBlur: 8,
    lift: 8,
    ribbon: 14,
    leaderMarker: 9,
    leaderMarkerInset: 7,
    leaderLabelFontSize: 9,
    stitchInset: 5,
    rings: (1.5, 3, 4),
  );

  /// Рука.
  static const CardMetrics hand = CardMetrics._(
    width: 77,
    height: 111,
    radius: 4,
    innerRadius: 2.5,
    frameWidth: 1.5,
    stateOffset: 3,
    disc: 26,
    powerFontSize: 15,
    columnInset: 4,
    columnGap: 3,
    discPadding: 4,
    arrowGap: 1,
    arrow: 8,
    coin: 17,
    coinIcon: 11,
    effect: 30,
    effectIcon: 18,
    crest: 32,
    plaqueHeight: 20,
    stripe: 2,
    plaquePaddingX: 4,
    nameFontSize: 11,
    nameUsesTitleFont: false,
    ornament: 4,
    ornamentInset: 4,
    glow: 10,
    shadowY: 3,
    shadowBlur: 8,
    lift: 10,
    ribbon: 12,
    leaderMarker: 8,
    leaderMarkerInset: 6,
    leaderLabelFontSize: 8,
    stitchInset: 4,
    rings: (1.5, 3, 4),
  );

  /// Ряд на поле.
  static const CardMetrics row = CardMetrics._(
    width: 52,
    height: 74,
    radius: 3,
    innerRadius: 2,
    frameWidth: 1,
    stateOffset: 2,
    disc: 22,
    powerFontSize: 14,
    columnInset: 2.5,
    columnGap: 2.5,
    discPadding: 3,
    arrowGap: 1,
    arrow: 7,
    coin: 15,
    coinIcon: 10,
    effect: 24,
    effectIcon: 14,
    crest: 26,
    plaqueHeight: 0,
    stripe: 2.5,
    plaquePaddingX: 0,
    nameFontSize: 0,
    nameUsesTitleFont: false,
    ornament: 3,
    ornamentInset: 3,
    glow: 8,
    shadowY: 2,
    shadowBlur: 5,
    lift: 6,
    ribbon: 10,
    leaderMarker: 7,
    leaderMarkerInset: 4,
    leaderLabelFontSize: 0,
    stitchInset: 3,
    rings: (1, 2, 3),
  );

  /// Мини-карта.
  static const CardMetrics mini = CardMetrics._(
    width: 31,
    height: 44,
    radius: 2,
    innerRadius: 1.5,
    frameWidth: 1,
    stateOffset: 2,
    disc: 0,
    powerFontSize: 0,
    columnInset: 2,
    columnGap: 2,
    discPadding: 0,
    arrowGap: 0,
    arrow: 0,
    coin: 0,
    coinIcon: 0,
    effect: 20,
    effectIcon: 12,
    crest: 24,
    plaqueHeight: 0,
    stripe: 2,
    plaquePaddingX: 0,
    nameFontSize: 0,
    nameUsesTitleFont: false,
    ornament: 2,
    ornamentInset: 2,
    glow: 6,
    shadowY: 1,
    shadowBlur: 3,
    lift: 4,
    ribbon: 0,
    leaderMarker: 6,
    leaderMarkerInset: 2,
    leaderLabelFontSize: 0,
    stitchInset: 2,
    rings: (1, 2, 3),
  );

  /// Ширина карты.
  final double width;

  /// Высота карты.
  final double height;

  /// Радиус углов карты.
  final double radius;

  /// Радиус внутренних углов (плашка, прострочка рубашки).
  final double innerRadius;

  /// Толщина рамки; у героя и лидера в 1,5 раза толще.
  final double frameWidth;

  /// Отступ пунктира шпиона от карты.
  final double stateOffset;

  /// Диаметр медальона силы.
  final double disc;

  /// Кегль силы.
  final double powerFontSize;

  /// Отступ колонки медальонов от края карты.
  final double columnInset;

  /// Промежуток между медальонами в колонке.
  final double columnGap;

  /// Боковой отступ числа внутри медальона силы.
  final double discPadding;

  /// Промежуток между стрелкой ▲▼ и числом.
  final double arrowGap;

  /// Размер стрелки ▲▼.
  final double arrow;

  /// Диаметр монеты ряда и способности.
  final double coin;

  /// Размер иконки на монете.
  final double coinIcon;

  /// Диаметр медальона эффекта особой карты и погоды.
  final double effect;

  /// Размер иконки на медальоне эффекта.
  final double effectIcon;

  /// Размер герба (лидер, рубашка).
  final double crest;

  /// Высота пергаментной плашки; 0 — плашки нет.
  final double plaqueHeight;

  /// Толщина полосы цвета фракции.
  final double stripe;

  /// Боковой отступ названия на плашке.
  final double plaquePaddingX;

  /// Кегль названия.
  final double nameFontSize;

  /// Название набрано Cormorant SC (полный просмотр), иначе Alegreya Bold: на малых размерах она читаемее.
  final bool nameUsesTitleFont;

  /// Сторона ромба героя в углу.
  final double ornament;

  /// Отступ ромба героя от края.
  final double ornamentInset;

  /// Радиус свечения (герой, погода, выбор).
  final double glow;

  /// Сдвиг тени карты вниз.
  final double shadowY;

  /// Размытие тени карты.
  final double shadowBlur;

  /// Подъём выбранной карты.
  final double lift;

  /// Ширина ленты шпиона; 0 — ленты нет.
  final double ribbon;

  /// Сторона ромба-метки лидера.
  final double leaderMarker;

  /// Отступ метки лидера от края.
  final double leaderMarkerInset;

  /// Кегль подписи «Доступна» у метки лидера; 0 — подписи нет.
  final double leaderLabelFontSize;

  /// Отступ прострочки рубашки от края.
  final double stitchInset;

  /// Три кольца вокруг медальонов: латунь, тёмный зазор, внешнее кольцо героя.
  final (double, double, double) rings;
}
