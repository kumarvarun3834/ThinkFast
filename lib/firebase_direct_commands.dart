import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final CollectionReference _db =
  FirebaseFirestore.instance.collection('databases');

  /// ✅ Create a new database
  Future<void> createDatabase({
    required String user,
    required String title,
    required String description,
    required List<Map<String, Object>> data,
  }) async {
    await _db.add({
      'user': user,
      'title': title,
      'description': description,
      'visibility': 'private',
      'data': data,
    });
  }

  /// ✅ Read all databases (real-time stream)
  Stream<List<Map<String, Object>>> readAllDatabases() {
    return _db.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) {
          var data = doc.data() as Map<String, Object>;
          data['id'] = doc.id; // include document ID
          return data;
        }).toList());
  }

  /// ✅ Update an existing database (only creator can update)
  Future<void> updateDatabase({
    required String docId,
    required String currentUser,
    String? title,
    String? description,
    List<Map<String, Object>>? data,
  }) async {
    final doc = await _db.doc(docId).get();
    if (doc.exists && doc['user'] == currentUser) {
      Map<String, Object> updatedFields = {};
      if (title != null) updatedFields['title'] = title;
      if (description != null) updatedFields['description'] = description;
      if (data != null) updatedFields['data'] = data;

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
}
