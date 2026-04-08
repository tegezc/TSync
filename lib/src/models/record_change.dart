enum ChangeType { added, modified, deleted }

class RecordChange {
  final String id;
  final ChangeType type;
  final Map<String, dynamic>? data;

  RecordChange({
    required this.id,
    required this.type,
    this.data,
  });
}