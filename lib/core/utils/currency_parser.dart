/// Parses Brazilian Real (PT-BR) and standard decimal currency strings safely.
///
/// Examples:
/// - `"150,50"` -> `150.5`
/// - `"1.250,90"` -> `1250.9`
/// - `"R$ 89,90"` -> `89.9`
/// - `"150.50"` -> `150.5`
/// - `""`, `"abc"`, `"-50,00"` -> `null`
double? parseBrlCurrency(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.contains('-')) return null;

  final cleaned = trimmed.replaceAll(RegExp(r'[^0-9.,]'), '');
  if (cleaned.isEmpty) return null;

  String normalized;
  if (cleaned.contains(',')) {
    // Brazilian format: dots are thousand separators, last comma is decimal separator
    final withoutThousands = cleaned.replaceAll('.', '');
    final lastComma = withoutThousands.lastIndexOf(',');
    final intPart = withoutThousands.substring(0, lastComma).replaceAll(',', '');
    final decPart = withoutThousands.substring(lastComma + 1);
    normalized = '$intPart.$decPart';
  } else {
    // Dot-only format: if multiple dots exist, treat all but last (or all if 3-digit group) as thousands
    final parts = cleaned.split('.');
    if (parts.length > 2) {
      normalized = cleaned.replaceAll('.', '');
    } else {
      normalized = cleaned;
    }
  }

  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed < 0 || parsed.isNaN || parsed.isInfinite) {
    return null;
  }
  return parsed;
}
