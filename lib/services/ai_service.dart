import 'package:cloud_firestore/cloud_firestore.dart';

class AiService {
  final CollectionReference _generations = FirebaseFirestore.instance.collection('ai_generations');
  final CollectionReference _usage = FirebaseFirestore.instance.collection('user_usage');

  /// ✅ Log AI Generation
  Future<void> logGeneration({
    required String userId,
    required String prompt,
    required String generatedQuizId,
  }) async {
    await _generations.add({
      'userId': userId,
      'prompt': prompt,
      'generatedQuizId': generatedQuizId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update usage
    await _usage.doc(userId).set({
      'aiGenerationsToday': FieldValue.increment(1),
      'lastReset': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ✅ Check user usage quota
  Future<int> getAiUsageToday(String userId) async {
    final doc = await _usage.doc(userId).get();
    if (!doc.exists) return 0;
    return (doc.data() as Map<String, dynamic>)['aiGenerationsToday'] ?? 0;
  }
}
