import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the couple's Cycle Tracker & Partner Care state ("Ciclo & Cuidado do Casal").
class CycleDataModel {
  static const String phaseMenstrual = 'menstrual';
  static const String phaseFollicular = 'follicular';
  static const String phaseOvulation = 'ovulation';
  static const String phaseLuteal = 'luteal';

  final DateTime lastPeriodStart;
  final int cycleLength;
  final int periodDuration;
  final List<String> currentSymptoms;
  final String? activeCareRequest;
  final String? careRequestedByName;
  final DateTime? careRequestedAt;
  final DateTime updatedAt;

  CycleDataModel({
    required this.lastPeriodStart,
    this.cycleLength = 28,
    this.periodDuration = 5,
    this.currentSymptoms = const [],
    this.activeCareRequest,
    this.careRequestedByName,
    this.careRequestedAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Returns 1-indexed day of the current cycle.
  int currentCycleDay({DateTime? today}) {
    final now = today ?? DateTime.now();
    final startClean = DateTime(
      lastPeriodStart.year,
      lastPeriodStart.month,
      lastPeriodStart.day,
    );
    final nowClean = DateTime(now.year, now.month, now.day);
    final diff = nowClean.difference(startClean).inDays;
    if (diff < 0) return 1;
    final safeLength = cycleLength.clamp(21, 45);
    return (diff % safeLength) + 1;
  }

  /// Calculates the active cycle phase based on [currentCycleDay].
  String currentPhase({DateTime? today}) {
    final day = currentCycleDay(today: today);
    final safePeriod = periodDuration.clamp(2, 10);
    final ovulationCenter = (cycleLength - 14).clamp(10, 22);

    if (day <= safePeriod) {
      return phaseMenstrual;
    } else if (day < ovulationCenter - 2) {
      return phaseFollicular;
    } else if (day <= ovulationCenter + 2) {
      return phaseOvulation;
    } else {
      return phaseLuteal;
    }
  }

  String phaseTitlePt({DateTime? today}) {
    switch (currentPhase(today: today)) {
      case phaseMenstrual:
        return 'Fase Menstrual 🩸';
      case phaseFollicular:
        return 'Fase Folicular 🌱';
      case phaseOvulation:
        return 'Fase Fértil / Ovulação ✨';
      case phaseLuteal:
      default:
        return 'Fase Lútea / Pré-Menstrual 🌙';
    }
  }

  String phasePartnerTipPt({DateTime? today}) {
    switch (currentPhase(today: today)) {
      case phaseMenstrual:
        return 'Momento de acolhimento máximo: ofereça bolsa de água quente, chá ou chocolate, assuma tarefas mais pesadas e dê muito cafuné sem cobranças 💕';
      case phaseFollicular:
        return 'A energia e a disposição estão subindo! Ótima fase para passeios ao ar livre, planejar novidades e experimentar novos restaurantes juntos 🌱';
      case phaseOvulation:
        return 'Pico de conexão, autoestima e libido! Capriche nos elogios, planeje um encontro romântico especial e aproveitem a sintonia a dois ✨';
      case phaseLuteal:
      default:
        return 'Fase de maior sensibilidade e possível TPM: pratique escuta carinhosa, paciência extra, jantares aconchegantes em casa e pequenos mimos 🌙';
    }
  }

  int daysUntilNextPeriod({DateTime? today}) {
    final day = currentCycleDay(today: today);
    final safeLength = cycleLength.clamp(21, 45);
    return (safeLength - day + 1).clamp(0, safeLength);
  }

  DateTime nextPeriodDate({DateTime? today}) {
    final now = today ?? DateTime.now();
    final todayClean = DateTime(now.year, now.month, now.day);
    return todayClean.add(Duration(days: daysUntilNextPeriod(today: today)));
  }

  CycleDataModel copyWith({
    DateTime? lastPeriodStart,
    int? cycleLength,
    int? periodDuration,
    List<String>? currentSymptoms,
    String? activeCareRequest,
    String? careRequestedByName,
    DateTime? careRequestedAt,
    bool clearCareRequest = false,
    DateTime? updatedAt,
  }) {
    return CycleDataModel(
      lastPeriodStart: lastPeriodStart ?? this.lastPeriodStart,
      cycleLength: cycleLength ?? this.cycleLength,
      periodDuration: periodDuration ?? this.periodDuration,
      currentSymptoms: currentSymptoms ?? this.currentSymptoms,
      activeCareRequest: clearCareRequest
          ? null
          : (activeCareRequest ?? this.activeCareRequest),
      careRequestedByName: clearCareRequest
          ? null
          : (careRequestedByName ?? this.careRequestedByName),
      careRequestedAt: clearCareRequest
          ? null
          : (careRequestedAt ?? this.careRequestedAt),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lastPeriodStart': Timestamp.fromDate(lastPeriodStart),
      'cycleLength': cycleLength,
      'periodDuration': periodDuration,
      'currentSymptoms': currentSymptoms,
      'activeCareRequest': activeCareRequest,
      'careRequestedByName': careRequestedByName,
      'careRequestedAt':
          careRequestedAt != null ? Timestamp.fromDate(careRequestedAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory CycleDataModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return CycleDataModel(
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 10)),
      );
    }
    return CycleDataModel(
      lastPeriodStart: _parseDate(map['lastPeriodStart']) ??
          DateTime.now().subtract(const Duration(days: 10)),
      cycleLength: (map['cycleLength'] as num?)?.toInt() ?? 28,
      periodDuration: (map['periodDuration'] as num?)?.toInt() ?? 5,
      currentSymptoms: (map['currentSymptoms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      activeCareRequest: map['activeCareRequest'] as String?,
      careRequestedByName: map['careRequestedByName'] as String?,
      careRequestedAt: _parseDate(map['careRequestedAt']),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}
