enum EntryWriteFailureKind { unavailable, changed, deleted, busy }

class EntryWriteFailure extends StateError {
  EntryWriteFailure(this.kind) : super('Entry write failed');
  final EntryWriteFailureKind kind;

  @override
  String toString() => 'Entry write failed: ${kind.name}';
}
