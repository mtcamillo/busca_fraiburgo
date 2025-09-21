import 'dart:convert';

/// Estrutura esperada no JSON:
/// {
///   "tz":"America/Sao_Paulo",
///   "monday":[{"open":"09:00","close":"18:00"}],
///   ...
/// }
class OpenStatus {
  final bool isOpen;
  final String label; 
  OpenStatus(this.isOpen, this.label);
}

OpenStatus computeOpenStatus(dynamic hoursJson, {DateTime? now}) {
  if (hoursJson == null) return OpenStatus(false, 'Horário não informado');

  final map = (hoursJson is String)
      ? jsonDecode(hoursJson) as Map<String, dynamic>
      : Map<String, dynamic>.from(hoursJson as Map);

  final DateTime dt = now ?? DateTime.now();

  const daysKeys = {
    1: 'monday',
    2: 'tuesday',
    3: 'wednesday',
    4: 'thursday',
    5: 'friday',
    6: 'saturday',
    7: 'sunday',
  };

  final key = daysKeys[dt.weekday]!;
  final intervals = (map[key] ?? []) as List;

  bool inside = false;
  for (final it in intervals) {
    final open = (it['open'] as String).split(':');
    final close = (it['close'] as String).split(':');

    final openDt = DateTime(dt.year, dt.month, dt.day,
        int.parse(open[0]), int.parse(open[1]));
    final closeDt = DateTime(dt.year, dt.month, dt.day,
        int.parse(close[0]), int.parse(close[1]));

    if (dt.isAfter(openDt) && dt.isBefore(closeDt)) {
      inside = true;
      break;
    }
  }

  return inside ? OpenStatus(true, 'Aberto agora') : OpenStatus(false, 'Fechado');
}
