import 'package:gwent_engine/gwent_engine.dart';

/// С чем клиент возвращается в партию: её идентификатор и токен места.
///
/// Приложение хранит билет, пока партия идёт, чтобы вернуться в неё и после перезапуска.
final class ResumeTicket extends Value {
  const ResumeTicket({required this.matchId, required this.token});

  final String matchId;
  final String token;

  @override
  List<Object?> get props => [matchId, token];
}
