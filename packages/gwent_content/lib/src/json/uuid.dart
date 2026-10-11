final RegExp _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

/// UUID в каноническом виде: 36 символов, hex в нижнем регистре, дефисы на своих местах.
bool isCanonicalUuid(String value) => _uuid.hasMatch(value);
