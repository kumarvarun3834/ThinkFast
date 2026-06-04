import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final CollectionReference _db =
  FirebaseFirestore.instance.collection('databases');
  final CollectionReference _responses =
  FirebaseFirestore.instance.collection('responses');
  final CollectionReference _users =
  FirebaseFirestore.instance.collection('users');

  /// ✅ Create a new user profile
  Future<void> createUserProfile({
    required String uid,
    required String email,
    String? name,
  }) async {
    await _users.doc(uid).set({
      'email': email,
      'name': name ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Fetch user profile by UID
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>;
  }

  /// 🛠️ Helper to transform quiz data and extract answer keys
  Map<String, dynamic> _transformQuizData(List<Map<String, Object>> inputData) {
    final List<Map<String, dynamic>> transformedData = [];
    final List<Map<String, String>> answerKeys = [];

    for (int i = 0; i < inputData.length; i++) {
      final item = inputData[i];
      final String qUid = "q_${DateTime.now().microsecondsSinceEpoch}_$i";
      final String qText = (item['question'] ?? '').toString();

      final choices = item['choices'] as List? ?? [];
      final answers = item['answers'] as List? ?? [];

      final List<Map<String, String>> optionsWithIds = [];
      for (int j = 0; j < choices.length; j++) {
        final String optUid =
            "opt_${DateTime.now().microsecondsSinceEpoch}_${i}_$j";
        final String optText = choices[j].toString();
        optionsWithIds.add({'id': optUid, 'text': optText});

        if (answers.contains(optText)) {
          answerKeys.add({'q': qUid, 'a': optUid});
        }
      }

      transformedData.add({
        'Q': {'id': qUid, 'text': qText},
        'Opt': optionsWithIds,
        'type': item['type'] ?? 'Single Choice',
      });
    }

    return {
      'data': transformedData,
      'answerkeys': answerKeys,
    };
  }

  /// ✅ Create a new database (quiz set)
  Future<String> createDatabase({
    required String creatorId, // 🔑 UID
    required String user, // email / phone (display only)
    required String title,
    required String description,
    required String visibility,
    required List<Map<String, Object>> data,
    required int time, // minutes
  }) async {
    final transformed = _transformQuizData(data);

    final docRef = await _db.add({
      'creatorId': creatorId,
      'user': user,
      'title': title,
      'description': description,
      'visibility': visibility,
      'data': transformed['data'],
      'answerkeys': transformed['answerkeys'], // [[Q,a],[Q,a]]
      'time': time * 60, // store seconds
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id; // return Firestore document ID
  }

  /// ✅ Read databases (real-time stream) with filters
  Stream<List<Map<String, dynamic>>> readAllDatabases({
    bool showMyQuizzes = false,
    String? creatorId,
  }) {
    Query query = _db;

    if (showMyQuizzes && creatorId != null) {
      query = query.where('creatorId', isEqualTo: creatorId);
    } else {
      query = query.where('visibility', isEqualTo: 'public');
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // 🛡️ Remove questions data to save bandwidth in list view
        data.remove('data');

        return data;
      }).toList();
    });
  }

  /// ✅ Update an existing database (only creator can update)
  Future<void> updateDatabase({
    required String docId,
    required String currentUserId, // 🔑 UID
    String? title,
    String? description,
    List<Map<String, Object>>? data,
    String? visibility,
    int? time, // minutes
  }) async {
    final docRef = _db.doc(docId);
    final doc = await docRef.get();

    if (!doc.exists) throw Exception('Quiz not found');
    if (doc['creatorId'] != currentUserId) {
      throw Exception('Only creator can update this quiz');
    }

    final Map<String, dynamic> updates = {};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (data != null) {
      final transformed = _transformQuizData(data);
      updates['data'] = transformed['data'];
      updates['answerkeys'] = transformed['answerkeys'];
    }
    if (visibility != null) updates['visibility'] = visibility;
    if (time != null) updates['time'] = time * 60;

    updates['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.update(updates);
  }

  /// ✅ Delete a database (only creator can delete)
  Future<void> deleteDatabase({
    required String docId,
    required String currentUserId, // 🔑 UID
  }) async {
    final docRef = _db.doc(docId);
    final doc = await docRef.get();

    if (!doc.exists) throw Exception('Quiz not found');
    if (doc['creatorId'] != currentUserId) {
      throw Exception('Only creator can delete this quiz');
    }

    await docRef.delete();
  }

  /// ✅ Read a single database (quiz) by docId - Strips answers for security
  Future<Map<String, dynamic>> readDatabase(String docId) async {
    final doc = await _db.doc(docId).get();
    if (!doc.exists) throw Exception("Quiz not found");

    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;

    // 🛡️ Remove 'answerkeys' to ensure answers are not sent to the client
    data.remove('answerkeys');

    return data;
  }

  /// ✅ Fetch ONLY the correct answers for a quiz (to be called on submit)
  Future<Map<String, List<String>>> getQuizAnswers(String docId) async {
    final doc = await _db.doc(docId).get();
    if (!doc.exists) throw Exception("Quiz not found");

    final data = doc.data() as Map<String, dynamic>;
    final Map<String, List<String>> result = {};

    if (data['answerkeys'] != null && data['answerkeys'] is List) {
      for (var entry in data['answerkeys']) {
        if (entry is Map) {
          final qUid = entry['q'].toString();
          final optUid = entry['a'].toString();

          if (result[qUid] == null) {
            result[qUid] = [optUid];
          } else {
            result[qUid]!.add(optUid);
          }
        }
      }
    }

    return result;
  }

  /// ✅ Submit a quiz attempt (based on responses schema)
  Future<void> submitAttempt({
    required String userId,
    required String quizId,
    required int score,
    required int totalQuestions,
    required Map<String, String> answers, // Map of questionId -> chosen choiceId
  }) async {
    final userDoc = _responses.doc(userId);

    // Update root user document
    await userDoc.set({
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Add to 'attempts' sub-collection
    await userDoc.collection('attempts').add({
      'quizId': quizId,
      'score': score,
      'totalQuestions': totalQuestions,
      'answers': answers,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Read all attempts for a specific user
  Stream<List<Map<String, dynamic>>> getUserAttempts(String userId) {
    return _responses
        .doc(userId)
        .collection('attempts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// ✅ Get all responses/attempts for a specific quiz (For the Quiz Owner)
  Stream<List<Map<String, dynamic>>> getQuizResponses(String quizId) {
    // Note: Requires a Collection Group Index in Firestore for 'attempts'
    return FirebaseFirestore.instance
        .collectionGroup('attempts')
        .where('quizId', isEqualTo: quizId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // User who made the attempt is the parent document ID
        data['respondentId'] = doc.reference.parent.parent?.id;
        return data;
      }).toList();
    });
  }
}
