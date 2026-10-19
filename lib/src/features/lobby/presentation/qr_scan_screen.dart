import 'package:flutter/widgets.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/game_invite.dart';
import 'package:gwent/src/features/lobby/presentation/camera_qr_scanner.dart';
import 'package:gwent/src/features/lobby/presentation/network_notice.dart';

/// Окно с камерой, читающее QR-коды: [onCode] получает строку каждого кода, [onUnavailable] — сигнал, что камера
/// недоступна. В тестах вместо камеры подставляют заглушку.
typedef QrScannerBuilder =
    Widget Function(BuildContext context, {required ValueChanged<String> onCode, required VoidCallback onUnavailable});

/// Камера по умолчанию.
Widget cameraQrScanner(
  BuildContext context, {
  required ValueChanged<String> onCode,
  required VoidCallback onUnavailable,
}) => CameraQrScanner(onCode: onCode, onUnavailable: onUnavailable);

/// Сканер QR-кода партии (макет 9, экран 3c): гость наводит камеру на экран хоста.
///
/// Чужой QR-код экран отвергает сообщением и продолжает искать. Найденный адрес отдаётся один раз в [onInvite].
class QrScanScreen extends StatefulWidget {
  /// Создаёт экран. [scannerBuilder] заменяет камеру в тестах.
  const QrScanScreen({
    super.key,
    required this.onInvite,
    required this.onOpenSettings,
    required this.onBack,
    this.scannerBuilder = cameraQrScanner,
  });

  /// Считано приглашение в партию.
  final ValueChanged<GameAddress> onInvite;

  /// Открывает системные настройки приложения, когда камеру не разрешили.
  final VoidCallback onOpenSettings;

  /// Игрок вернулся назад.
  final VoidCallback onBack;

  /// Строит окно камеры.
  final QrScannerBuilder scannerBuilder;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _handled = false;
  bool _foreign = false;
  bool _unavailable = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _scan
        ..stop()
        ..value = 0.5;
    } else if (!_scan.isAnimating) {
      _scan.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  void _onCode(String code) {
    if (_handled) return;
    final address = GameInvite.decode(code);
    if (address == null) {
      if (!_foreign) setState(() => _foreign = true);
      return;
    }
    _handled = true;
    widget.onInvite(address);
  }

  void _onUnavailable() {
    if (!_unavailable && mounted) setState(() => _unavailable = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: Column(
        children: [
          ScreenHeader(title: l10n.netScanTitle, titleSize: 32, onBack: widget.onBack),
          Expanded(
            child: _unavailable
                ? NetworkNotice(
                    title: l10n.netScanDeniedTitle,
                    text: l10n.netScanDeniedText,
                    icon: GwentIcon.iconLock,
                    actions: [
                      (
                        label: l10n.netProblemSettings,
                        style: GwentButtonStyle.primary,
                        onPressed: widget.onOpenSettings,
                      ),
                      (label: l10n.netNoticeBack, style: GwentButtonStyle.secondary, onPressed: widget.onBack),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Semantics(
                        label: l10n.netScanViewfinder,
                        child: widget.scannerBuilder(context, onCode: _onCode, onUnavailable: _onUnavailable),
                      ),
                      _Viewfinder(scan: _scan),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 40,
                        child: _Caption(
                          title: l10n.netScanAim,
                          text: _foreign ? l10n.netScanForeign : l10n.netScanHint,
                          warning: _foreign,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Золотая рамка с бегущей линией посреди камеры.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.scan});

  final Animation<double> scan;

  static const double _side = 260;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      alignment: const Alignment(0, -0.35),
      child: SizedBox.square(
        dimension: _side,
        child: AnimatedBuilder(
          animation: scan,
          builder: (context, _) => CustomPaint(painter: _FramePainter(scan.value)),
        ),
      ),
    ),
  );
}

class _FramePainter extends CustomPainter {
  const _FramePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const corner = 40.0;
    final paint = Paint()
      ..color = GwentColors.goldHighlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    for (final (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (w, 0.0, -1.0, 1.0), (0.0, h, 1.0, -1.0), (w, h, -1.0, -1.0)]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * corner)
          ..lineTo(x, y)
          ..lineTo(x + dx * corner, y),
        paint,
      );
    }
    final lineY = 10 + (h - 20) * progress;
    canvas.drawLine(
      Offset(10, lineY),
      Offset(w - 10, lineY),
      Paint()
        ..strokeWidth = 2
        ..shader = const LinearGradient(
          colors: [Color(0x00E6C67E), GwentColors.goldHighlight, Color(0x00E6C67E)],
        ).createShader(Rect.fromLTWH(10, 0, w - 20, 1)),
    );
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => oldDelegate.progress != progress;
}

class _Caption extends StatelessWidget {
  const _Caption({required this.title, required this.text, required this.warning});

  final String title;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) => Center(
    child: DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xCC0E0B09), borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontFamily: GwentText.cormorant,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  height: 1.1,
                  color: GwentColors.textPrimary,
                ),
              ),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: GwentText.alegreya,
                  fontSize: 14.5,
                  height: 1.4,
                  color: warning ? GwentColors.errorText : GwentColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
