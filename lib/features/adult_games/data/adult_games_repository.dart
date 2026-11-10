import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:couple_app/features/adult_games/domain/adult_game_model.dart';

final adultGamesRepositoryProvider = Provider<AdultGamesRepository>((ref) {
  return AdultGamesRepository(firestore: FirebaseFirestore.instance);
});

final adultGamesDeckStreamProvider =
    StreamProvider.family<List<AdultGameCardModel>, String>((ref, coupleId) {
  if (coupleId.trim().isEmpty) return Stream.value(const []);
  return ref.watch(adultGamesRepositoryProvider).watchCards(coupleId);
});

final adultGameSessionStreamProvider =
    StreamProvider.family<AdultGameSessionState, String>((ref, coupleId) {
  if (coupleId.trim().isEmpty) {
    return Stream.value(const AdultGameSessionState());
  }
  return ref.watch(adultGamesRepositoryProvider).watchSession(coupleId);
});

class AdultGamesRepository {
  final FirebaseFirestore _firestore;

  AdultGamesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _cardsRef(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('adult_games');
  }

  DocumentReference<Map<String, dynamic>> _sessionRef(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('adult_game_state')
        .doc('current');
  }

  static const List<AdultGameCardModel> curatedDeck = [
    // NÍVEL 1: SUAVE 💕 (Conexão, Carinho e Sedução Leve)
    AdultGameCardModel(
      id: 'ag_gentle_01',
      title: 'Olhar nos Olhos',
      prompt:
          'Olhem-se nos olhos em silêncio por 60 segundos enquanto fazem carinho nas mãos um do outro e terminem com um beijo demorado.',
      level: AdultGameCardModel.levelGentle,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_gentle_02',
      title: 'Três Partes Favoritas',
      prompt:
          'Beije as 3 partes do rosto ou pescoço do seu amor que você acha mais irresistíveis e diga o motivo.',
      level: AdultGameCardModel.levelGentle,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_gentle_03',
      title: 'Memória Inesquecível',
      prompt:
          'Qual foi o momento em que você sentiu mais atração por mim desde que nos conhecemos?',
      level: AdultGameCardModel.levelGentle,
      cardType: AdultGameCardModel.typeQuestion,
    ),
    AdultGameCardModel(
      id: 'ag_gentle_04',
      title: 'Sussurro no Ouvido',
      prompt:
          'Sussurre bem baixinho no ouvido do seu parceiro(a) algo romântico (ou provocante) que você quer fazer hoje à noite.',
      level: AdultGameCardModel.levelGentle,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_gentle_05',
      title: 'Dança Coladinhos',
      prompt:
          'Coloquem uma música lenta e dancem abraçados no meio do quarto por pelo menos 2 minutos.',
      level: AdultGameCardModel.levelGentle,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_gentle_06',
      title: 'Toque Favorito',
      prompt:
          'Onde e como você mais gosta de receber carinho quando estamos sozinhos na cama?',
      level: AdultGameCardModel.levelGentle,
      cardType: AdultGameCardModel.typeQuestion,
    ),
    AdultGameCardModel(
      id: 'ag_gentle_07',
      title: 'Massagem na Nuca',
      prompt:
          'Faça uma massagem lenta nos ombros e na nuca do seu amor por 3 minutos, intercalando com beijos suaves.',
      level: AdultGameCardModel.levelGentle,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_gentle_08',
      title: 'Primeiro Beijo',
      prompt:
          'Recriem agora mesmo o primeiro beijo de vocês, mas com toda a paixão de hoje.',
      level: AdultGameCardModel.levelGentle,
      cardType: AdultGameCardModel.typeDare,
    ),

    // NÍVEL 2: OUSADO 🔥 (Provocação, Desejo e Sensualidade)
    AdultGameCardModel(
      id: 'ag_bold_01',
      title: 'Beijo de Olhos Vendados',
      prompt:
          'Um de vocês fecha os olhos por 2 minutos enquanto o outro escolhe 5 lugares do corpo para beijar lentamente.',
      level: AdultGameCardModel.levelBold,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_bold_02',
      title: 'Confissão de Fantasia',
      prompt:
          'Conte um desejo ou curiosidade íntima que você já pensou sobre nós dois, mas nunca teve coragem de falar em voz alta.',
      level: AdultGameCardModel.levelBold,
      cardType: AdultGameCardModel.typeQuestion,
    ),
    AdultGameCardModel(
      id: 'ag_bold_03',
      title: 'Trilha de Beijos',
      prompt:
          'Faça uma trilha de beijos lentos começando nos lábios, descendo pelo pescoço até a cintura do seu amor.',
      level: AdultGameCardModel.levelBold,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_bold_04',
      title: 'Uma Peça a Menos',
      prompt:
          'Tire lentamente uma peça de roupa do seu parceiro(a) mantendo contato visual o tempo todo.',
      level: AdultGameCardModel.levelBold,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_bold_05',
      title: 'Gatilho de Desejo',
      prompt:
          'O que eu faço — uma roupa, um olhar, um toque ou uma atitude — que deixa você com desejo quase instantaneamente?',
      level: AdultGameCardModel.levelBold,
      cardType: AdultGameCardModel.typeQuestion,
    ),
    AdultGameCardModel(
      id: 'ag_bold_06',
      title: 'Proibido Usar as Mãos',
      prompt:
          'Provoke e beije seu parceiro(a) por 90 segundos sem que ele(a) possa usar as mãos para tocar em você.',
      level: AdultGameCardModel.levelBold,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_bold_07',
      title: 'Massagem Sensual nas Coxas',
      prompt:
          'Faça uma massagem provocante nas pernas e parte interna das coxas do seu amor por 3 minutos.',
      level: AdultGameCardModel.levelBold,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_bold_08',
      title: 'Lugar Inusitado',
      prompt:
          'Qual cômodo da casa (fora da cama) ou lugar diferente você mais gostaria que a gente aproveitasse juntos?',
      level: AdultGameCardModel.levelBold,
      cardType: AdultGameCardModel.typeQuestion,
    ),

    // NÍVEL 3: PICANTE 🌶️ (Intimidade 18+ Intensa)
    AdultGameCardModel(
      id: 'ag_spicy_01',
      title: 'No Comando por 5 Minutos',
      prompt:
          'Durante os próximos 5 minutos, seu parceiro(a) está 100% no comando e você deve realizar cada pedido sensual dele(a).',
      level: AdultGameCardModel.levelSpicy,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_spicy_02',
      title: 'Temperatura Máxima',
      prompt:
          'Use um cubo de gelo ou o calor da respiração para percorrer o pescoço, peito e abdômen do seu amor.',
      level: AdultGameCardModel.levelSpicy,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_spicy_03',
      title: 'Demonstração ao Vivo',
      prompt:
          'Em vez de apenas dizer, mostre no corpo do seu parceiro(a) exatamente o ritmo e a intensidade que você mais gosta.',
      level: AdultGameCardModel.levelSpicy,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_spicy_04',
      title: 'Nossa Noite Mais Quente',
      prompt:
          'Descreva com todos os detalhes qual foi a nossa vez mais inesquecível e o que você quer repetir hoje.',
      level: AdultGameCardModel.levelSpicy,
      cardType: AdultGameCardModel.typeQuestion,
    ),
    AdultGameCardModel(
      id: 'ag_spicy_05',
      title: 'Sussurro Proibido',
      prompt:
          'Descreva no ouvido do seu amor, sem filtro, exatamente o que você quer fazer com ele(a) quando o jogo terminar.',
      level: AdultGameCardModel.levelSpicy,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_spicy_06',
      title: 'Desafio do Silêncio',
      prompt:
          'Acaricie e beije as zonas mais sensíveis do seu amor por 2 minutos enquanto ele(a) tenta não emitir nenhum som.',
      level: AdultGameCardModel.levelSpicy,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_spicy_07',
      title: 'Nova Experiência',
      prompt:
          'Escolha uma posição ou carícia que ainda não tentamos este mês e pratiquem juntos agora.',
      level: AdultGameCardModel.levelSpicy,
      cardType: AdultGameCardModel.typeDare,
    ),
    AdultGameCardModel(
      id: 'ag_spicy_08',
      title: 'Desejo Secreto Revelado',
      prompt:
          'Se hoje não houvesse nenhum limite ou timidez, qual seria o seu pedido número 1 na cama?',
      level: AdultGameCardModel.levelSpicy,
      cardType: AdultGameCardModel.typeQuestion,
    ),
  ];

  Stream<List<AdultGameCardModel>> watchCards(String coupleId) {
    bool seeded = false;
    return _cardsRef(coupleId).snapshots().asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty && !seeded) {
        seeded = true;
        final batch = _firestore.batch();
        for (final card in curatedDeck) {
          batch.set(_cardsRef(coupleId).doc(card.id), card.toMap());
        }
        await batch.commit();
        return curatedDeck;
      }
      return snapshot.docs
          .map((doc) => AdultGameCardModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Stream<AdultGameSessionState> watchSession(String coupleId) {
    return _sessionRef(coupleId).snapshots().map(
          (snap) => AdultGameSessionState.fromMap(snap.data()),
        );
  }

  Future<void> setActiveCard(
    String coupleId, {
    required String cardId,
    required String level,
  }) async {
    await _sessionRef(coupleId).set(
      {
        'activeCardId': cardId,
        'selectedLevel': level,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> sendSpicyNudge(
    String coupleId, {
    required String senderUid,
    required String senderName,
    required String message,
  }) async {
    await _sessionRef(coupleId).set(
      {
        'nudgeSenderUid': senderUid,
        'nudgeSenderName': senderName,
        'nudgeMessage': message,
        'nudgeSentAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> toggleCardCompleted(
    String coupleId,
    AdultGameCardModel card,
  ) async {
    final updated = card.toggleCompleted();
    await _cardsRef(coupleId).doc(card.id).update(updated.toMap());
  }

  Future<void> addCustomCard(
    String coupleId,
    AdultGameCardModel card,
  ) async {
    final docRef = _cardsRef(coupleId).doc();
    await docRef.set(card.copyWith(id: docRef.id).toMap());
  }
}
