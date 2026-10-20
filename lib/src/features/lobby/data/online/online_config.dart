import 'package:meta/meta.dart';

/// Куда обращается игра через интернет: адрес проекта Supabase и его publishable-ключ (ADR 0025).
///
/// Оба значения публичны по замыслу Supabase: ключ есть в каждой собранной копии приложения, а защиту держат RLS,
/// проверки функций и авторизация канала. Секретный ключ и пароль базы сюда не попадают никогда.
@immutable
final class OnlineConfig {
  /// Создаёт настройки.
  const OnlineConfig({required this.url, required this.publishableKey});

  /// Проект `Gwent Mobile` (ADR 0025).
  static const OnlineConfig gwentMobile = OnlineConfig(
    url: 'https://dduuljprudykffghxytl.supabase.co',
    publishableKey: 'sb_publishable_fgcHoHr2vAgug2WT04IBcA_EU1BqLg_',
  );

  /// Адрес проекта.
  final String url;

  /// Publishable-ключ проекта.
  final String publishableKey;
}
