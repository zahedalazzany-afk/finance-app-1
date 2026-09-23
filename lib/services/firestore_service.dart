import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const int _maxCommitAttempts = 3;
  static const String _deviceIdKey = 'firestore_sync_device_id';
  static const String _lastSyncedPrefix = 'firestore_last_synced_';

  static String _canonicalJson(Map<String, dynamic> data) {
    dynamic normalize(dynamic value) {
      if (value is Map) {
        final keys = value.keys.map((e) => e.toString()).toList()..sort();
        return {for (final key in keys) key: normalize(value[key])};
      }
      if (value is List) return value.map(normalize).toList();
      return value;
    }

    return jsonEncode(normalize(data));
  }

  static Future<String?> _lastSynced(String collection, String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_lastSyncedPrefix${collection}_$id');
  }

  static Future<void> _rememberSynced(
      String collection, String id, String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_lastSyncedPrefix${collection}_$id', json);
  }

  static Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 32)}';
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

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
    final deviceId = await _deviceId();
    final existing = await col.get();
    final existingById = {for (final d in existing.docs) d.id: d};
    final newIds = <String>{};
    final writes = <({DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data})>[];

    for (final item in items) {
      final map = Map<String, dynamic>.from(toJson(item));
      final rawId = map['id'];
      if (rawId is! String || rawId.isEmpty) continue;
      newIds.add(rawId);
      final currentJson = _canonicalJson(map);
      final cloudMap = existingById[rawId]?.data();
      final cloudDeleted = cloudMap?['__deleted'] == true;
      final cloudJson = cloudMap == null || cloudDeleted
          ? null
          : _canonicalJson(Map<String, dynamic>.from(cloudMap)
            ..remove('__writerId')
            ..remove('__updatedAt')
            ..remove('__deleted'));
      final lastSyncedJson = await _lastSynced(collection, rawId);

      if (cloudDeleted) {
        final cloudUpdated = cloudMap?['__updatedAt'];
        final lastSyncPrefs = await SharedPreferences.getInstance();
        final lastSyncAt = lastSyncPrefs.getInt(
            '$_lastSyncedPrefix${collection}_${rawId}_at');
        if (lastSyncedJson != null &&
            currentJson == lastSyncedJson &&
            (lastSyncAt == null ||
                cloudUpdated is! Timestamp ||
                cloudUpdated.millisecondsSinceEpoch > lastSyncAt)) {
          continue;
        }
        if (lastSyncAt != null &&
            cloudUpdated is Timestamp &&
            cloudUpdated.millisecondsSinceEpoch > lastSyncAt) {
          continue;
        }
      }

      if (cloudJson != null && cloudJson == currentJson) {
        await _rememberSynced(collection, rawId, currentJson);
        continue;
      }

      // إذا لم يتغير السجل محلياً منذ آخر مزامنة، بينما تغير في السحابة،
      // فهذه نسخة أحدث من جهاز آخر ولا يجوز استبدالها بنسخة محلية قديمة.
      if (cloudJson != null &&
          lastSyncedJson != null &&
          currentJson == lastSyncedJson) {
        continue;
      }

      // عند وجود تعارض حقيقي (تغير محلي وتغير سحابي) نتحقق من وقت آخر
      // مزامنة معروف. إذا كانت السحابة أحدث من آخر نسخة تعاملنا معها،
      // نحتفظ بالنسخة السحابية بدلاً من الكتابة فوقها.
      final cloudUpdated = cloudMap?['__updatedAt'];
      if (cloudJson != null &&
          lastSyncedJson != null &&
          cloudUpdated is Timestamp) {
        final lastSyncPrefs = await SharedPreferences.getInstance();
        final lastSyncAt = lastSyncPrefs.getInt(
            '$_lastSyncedPrefix${collection}_${rawId}_at');
        if (lastSyncAt != null &&
            cloudUpdated.millisecondsSinceEpoch > lastSyncAt) {
          continue;
        }
      }

      writes.add((ref: col.doc(rawId), data: {...map, '__writerId': deviceId}));
    }
    for (final doc in existing.docs) {
      if (!newIds.contains(doc.id) && doc.data()['__deleted'] != true) {
        writes.add((
          ref: doc.reference,
          data: <String, dynamic>{
            '__delete__': true,
            '__deleted': true,
            '__writerId': deviceId,
          },
        ));
      }
    }

    for (var start = 0; start < writes.length; start += _maxBatchOperations) {
      final end = (start + _maxBatchOperations).clamp(0, writes.length);
      Object? lastError;
      for (var attempt = 1; attempt <= _maxCommitAttempts; attempt++) {
        try {
          // أنشئ WriteBatch جديدًا في كل محاولة؛ إعادة استخدام نفس الدفعة
          // بعد فشل commit قد يترك حالة داخلية غير متوقعة في بعض إصدارات
          // SDK، بينما إعادة بنائها تضمن أن كل محاولة تبدأ بحالة نظيفة.
          final batch = FirebaseFirestore.instance.batch();
          for (final entry in writes.sublist(start, end)) {
            if (entry.data['__delete__'] == true) {
              batch.set(
                entry.ref,
                {
                  '__deleted': true,
                  '__writerId': entry.data['__writerId'],
                  '__updatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
              );
            } else {
              batch.set(
                entry.ref,
                {...entry.data, '__updatedAt': FieldValue.serverTimestamp()},
                SetOptions(merge: true),
              );
            }
          }
          await batch.commit();
          lastError = null;
          break;
        } catch (e) {
          lastError = e;
          if (attempt == _maxCommitAttempts) rethrow;
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
        }
      }
      if (lastError != null) throw lastError!;
      for (final entry in writes.sublist(start, end)) {
        if (entry.data['__delete__'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('$_lastSyncedPrefix${collection}_${entry.ref.id}');
          await prefs.setInt(
            '$_lastSyncedPrefix${collection}_${entry.ref.id}_at',
            DateTime.now().toUtc().millisecondsSinceEpoch,
          );
          continue;
        }
        final map = Map<String, dynamic>.from(entry.data)
          ..remove('__writerId')
          ..remove('__updatedAt');
        await _rememberSynced(collection, entry.ref.id, _canonicalJson(map));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          '$_lastSyncedPrefix${collection}_${entry.ref.id}_at',
          DateTime.now().toUtc().millisecondsSinceEpoch,
        );
      }
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
    final deviceId = await _deviceId();
    final existing = await col.get();
    final existingIds = existing.docs.map((d) => d.id).toSet();
    final writes = <({DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data})>[];

    for (final item in items) {
      final map = Map<String, dynamic>.from(toJson(item));
      final rawId = map['id'];
      if (rawId is! String || rawId.isEmpty) continue;
      // التهيئة الأولى لا تستبدل سجلاً موجوداً في السحابة؛ النسخة السحابية
      // قد تكون أحدث من البيانات المحلية لهذا الجهاز.
      if (existingIds.contains(rawId)) continue;
      writes.add((ref: col.doc(rawId), data: {...map, '__writerId': deviceId}));
    }

    for (var start = 0; start < writes.length; start += _maxBatchOperations) {
      final end = (start + _maxBatchOperations).clamp(0, writes.length);
      Object? lastError;
      for (var attempt = 1; attempt <= _maxCommitAttempts; attempt++) {
        try {
          final batch = FirebaseFirestore.instance.batch();
          for (final entry in writes.sublist(start, end)) {
            batch.set(
              entry.ref,
              {...entry.data, '__updatedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true),
            );
          }
          await batch.commit();
          lastError = null;
          break;
        } catch (e) {
          lastError = e;
          if (attempt == _maxCommitAttempts) rethrow;
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
        }
      }
      if (lastError != null) throw lastError!;
      for (final entry in writes.sublist(start, end)) {
        final map = Map<String, dynamic>.from(entry.data)
          ..remove('__writerId')
          ..remove('__updatedAt');
        await _rememberSynced(collection, entry.ref.id, _canonicalJson(map));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          '$_lastSyncedPrefix${collection}_${entry.ref.id}_at',
          DateTime.now().toUtc().millisecondsSinceEpoch,
        );
      }
    }
  }

  /// تنزيل مجموعة كاملة من المنصة حيث كل وثيقة سجل واحد.
  static Future<List<Map<String, dynamic>>> loadCollection(
      String collection) async {
    final snap = await _sub(collection).get();
    return snap.docs
        .where((d) => d.data()['__deleted'] != true)
        .map((d) {
          final data = Map<String, dynamic>.from(d.data())
            ..remove('__writerId')
            ..remove('__updatedAt')
            ..remove('__deleted');

          // هوية السجل الحقيقية هي معرّف وثيقة Firestore. إذا كان
          // حقل id مفقودًا أو تالفًا أو لا يطابق معرّف الوثيقة، نستخدم
          // معرّف الوثيقة حتى لا تؤدي بيانات سحابية غير صحيحة إلى إنشاء
          // سجل بمعرّف مختلف أو الكتابة فوق سجل محلي آخر أثناء الاستعادة.
          data['id'] = d.id;
          return data;
        })
        .toList();
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
