import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RecommendationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ✅ Fetch recommendations for a specific user
  /// Returns a list of recommendation maps sorted by createdAtMs DESC
  Stream<List<Map<String, dynamic>>> streamRecommendations(String userId) {
    return _db.collection('recommendation').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return [];

      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      final List<Map<String, dynamic>> recommendations = [];

      data.forEach((quizId, details) {
        if (details is Map) {
          final Map<String, dynamic> rec = Map<String, dynamic>.from(details);
          rec['quizId'] = quizId; // Ensure quizId is present
          recommendations.add(rec);
        }
      });

      // Sort by date DESC (Newest first)
      recommendations.sort((a, b) {
        final int timeA = a['createdAtMs'] ?? 0;
        final int timeB = b['createdAtMs'] ?? 0;
        return timeB.compareTo(timeA);
      });

      return recommendations;
    });
  }

  /// ✅ Fetch once (Future)
  Future<List<Map<String, dynamic>>> getRecommendations(String userId) async {
    try {
      final doc = await _db.collection('recommendation').doc(userId).get();
      if (!doc.exists) return [];

      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      final List<Map<String, dynamic>> recommendations = [];

      data.forEach((quizId, details) {
        if (details is Map) {
          final Map<String, dynamic> rec = Map<String, dynamic>.from(details);
          rec['quizId'] = quizId;
          recommendations.add(rec);
        }
      });

      recommendations.sort((a, b) {
        final int timeA = a['createdAtMs'] ?? 0;
        final int timeB = b['createdAtMs'] ?? 0;
        return timeB.compareTo(timeA);
      });

      return recommendations;
    } catch (e) {
      debugPrint("Error fetching recommendations: $e");
      return [];
    }
  }
}
