class Alert {
  final int? id;
  final String nodeId;
  final String message;
  final double value;
  final String timestamp;

  Alert({
    this.id,
    required this.nodeId,
    required this.message,
    required this.value,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'node_id': nodeId,
        'message': message,
        'value': value,
        'timestamp': timestamp,
      };

  factory Alert.fromMap(Map<String, dynamic> map) => Alert(
        id: map['id'] as int?,
        nodeId: map['node_id'] as String,
        message: map['message'] as String,
        value: (map['value'] as num).toDouble(),
        timestamp: map['timestamp'] as String,
      );
}