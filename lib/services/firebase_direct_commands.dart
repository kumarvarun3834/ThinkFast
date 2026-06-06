import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class DatabaseService {
  final CollectionReference _db = FirebaseFirestore.instance.collection(
    'databases',
  );
  final CollectionReference _responses = FirebaseFirestore.instance.collection(
    'responses',
  );
  final CollectionReference _users = FirebaseFirestore.instance.collection(
    'users',
  );
  final CollectionReference _answerKeys = FirebaseFirestore.instance.collection(
    'answer_keys',
  );
  final CollectionReference _questions = FirebaseFirestore.instance.collection(
    'quiz_questions',
  );

  /// ✅ Create a new user profile
  Future<void> createUserProfile({
    required String uid,
    required String email,
    String? name,
  }) async {
    // 1. Public Profile (Accessible by anyone)
    await _users.doc(uid).set({
      'name': name ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
    });

    // 2. Private Data (Accessible only by the owner)
    await _users.doc(uid).collection('private').doc('details').set({
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Fetch user profile by UID
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return null;
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      return null; // Return null instead of throwing to prevent UI crashes
    }
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

    return {'data': transformedData, 'answerkeys': answerKeys};
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

    // 1. Create the Quiz document in 'databases' collection (Metadata only)
    final docRef = await _db.add({
      'creatorId': creatorId,
      'user': user,
      'title': title,
      'description': description,
      'visibility': visibility,
      'time': time * 60, // store seconds
      'isDeleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Create the Questions document in 'quiz_questions' collection (same ID)
    await _questions.doc(docRef.id).set({
      'quizId': docRef.id,
      'data': transformed['data'],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Create the Answer Key in 'answer_keys' collection (same ID)
    await _answerKeys.doc(docRef.id).set({
      'quizId': docRef.id,
      'answerkeys': transformed['answerkeys'], // [{q, a}, ...]
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// ✅ Read databases (real-time stream) with filters
  /// ✅ Read databases (real-time stream) with filters
  Stream<List<Map<String, dynamic>>> readAllDatabases({
    bool showMyQuizzes = false,
    String? creatorId,
  }) {
    // 1. Start with the base query and exclude deleted items
    // NOTE: This may require a Firestore composite index which the console will provide a link for in logs
    Query query = _db.where('isDeleted', isEqualTo: false);

    if (showMyQuizzes && creatorId != null) {
      query = query.where('creatorId', isEqualTo: creatorId);
    } else {
      query = query.where('visibility', isEqualTo: 'public');
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
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

      // Update questions in separate collection
      await _questions.doc(docId).set({
        'data': transformed['data'],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update answers in separate collection
      await _answerKeys.doc(docId).set({
        'answerkeys': transformed['answerkeys'],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (visibility != null) updates['visibility'] = visibility;
    if (time != null) updates['time'] = time * 60;

    updates['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.update(updates);
  }

  /// ✅ Delete a database (Soft Delete)
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

    await docRef.update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Read a single database (quiz) by docId - Includes questions from separate collection
  Future<Map<String, dynamic>> readDatabase(String docId) async {
    final doc = await _db.doc(docId).get();
    if (!doc.exists ||
        (doc.data() as Map<String, dynamic>)['isDeleted'] == true) {
      throw Exception("Quiz not found");
    }

    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;

    // Fetch questions from the separate collection
    final questionDoc = await _questions.doc(docId).get();
    if (questionDoc.exists) {
      data['data'] = (questionDoc.data() as Map<String, dynamic>)['data'];
    } else {
      data['data'] = []; // Fallback if questions are missing
    }

    return data;
  }

  /// ✅ Fetch ONLY the correct answers for a quiz (to be called on submit or edit)
  Future<Map<String, List<String>>> getQuizAnswers(
    String docId,
    String userId, {
    String? from,
    int? totalQuestions,
    Map<String, dynamic>? userAnswers,
  }) async {
    final quizDoc = await _db.doc(docId).get();
    if (!quizDoc.exists ||
        (quizDoc.data() as Map<String, dynamic>)['isDeleted'] == true) {
      throw Exception("Quiz not found");
    }
    final bool isCreator = quizDoc['creatorId'] == userId;

    final keyDoc = await _answerKeys.doc(docId).get();
    if (!keyDoc.exists) throw Exception("Answers not found");

    final keyData = keyDoc.data() as Map<String, dynamic>;
    final Map<String, List<String>> correctKey = {};
    if (keyData['answerkeys'] != null && keyData['answerkeys'] is List) {
      for (var entry in keyData['answerkeys']) {
        if (entry is Map) {
          final qUid = entry['q'].toString();
          final optUid = entry['a'].toString();
          correctKey.putIfAbsent(qUid, () => []).add(optUid);
        }
      }
    }

    if (from == 'quizform') {
      // 🛡️ Editor Mode: Verify creator
      if (!isCreator) {
        throw Exception("Only creator can access answers in editor");
      }
    } else {
      // 🚀 Taker Mode: Auto-submit and save attempt data
      if (userAnswers != null && totalQuestions != null) {
        // Calculate score
        int score = 0;
        userAnswers.forEach((qUid, selections) {
          final correct = correctKey[qUid] ?? [];
          final List selected = selections is List
              ? selections
              : [selections.toString()];

          if (selected.isNotEmpty &&
              selected.length == correct.length &&
              selected.every((s) => correct.contains(s))) {
            score += 4; // Correct
          } else if (selected.isNotEmpty) {
            score -= 1; // Wrong
          }
        });

        // Save Attempt
        await submitAttempt(
          userId: userId,
          quizId: docId,
          quizTitle: quizDoc['title'] ?? 'Untitled Quiz',
          score: score,
          totalQuestions: totalQuestions,
          answers: userAnswers,
        );
      } else {
        // Fallback for direct result viewing: Check if attempt exists (Creators bypass)
        if (!isCreator) {
          final attempts = await _responses
              .where('userId', isEqualTo: userId)
              .where('quizId', isEqualTo: docId)
              .limit(1)
              .get();

          if (attempts.docs.isEmpty) {
            throw Exception("Access Denied: You must attempt the quiz first.");
          }
        }
      }
    }

    return correctKey;
  }

  /// ✅ Submit a quiz attempt (Flat collection with foreign keys)
  Future<String> submitAttempt({
    required String userId,
    required String quizId,
    required String quizTitle,
    required int score,
    required int totalQuestions,
    required Map<String, dynamic>
    answers, // Map of questionUid -> chosen optUid
  }) async {
    // 1. Reference in Flat global collection
    final attemptRef = _responses.doc();

    final attemptData = {
      'userId': userId,
      'quizId': quizId,
      'quizTitle': quizTitle,
      'score': score,
      'totalQuestions': totalQuestions,
      'answers': answers,
      'status': 1, // Default status to 1 (Completed)
      'timestamp': FieldValue.serverTimestamp(),
    };

    await attemptRef.set(attemptData);

    // 2. Update user's last active in profiles (Foreign Key lookup not needed, direct ID)
    await _users.doc(userId).set({
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return attemptRef.id;
  }

  /// ✅ Update score in an attempt
  Future<void> updateAttemptScore({
    required String userId,
    required String attemptId,
    required int score,
  }) async {
    await _responses.doc(attemptId).update({'score': score});
  }

  /// ✅ Read all attempts for a specific user (Query by userId Foreign Key)
  Stream<List<Map<String, dynamic>>> getUserAttempts(String userId) {
    return _responses
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  /// ✅ Get all responses/attempts for a specific quiz (Query by quizId Foreign Key)
  Stream<List<Map<String, dynamic>>> getQuizResponses(String quizId) {
    return _responses
        .where('quizId', isEqualTo: quizId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }
}
