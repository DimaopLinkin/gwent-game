import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/components/game_loader.dart';
import 'package:gwent/src/core/presentation/components/gwent_button.dart';
import 'package:gwent/src/core/presentation/components/screen_backdrop.dart';
import 'package:gwent/src/core/presentation/components/screen_header.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';
import 'package:gwent/src/features/lobby/presentation/host_invite_cubit.dart';
import 'package:gwent/src/features/lobby/presentation/host_invite_state.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR-код партии для гостя (макет 9, экран 2c): запасной путь, когда сеть не пропускает поиск рядом.
///
/// Когда соперник подключился или партия кончилась, экран сам сообщает [onBack]: код больше не нужен.
class HostQrScreen extends StatelessWidget {
  /// Создаёт экран.
  const HostQrScreen({super.key, required this.onBack});

  /// Вернуться к ожиданию.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScreenBackdrop(
      child: BlocConsumer<HostInviteCubit, HostInviteState>(
        listenWhen: (previous, current) => current is HostInviteDone,
        listener: (context, state) => onBack(),
        builder: (context, state) => Column(
          children: [
            ScreenHeader(title: l10n.netQrTitle, titleSize: 32, onBack: onBack),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: switch (state) {
                            HostInviteReady(:final invite, :final label) => _Code(invite: invite, label: label),
                            HostInviteFailed() => Text(
                              l10n.netQrFailed,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: GwentText.alegreya,
                                fontSize: 16,
                                height: 1.35,
                                color: GwentColors.textSecondary,
                              ),
                            ),
                            HostInviteLoading() || HostInviteDone() => const GameLoader(caption: ''),
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: GwentButton(
                        label: l10n.netQrBack,
                        style: GwentButtonStyle.secondary,
                        fontSize: 21,
                        onPressed: onBack,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Code extends StatelessWidget {
  const _Code({required this.invite, required this.label});

  final String invite;
  final String label;

  /// Сторона квадрата кода: чем крупнее модули, тем легче считать код с руки.
  static const double _size = 252;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 18,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [GwentColors.parchmentLight, GwentColors.parchmentShade],
            ),
            border: Border.all(color: GwentColors.brass),
            boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 34, offset: Offset(0, 14))],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                Semantics(
                  label: l10n.netQrSemantics,
                  image: true,
                  child: ExcludeSemantics(
                    child: QrImageView(
                      data: invite,
                      size: _size,
                      padding: const EdgeInsets.all(14),
                      // Тёплая подложка вместо белой, тёмно-коричневые модули: контраст остаётся высоким.
                      backgroundColor: const Color(0xFFEFE4C6),
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1E160D)),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF1E160D),
                      ),
                    ),
                  ),
                ),
                Text(
                  l10n.netQrCaption,
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontFamily: GwentText.cormorant,
                    fontWeight: FontWeight.w700,
                    fontSize: 25,
                    height: 1,
                    color: GwentColors.onParchment,
                  ),
                ),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: GwentColors.onParchmentSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        Text(
          l10n.netQrHint,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: GwentText.alegreya,
            fontSize: 14.5,
            height: 1.4,
            color: GwentColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
