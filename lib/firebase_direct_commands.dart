import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final CollectionReference _db =
  FirebaseFirestore.instance.collection('databases');

  /// ✅ Create a new database (quiz set)
  Future<String> createDatabase({
    required String user,
    required String title,
    required String description,
    required String visibility,
    required List<Map<String, Object>> data,
    required String time, // ⏱️ new field
  }) async {
    // Convert String → int
    int timeInMinutes = int.tryParse(time) ?? 0;

    // Convert minutes → seconds
    int timeInSeconds = timeInMinutes * 60;
    final docRef = await _db.add({
      'user': user,
      'title': title,
      'description': description,
      'visibility': visibility,
      'data': data,
      'time': timeInSeconds, // ⏱️ save time (e.g. seconds/minutes)
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id; // return Firestore document ID
  }

  /// ✅ Read all databases (real-time stream) with optional visibility filter
  Stream<List<Map<String, dynamic>>> readAllDatabases({String? visibility}) {
    return _db.snapshots().map(
          (snapshot) => snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // attach Firestore ID
        return data;
      }).where((data) {
        // Filter if visibility is provided
        if (visibility != null) {
          return data['visibility'] == visibility;
        }
        return true; // include all if no filter
      }).toList(),
    );
  }

  /// ✅ Update an existing database (only creator can update)
  Future<void> updateDatabase({
    required String docId,
    required String currentUser,
    String? title,
    String? description,
    List<Map<String, Object>>? data,
    String? visibility,
    String? time, // ⏱️ updatable field
  }) async {
    final doc = await _db.doc(docId).get();
    if (doc.exists && doc['user'] == currentUser) {
      Map<String, Object> updatedFields = {};
      if (title != null) updatedFields['title'] = title;
      if (description != null) updatedFields['description'] = description;
      if (data != null) updatedFields['data'] = data;
      if (visibility != null) updatedFields['visibility'] = visibility;
      if (time != null) updatedFields['time'] = time*60; // ⏱️ update time

      updatedFields['updatedAt'] = FieldValue.serverTimestamp();

      await _db.doc(docId).update(updatedFields);
    } else {
      throw Exception('Only the creator can update this database');
    }
  }

  /// ✅ Delete a database (only creator can delete)
  Future<void> deleteDatabase({
    required String docId,
    required String currentUser,
  }) async {
    final doc = await _db.doc(docId).get();
    if (doc.exists && doc['user'] == currentUser) {
      await _db.doc(docId).delete();
    } else {
      throw Exception('Only the creator can delete this database');
    }
  }

  /// ✅ Read a single database (quiz) by docId
  Future<Map<String, dynamic>> readDatabase(String docId) async {
    final doc = await _db.doc(docId).get();
    if (!doc.exists) throw Exception("Quiz not found");

    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id; // attach Firestore ID
    return data;
  }
}
