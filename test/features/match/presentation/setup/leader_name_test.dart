import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/card/leader_name.dart';

void main() {
  test('имя лидера делится по двоеточию на персонажа и прозвище', () {
    expect(splitLeaderName('Фольтест: Король Темерии'), ('Фольтест', 'Король Темерии'));
    expect(splitLeaderName('Эредин'), ('Эредин', null));
    expect(splitLeaderName(': без персонажа'), (': без персонажа', null));
  });

  test('короткое имя для строки списка обрезает прозвище до первой запятой', () {
    expect(
      shortLeaderName('Эмгыр вар Эмрейс: Белое Пламя, Пляшущее на Курганах Врагов'),
      'Эмгыр вар Эмрейс, Белое Пламя',
    );
    expect(shortLeaderName('Фольтест: Король Темерии'), 'Фольтест, Король Темерии');
    expect(shortLeaderName('Эредин'), 'Эредин');
  });
}
