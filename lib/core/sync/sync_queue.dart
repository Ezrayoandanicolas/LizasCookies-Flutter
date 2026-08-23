import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';

class SyncQueueItem {
  final String id;
  final String type;
  final String endpoint;
  final String method;
  final Map<String, dynamic>? body;
  final DateTime createdAt;
  int retryCount;

  SyncQueueItem({
    required this.id,
    required this.type,
    required this.endpoint,
    required this.method,
    this.body,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'endpoint': endpoint,
        'method': method,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String,
      type: json['type'] as String,
      endpoint: json['endpoint'] as String,
      method: json['method'] as String,
      body: json['body'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    );
  }
}

enum SyncQueueType { order, stockAdd, stockRemove, expense }

class SyncQueue {
  static const String _boxKey = 'items';

  Box get _box => Hive.box(AppConstants.syncQueueBoxName);

  List<SyncQueueItem> getAll() {
    final raw = _box.get(_boxKey);
    if (raw == null) return [];

    final list = jsonDecode(raw as String) as List;
    return list.map((e) => SyncQueueItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  void _saveAll(List<SyncQueueItem> items) {
    final json = items.map((e) => e.toJson()).toList();
    _box.put(_boxKey, jsonEncode(json));
  }

  String enqueue({
    required SyncQueueType type,
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
  }) {
    final items = getAll();
    final item = SyncQueueItem(
      id: const Uuid().v4(),
      type: type.name,
      endpoint: endpoint,
      method: method,
      body: body,
      createdAt: DateTime.now(),
    );
    items.add(item);
    _saveAll(items);
    return item.id;
  }

  bool remove(String id) {
    final items = getAll();
    final before = items.length;
    items.removeWhere((e) => e.id == id);
    if (items.length < before) {
      _saveAll(items);
      return true;
    }
    return false;
  }

  void clear() {
    _box.delete(_boxKey);
  }

  bool hasPending() {
    return getAll().isNotEmpty;
  }
}

final syncQueueProvider = Provider<SyncQueue>((ref) => SyncQueue());
