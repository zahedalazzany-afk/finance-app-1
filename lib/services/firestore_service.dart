import 'package:cloud_firestore/cloud_firestore.dart';

/// طبقة مزامنة Cloud Firestore.
///
/// تخزّن كل مجموعة (entities) كسجلات مستقلة تحت الجذر [root]
/// بالشكل `finance_data/<collection>/items/<id>`، حيث يُخزَّن
/// كل سجل بنفس تنسيق `toJson()` المستخدم محلياً (تواريخ نصية ISO8601)
/// لذا لا حاجة لتحويل `Timestamp`. هذا يجعل الوثائق متوافقة تماماً
/// مع `fromJson()` الخاص بكل نموذج.
class FirestoreService {
  FirestoreService._();

  static const String root = 'finance_data';

  static const int _maxBatchOperations = 450;

  static CollectionReference<Map<String, dynamic>> _sub(
      String collection) {
    return FirebaseFirestore.instance
        .collection(root)
        .doc(collection)
        .collection('items');
  }

  /// رفع مجموعة كاملة إلى المنصة. يكتب كل سجل بوثيقة معرّفة بـ `id`
  /// ويحذف الوثائق المفقودة محلياً.
  static Future<void> saveCollection<T>(
    String collection,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final col = _sub(collection);
    final existing = await col.get();
    final existingIds = existing.docs.map((d) => d.id).toSet();
    final newIds = <String>{};
    final writes = <({DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data})>[];

    for (final item in items) {
      final map = Map<String, dynamic>.from(toJson(item));
      final rawId = map['id'];
      if (rawId is! String || rawId.isEmpty) continue;
      newIds.add(rawId);
      writes.add((ref: col.doc(rawId), data: map));
    }
    for (final id in existingIds.difference(newIds)) {
      writes.add((ref: col.doc(id), data: const <String, dynamic>{'__delete__': true}));
    }

    for (var start = 0; start < writes.length; start += _maxBatchOperations) {
      final end = (start + _maxBatchOperations).clamp(0, writes.length);
      final batch = FirebaseFirestore.instance.batch();
      for (final entry in writes.sublist(start, end)) {
        if (entry.data['__delete__'] == true) {
          batch.delete(entry.ref);
        } else {
          batch.set(entry.ref, entry.data, SetOptions(merge: true));
        }
      }
      await batch.commit();
    }
  }

  /// رفع سجلات محلية إلى المنصة بدون حذف أي سجل موجود على المنصة.
  /// يستخدم أثناء التهيئة الأولى/الترحيل حتى لا يؤدي اختلاف بيانات جهازين
  /// إلى حذف سجلات موجودة على جهاز آخر.
  static Future<void> mergeCollection<T>(
    String collection,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final col = _sub(collection);
    final writes = <({DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data})>[];

    for (final item in items) {
      final map = Map<String, dynamic>.from(toJson(item));
      final rawId = map['id'];
      if (rawId is! String || rawId.isEmpty) continue;
      writes.add((ref: col.doc(rawId), data: map));
    }

    for (var start = 0; start < writes.length; start += _maxBatchOperations) {
      final end = (start + _maxBatchOperations).clamp(0, writes.length);
      final batch = FirebaseFirestore.instance.batch();
      for (final entry in writes.sublist(start, end)) {
        batch.set(entry.ref, entry.data, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  /// تنزيل مجموعة كاملة من المنصة حيث كل وثيقة سجل واحد.
  static Future<List<Map<String, dynamic>>> loadCollection(
      String collection) async {
    final snap = await _sub(collection).get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// حذف كل الوثائق ضمن مجموعة (للإعدادات الطارئة أو إعادة البناء).
  static Future<void> clearCollection(String collection) async {
    final snap = await _sub(collection).get();
    if (snap.docs.isEmpty) return;
    for (var start = 0; start < snap.docs.length; start += _maxBatchOperations) {
      final end = (start + _maxBatchOperations).clamp(0, snap.docs.length);
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs.sublist(start, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
