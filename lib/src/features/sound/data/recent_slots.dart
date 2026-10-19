import 'dart:collection';

/// Ограниченный набор значений: когда места не хватает, вытесняется то, чем дольше всего не пользовались.
///
/// Нужен выводу звука: у каждого проигрывателя на устройстве есть цена (iOS держит по `AVPlayer` на эффект), поэтому
/// «живых» проигрывателей ограниченное число, а редкие эффекты создаются заново, когда до них доходит очередь.
final class RecentSlots<K, V> {
  /// Создаёт набор не больше чем на [capacity] значений.
  RecentSlots(this.capacity) : assert(capacity > 0, 'вместимость положительна');

  /// Сколько значений набор держит одновременно.
  final int capacity;

  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  /// Сколько значений сейчас в наборе.
  int get length => _entries.length;

  /// Значение по [key]; обращение делает его самым свежим. `null`, если значения нет.
  V? use(K key) {
    final value = _entries.remove(key);
    if (value != null) _entries[key] = value;
    return value;
  }

  /// Кладёт [value] по [key] самым свежим. Если набор переполнился, возвращает вытесненную пару.
  MapEntry<K, V>? put(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    if (_entries.length <= capacity) return null;
    final oldest = _entries.entries.first;
    _entries.remove(oldest.key);
    return oldest;
  }

  /// Убирает значение по [key], если оно ещё лежит именно [value].
  void remove(K key, V value) {
    if (identical(_entries[key], value)) _entries.remove(key);
  }
}
