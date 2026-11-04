import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/daily_question_model.dart';

/// Repository managing daily question prompts and dual-answer reveal logic.
///
/// Data is persisted under `/couples/{coupleId}/daily_questions/{questionId}`.
/// Includes an integrated 50+ question bank with automatic seeding.
class DailyQuestionRepository {
  final FirebaseFirestore _firestore;

  DailyQuestionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Default curated question bank for couples.
  static const List<String> defaultQuestionBank = [
    'What was your favorite memory together this week?',
    'What is a dream trip you want to take with me?',
    'What first went through your mind the very first time we met?',
    'What is something small that I do that always makes you smile?',
    'If we could spend an entire weekend doing anything with zero responsibilities, what would we do?',
    'What is your favorite song that always reminds you of us?',
    'What is one quality in me that you admire the most?',
    'What was the funniest moment we have ever shared?',
    'What is a dish or meal we shared that you will never forget?',
    'If our relationship were a movie genre, what would it be?',
    'What is one goal you want us to accomplish together in the next year?',
    'What is your favorite way to unwind together after a long day?',
    'What habit of mine do you find endearing or cute?',
    'What is the sweetest thing I have ever done for you?',
    'If you could freeze one day from our past to relive forever, which one would it be?',
    'What is something new you would love for us to learn or try together?',
    'What is your favorite photo of us and what was happening when it was taken?',
    'How have I helped you grow as a person since we got together?',
    'What is something that made you laugh uncontrollably recently?',
    'What is your favorite morning or evening ritual that we share?',
    'If you had an unexpected free day with me tomorrow, where would we go?',
    'What is something you appreciate about how we handle disagreements?',
    'What is a secret dream or passion you haven\'t talked about in a while?',
    'What was a moment when you felt most supported and loved by me?',
    'What is your favorite physical feature or expression of mine?',
    'If we wrote a book about our love story, what would the title be?',
    'What is the most memorable surprise we\'ve ever pulled off for each other?',
    'What is one compliment you received from me that stuck with you?',
    'What is your comfort food when you\'re feeling down, and how can I best cheer you up?',
    'What is an inside joke between us that never fails to make you laugh?',
    'What is one value or principle we share that you cherish most?',
    'If you could pick our next anniversary celebration spot right now, where would it be?',
    'What was the moment you realized you had truly fallen for me?',
    'What is your favorite holiday tradition we have created or want to create?',
    'What is something about the future that excites you the most when you picture us together?',
    'What is a small gesture of affection you love receiving most?',
    'What is something funny or quirky that only the two of us know about each other?',
    'What is your favorite outfit or style that you love seeing me in?',
    'If we had our own signature couple drink, what would it taste like?',
    'What is one place in our town or city that holds special meaning for us?',
    'What made you proud of me recently?',
    'What is a book, show, or film you would love for us to binge together under blankets?',
    'What is one promise you make to me for our future?',
    'What is the best piece of advice anyone has ever given you about love?',
    'How would you describe our bond in three words?',
    'What is your favorite thing about waking up next to each other?',
    'If we could build our dream house, what is one non-negotiable room or feature we would have?',
    'What is something you are deeply grateful for in our lives today?',
    'What is a sweet memory from when we were first dating that you still replay?',
    'What makes you feel safest and most at home when we are together?',
  ];

  /// Formats a [DateTime] into standard `YYYY-MM-DD` date key.
  static String formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Today's date string in `YYYY-MM-DD` format.
  static String get todayDateString => formatDate(DateTime.now());

  /// Deterministically picks a prompt from the question bank for a given date.
  static String getPromptForDate(String dateString) {
    final hash = dateString.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    final index = hash.abs() % defaultQuestionBank.length;
    return defaultQuestionBank[index];
  }

  /// Ensures today's question exists in Firestore for [coupleId], creating it if absent.
  Future<DailyQuestionModel> ensureTodayQuestion(
    String coupleId, {
    DateTime? date,
  }) async {
    final dateStr = date != null ? formatDate(date) : todayDateString;
    final docRef = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('daily_questions')
        .doc(dateStr);

    final snapshot = await docRef.get();
    if (snapshot.exists && snapshot.data() != null) {
      return DailyQuestionModel.fromMap(snapshot.id, snapshot.data()!);
    }

    final prompt = getPromptForDate(dateStr);
    final newQuestion = DailyQuestionModel(
      id: dateStr,
      date: dateStr,
      prompt: prompt,
      answers: const {},
      isRevealed: false,
    );

    await docRef.set(newQuestion.toMap(), SetOptions(merge: true));
    return newQuestion;
  }

  /// Single-shot retrieval of today's question for [coupleId].
  Future<DailyQuestionModel> getTodayQuestion(
    String coupleId, {
    DateTime? date,
  }) async {
    return ensureTodayQuestion(coupleId, date: date);
  }

  /// Watches today's question in real time.
  ///
  /// Yields immediate question data even if document is in process of seeding.
  Stream<DailyQuestionModel> watchTodayQuestion(
    String coupleId, {
    DateTime? date,
  }) {
    final dateStr = date != null ? formatDate(date) : todayDateString;
    final docRef = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('daily_questions')
        .doc(dateStr);

    return docRef.snapshots().asyncMap((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        return DailyQuestionModel.fromMap(snapshot.id, snapshot.data()!);
      } else {
        try {
          return await ensureTodayQuestion(coupleId, date: date);
        } catch (_) {
          return DailyQuestionModel(
            id: dateStr,
            date: dateStr,
            prompt: getPromptForDate(dateStr),
            answers: const {},
            isRevealed: false,
          );
        }
      }
    });
  }

  /// Submits an answer atomically.
  ///
  /// Writes `answers.{uid}` and atomically toggles `isRevealed = true`
  /// when both partners have submitted their answers.
  Future<void> submitAnswer(
    String coupleId,
    String questionId,
    String uid,
    String text,
  ) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw ArgumentError('Answer cannot be empty.');
    }

    final docRef = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('daily_questions')
        .doc(questionId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final now = DateTime.now();
      final newAnswer = DailyQuestionAnswer(
        uid: uid,
        text: trimmedText,
        answeredAt: now,
      );

      if (!snapshot.exists || snapshot.data() == null) {
        final prompt = getPromptForDate(questionId);
        final newQuestion = DailyQuestionModel(
          id: questionId,
          date: questionId,
          prompt: prompt,
          answers: {uid: newAnswer},
          isRevealed: false,
        );
        transaction.set(docRef, newQuestion.toMap());
      } else {
        final data = snapshot.data()!;
        final rawAnswers = data['answers'];
        final Map<String, dynamic> answersMap =
            rawAnswers is Map ? Map<String, dynamic>.from(rawAnswers) : {};

        answersMap[uid] = newAnswer.toMap();
        final shouldReveal = answersMap.length >= 2;

        transaction.update(docRef, {
          'answers.$uid': newAnswer.toMap(),
          if (shouldReveal) 'isRevealed': true,
        });
      }
    });
  }

  /// Watches all historical daily questions for [coupleId], ordered by date descending.
  Stream<List<DailyQuestionModel>> watchPastQuestions(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('daily_questions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DailyQuestionModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }
}

/// Riverpod provider for [DailyQuestionRepository].
final dailyQuestionRepositoryProvider = Provider<DailyQuestionRepository>((ref) {
  return DailyQuestionRepository();
});

/// Riverpod stream provider for today's [DailyQuestionModel] keyed by coupleId.
final todayDailyQuestionProvider =
    StreamProvider.family<DailyQuestionModel, String>((ref, coupleId) {
  final repository = ref.watch(dailyQuestionRepositoryProvider);
  return repository.watchTodayQuestion(coupleId);
});

/// Riverpod stream provider for the list of past [DailyQuestionModel]s keyed by coupleId.
final pastDailyQuestionsProvider =
    StreamProvider.family<List<DailyQuestionModel>, String>((ref, coupleId) {
  final repository = ref.watch(dailyQuestionRepositoryProvider);
  return repository.watchPastQuestions(coupleId);
});
