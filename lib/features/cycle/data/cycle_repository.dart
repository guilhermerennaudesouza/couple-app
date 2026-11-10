import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:couple_app/features/cycle/domain/cycle_model.dart';

final cycleRepositoryProvider = Provider<CycleRepository>((ref) {
  return CycleRepository(firestore: FirebaseFirestore.instance);
});

final cycleDataStreamProvider =
    StreamProvider.family<CycleDataModel, String>((ref, coupleId) {
  if (coupleId.trim().isEmpty) {
    return Stream.value(
      CycleDataModel(
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 10)),
      ),
    );
  }
  return ref.watch(cycleRepositoryProvider).watchCycleData(coupleId);
});

class CycleRepository {
  final FirebaseFirestore _firestore;

  CycleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _docRef(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('cycle_data')
        .doc('current');
  }

  static const List<String> availableSymptoms = [
    'Cólica 🩸',
    'Sensível 🥺',
    'Desejo de Doce 🍫',
    'Cansaço 😴',
    'Dor de Cabeça 🤕',
    'Inchaço 💧',
    'Com Energia ⚡',
    'Carinhosa(o) 💕',
    'Libido Alta 🔥',
    'Paz & Calma 🧘',
  ];

  static const List<Map<String, String>> careRequests = [
    {
      'emoji': '🤗',
      'title': 'Preciso de um abraço apertado e cafuné',
    },
    {
      'emoji': '🍫',
      'title': 'Desejo oficial de chocolate ou docinho',
    },
    {
      'emoji': '🍵',
      'title': 'Bolsa de água quente e um chazinho',
    },
    {
      'emoji': '🧹',
      'title': 'Pode assumir as tarefas de casa hoje?',
    },
    {
      'emoji': '🍝',
      'title': 'Cozinhar ou pedir nosso jantar favorito hoje',
    },
    {
      'emoji': '🌙',
      'title': 'Preciso de descanso tranquilo e acolhimento',
    },
  ];

  Stream<CycleDataModel> watchCycleData(String coupleId) {
    return _docRef(coupleId).snapshots().map(
          (snap) => CycleDataModel.fromMap(snap.data()),
        );
  }

  Future<void> saveCycleSettings(
    String coupleId, {
    required DateTime lastPeriodStart,
    required int cycleLength,
    required int periodDuration,
  }) async {
    await _docRef(coupleId).set(
      {
        'lastPeriodStart': Timestamp.fromDate(lastPeriodStart),
        'cycleLength': cycleLength,
        'periodDuration': periodDuration,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> toggleSymptom(
    String coupleId,
    CycleDataModel current,
    String symptom,
  ) async {
    final next = List<String>.from(current.currentSymptoms);
    if (next.contains(symptom)) {
      next.remove(symptom);
    } else {
      next.add(symptom);
    }
    await _docRef(coupleId).set(
      {
        'currentSymptoms': next,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> sendCareRequest(
    String coupleId, {
    required String requestText,
    required String senderName,
  }) async {
    await _docRef(coupleId).set(
      {
        'activeCareRequest': requestText,
        'careRequestedByName': senderName,
        'careRequestedAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> clearCareRequest(String coupleId) async {
    await _docRef(coupleId).set(
      {
        'activeCareRequest': null,
        'careRequestedByName': null,
        'careRequestedAt': null,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }
}
