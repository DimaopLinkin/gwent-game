import 'package:crypto/crypto.dart';

/// Префикс хеша содержимого в манифесте: `sha256:<hex>`.
const String contentHashPrefix = 'sha256:';

/// SHA-256 байтов [bytes] в нижнем регистре hex (64 символа).
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// Хеш содержимого в виде `sha256:<hex>`, как его пишет манифест.
String contentHashOf(List<int> bytes) => '$contentHashPrefix${sha256Hex(bytes)}';
