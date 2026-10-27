import 'package:gwent_content/gwent_content.dart';

/// Сколько всего копий карт и лидеров в пакете: знаменатель в «Открыто N из M».
int totalCardCopies(PackRules rules) =>
    rules.squadCards.fold<int>(0, (sum, card) => sum + card.count) +
    rules.specialCards.fold<int>(0, (sum, card) => sum + card.count) +
    rules.leaderCards.length;
