import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Камера, которая читает QR-коды: нативное окно `mobile_scanner` без подписей и рамок.
///
/// Каждый считанный код приходит в [onCode] как строка (повтор того же кода плагин не присылает). Камера
/// недоступна (нет разрешения, нет камеры) — один раз вызывается [onUnavailable].
class CameraQrScanner extends StatefulWidget {
  /// Создаёт сканер.
  const CameraQrScanner({super.key, required this.onCode, required this.onUnavailable});

  /// Считан код.
  final ValueChanged<String> onCode;

  /// Камеру открыть не удалось.
  final VoidCallback onUnavailable;

  @override
  State<CameraQrScanner> createState() => _CameraQrScannerState();
}

class _CameraQrScannerState extends State<CameraQrScanner> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue case final value?) widget.onCode(value);
    }
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
    controller: _controller,
    onDetect: _onDetect,
    errorBuilder: (context, error) => _ReportOnce(onReport: widget.onUnavailable),
  );
}

/// Сообщает о сбое камеры после кадра: во время сборки экран менять нельзя.
class _ReportOnce extends StatefulWidget {
  const _ReportOnce({required this.onReport});

  final VoidCallback onReport;

  @override
  State<_ReportOnce> createState() => _ReportOnceState();
}

class _ReportOnceState extends State<_ReportOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReport();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
