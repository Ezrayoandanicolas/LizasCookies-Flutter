enum SyncStatus { syncing, success, failed, skipped }

enum SyncType { order, stock, other }

class SyncHistoryItem {
  final String id;
  final SyncType type;
  final SyncStatus status;
  final String endpoint;
  final String method;
  final String description;
  final String? error;
  final int? httpStatusCode;
  final DateTime timestamp;
  final int retryCount;
  final Map<String, dynamic>? requestBody;

  SyncHistoryItem({
    required this.id,
    required this.type,
    required this.status,
    required this.endpoint,
    this.method = 'POST',
    required this.description,
    this.error,
    this.httpStatusCode,
    required this.timestamp,
    this.retryCount = 0,
    this.requestBody,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'status': status.name,
    'endpoint': endpoint,
    'method': method,
    'description': description,
    'error': error,
    'httpStatusCode': httpStatusCode,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
    'requestBody': requestBody,
  };

  factory SyncHistoryItem.fromJson(Map<String, dynamic> json) => SyncHistoryItem(
    id: json['id'] ?? '',
    type: SyncType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => SyncType.other,
    ),
    status: SyncStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => SyncStatus.failed,
    ),
    endpoint: json['endpoint'] ?? '',
    method: json['method'] ?? 'POST',
    description: json['description'] ?? '',
    error: json['error'],
    httpStatusCode: json['httpStatusCode'],
    timestamp: DateTime.parse(json['timestamp']),
    retryCount: json['retryCount'] ?? 0,
    requestBody: json['requestBody'],
  );
}
