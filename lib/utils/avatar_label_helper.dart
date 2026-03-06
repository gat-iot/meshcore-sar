class AvatarLabelHelper {
  static String buildLabel(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';

    if (trimmed.startsWith('#')) {
      final hashBody = trimmed.substring(1).replaceAll(RegExp(r'[\s_-]+'), '');
      if (hashBody.isEmpty) {
        return '#';
      }
      return '#${_take(hashBody, 2)}'.toUpperCase();
    }

    final parts = trimmed
        .split(RegExp(r'[\s_-]+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      final first = _take(parts[0], 1);
      final second = _take(parts[1], 1);
      return '$first$second'.toUpperCase();
    }

    return _take(trimmed, 2).toUpperCase();
  }

  static String _take(String value, int count) {
    if (value.length <= count) return value;
    return value.substring(0, count);
  }
}
