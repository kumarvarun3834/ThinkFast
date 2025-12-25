import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final CollectionReference _db =
  FirebaseFirestore.instance.collection('databases');

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
    final docRef = await _db.add({
      'creatorId': creatorId,
      'user': user,
      'title': title,
      'description': description,
      'visibility': visibility,
      'data': data,
      'time': time * 60, // store seconds
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id; // return Firestore document ID
  }

  /// ✅ Read all databases (real-time stream) with optional visibility filter
  Stream<List<Map<String, dynamic>>> readAllDatabases({String? visibility}) {
    Query query = _db;
    if (visibility != null) {
      query = query.where('visibility', isEqualTo: visibility);
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

    final Map<String, Object> updates = {};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (data != null) updates['data'] = data;
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

  /// ✅ Read a single database (quiz) by docId
  Future<Map<String, dynamic>> readDatabase(String docId) async {
    final doc = await _db.doc(docId).get();
    if (!doc.exists) throw Exception("Quiz not found");

    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return data;
  }
}
