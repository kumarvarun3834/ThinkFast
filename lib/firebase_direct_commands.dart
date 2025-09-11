import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final CollectionReference _db =
  FirebaseFirestore.instance.collection('databases');

  /// ✅ Create a new database (quiz set)
  Future<String> createDatabase({
    required String user,
    required String title,
    required String description,
    required List<Map<String, Object>> data,
  }) async {
    final docRef = await _db.add({
      'user': user,
      'title': title,
      'description': description,
      'visibility': 'private',
      'data': data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id; // return Firestore document ID
  }

  /// ✅ Read all databases (real-time stream)
  Stream<List<Map<String, dynamic>>> readAllDatabases() {
    return _db.snapshots().map(
          (snapshot) => snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // attach Firestore ID
        return data;
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
  }) async {
    final doc = await _db.doc(docId).get();
    if (doc.exists && doc['user'] == currentUser) {
      Map<String, Object> updatedFields = {};
      if (title != null) updatedFields['title'] = title;
      if (description != null) updatedFields['description'] = description;
      if (data != null) updatedFields['data'] = data;
      if (visibility != null) updatedFields['visibility'] = visibility;

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

  /// ✅ Get specific fields from data array
  // Future<List<T>> getDataField<T>(String docId, String fieldName) async {
  //   final doc = await _db.doc(docId).get();
  //   if (doc.exists) {
  //     final data = List<Map<String, dynamic>>.from(doc['data']);
  //     return data.map<T>((item) => item[fieldName] as T).toList();
  //   } else {
  //     throw Exception("Document not found");
  //   }
  // }
}
