enum ModelTransferState {
  queued,
  downloading,
  verifying,
  completed,
  cancelled,
  failed;

  bool get isActive =>
      this == queued || this == downloading || this == verifying;
}

/// Persisted platform state. Completion means size and SHA-256 were verified.
class ModelTransfer {
  const ModelTransfer({
    required this.id,
    required this.state,
    required this.received,
    required this.total,
    this.retainedBytes = 0,
    this.error,
    this.verification,
    this.token,
  });

  factory ModelTransfer.fromMap(Map<Object?, Object?> map) => ModelTransfer(
    id: map['id'] as String,
    state: ModelTransferState.values.byName(map['state'] as String),
    received: (map['received'] as num).toInt(),
    total: (map['bytes'] as num).toInt(),
    retainedBytes: (map['retained'] as num?)?.toInt() ?? 0,
    error: map['error'] as String?,
    token: map['token'] as String?,
    verification: (map['verification'] as Map?)?.cast<String, dynamic>(),
  );

  final String id;
  final ModelTransferState state;
  final int received;
  final int total;
  final int retainedBytes;
  final String? error;
  final String? token;
  final Map<String, dynamic>? verification;
}
