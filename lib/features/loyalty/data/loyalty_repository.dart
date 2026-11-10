import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:couple_app/features/loyalty/domain/loyalty_coupon_model.dart';

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  return LoyaltyRepository(firestore: FirebaseFirestore.instance);
});

final loyaltyCouponsStreamProvider =
    StreamProvider.family<List<LoyaltyCouponModel>, String>((ref, coupleId) {
  if (coupleId.trim().isEmpty) return Stream.value(const []);
  return ref.watch(loyaltyRepositoryProvider).watchCoupons(coupleId);
});

class LoyaltyRepository {
  final FirebaseFirestore _firestore;

  LoyaltyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _couponsRef(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('loyalty_coupons');
  }

  static List<LoyaltyCouponModel> defaultLoveCoupons(DateTime now) {
    return [
      LoyaltyCouponModel(
        id: 'coupon_massage',
        title: 'Vale-Massagem Relaxante (20 min)',
        description:
            'Direito a 20 minutos de massagem nas costas ou nos pés, sem reclamações e com óleo ou hidratante.',
        emoji: '💆',
        category: LoyaltyCouponModel.categoryCare,
        maxUses: 3,
        createdBy: 'system',
        createdAt: now,
      ),
      LoyaltyCouponModel(
        id: 'coupon_breakfast',
        title: 'Vale-Café da Manhã na Cama',
        description:
            'Acorde com café fresquinho, pão quentinho e frutas preparados pelo seu amor.',
        emoji: '🥐',
        category: LoyaltyCouponModel.categoryFood,
        maxUses: 2,
        createdBy: 'system',
        createdAt: now,
      ),
      LoyaltyCouponModel(
        id: 'coupon_movie_pick',
        title: 'Vale-Escolha Absoluta do Filme',
        description:
            'Hoje quem escolhe o filme ou série sou eu — com direito a pipoca e zero poder de veto!',
        emoji: '🎬',
        category: LoyaltyCouponModel.categoryFun,
        maxUses: 3,
        createdBy: 'system',
        createdAt: now,
      ),
      LoyaltyCouponModel(
        id: 'coupon_no_chores',
        title: 'Vale-Folga das Tarefas de Hoje',
        description:
            'Passe livre da louça ou limpeza de hoje. Seu único dever é descansar no sofá!',
        emoji: '🛋️',
        category: LoyaltyCouponModel.categoryCare,
        maxUses: 2,
        createdBy: 'system',
        createdAt: now,
      ),
      LoyaltyCouponModel(
        id: 'coupon_dinner',
        title: 'Vale-Jantar Romântico ou Delivery',
        description:
            'Escolha seu prato favorito para cozinharmos juntos ou pedirmos hoje à noite.',
        emoji: '🍝',
        category: LoyaltyCouponModel.categoryFood,
        maxUses: 2,
        createdBy: 'system',
        createdAt: now,
      ),
      LoyaltyCouponModel(
        id: 'coupon_kisses',
        title: 'Vale-Chuva de Beijos & Cafuné',
        description:
            'Resgate imediatamente 15 minutos de cafuné, abraço apertado e muitos beijos.',
        emoji: '💋',
        category: LoyaltyCouponModel.categoryRomance,
        maxUses: 5,
        createdBy: 'system',
        createdAt: now,
      ),
      LoyaltyCouponModel(
        id: 'coupon_dessert',
        title: 'Vale-Doce ou Sobremesa Surpresa',
        description:
            'Seu amor busca ou prepara seu doce/chocolate favorito quando bater aquela vontade.',
        emoji: '🍫',
        category: LoyaltyCouponModel.categoryFood,
        maxUses: 3,
        createdBy: 'system',
        createdAt: now,
      ),
      LoyaltyCouponModel(
        id: 'coupon_surprise_date',
        title: 'Vale-Passeio Surpresa a Dois',
        description:
            'Um encontro planejado do início ao fim pelo seu parceiro(a) para sair da rotina.',
        emoji: '✨',
        category: LoyaltyCouponModel.categoryRomance,
        maxUses: 1,
        createdBy: 'system',
        createdAt: now,
      ),
    ];
  }

  Stream<List<LoyaltyCouponModel>> watchCoupons(String coupleId) {
    bool seeded = false;
    return _couponsRef(coupleId).snapshots().asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty && !seeded) {
        seeded = true;
        final defaults = defaultLoveCoupons(DateTime.now());
        final batch = _firestore.batch();
        for (final c in defaults) {
          batch.set(_couponsRef(coupleId).doc(c.id), c.toMap());
        }
        await batch.commit();
        return defaults;
      }
      final list = snapshot.docs
          .map((doc) => LoyaltyCouponModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) {
        if (a.isExhausted != b.isExhausted) {
          return a.isExhausted ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  Future<void> addCoupon(String coupleId, LoyaltyCouponModel coupon) async {
    final docRef = coupon.id.isNotEmpty
        ? _couponsRef(coupleId).doc(coupon.id)
        : _couponsRef(coupleId).doc();
    await docRef.set(coupon.copyWith(id: docRef.id).toMap());
  }

  Future<void> redeemCoupon(
    String coupleId,
    LoyaltyCouponModel coupon,
    String redeemedByUid,
  ) async {
    if (coupon.isExhausted) return;
    final updated = coupon.redeem(redeemedByUid: redeemedByUid);
    await _couponsRef(coupleId).doc(coupon.id).update({
      'usedCount': updated.usedCount,
      'lastRedeemedAt': Timestamp.fromDate(updated.lastRedeemedAt!),
      'lastRedeemedBy': updated.lastRedeemedBy,
    });
  }

  Future<void> refillCoupon(String coupleId, String couponId) async {
    await _couponsRef(coupleId).doc(couponId).update({
      'usedCount': 0,
    });
  }

  Future<void> deleteCoupon(String coupleId, String couponId) async {
    await _couponsRef(coupleId).doc(couponId).delete();
  }
}
