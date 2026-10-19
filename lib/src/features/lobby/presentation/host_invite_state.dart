/// Состояние экрана с QR-кодом партии.
sealed class HostInviteState {
  const HostInviteState();
}

/// Адрес партии узнаётся.
final class HostInviteLoading extends HostInviteState {
  /// Создаёт состояние.
  const HostInviteLoading();
}

/// QR-код готов.
final class HostInviteReady extends HostInviteState {
  /// Создаёт состояние: [invite] — строка в QR-коде, [label] — адрес для людей.
  const HostInviteReady(this.invite, this.label);

  /// Приглашение, которое кодируется в QR-код.
  final String invite;

  /// Адрес партии под кодом, например `192.168.1.5:4000`.
  final String label;
}

/// Адрес узнать не удалось.
final class HostInviteFailed extends HostInviteState {
  /// Создаёт состояние.
  const HostInviteFailed();
}

/// Показывать код больше не нужно: соперник подключился или партия кончилась.
final class HostInviteDone extends HostInviteState {
  /// Создаёт состояние.
  const HostInviteDone();
}
