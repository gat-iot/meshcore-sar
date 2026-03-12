class SavedContactGroup {
  final String id;
  final String sectionKey;
  final String label;
  final String query;
  final DateTime createdAt;

  const SavedContactGroup({
    required this.id,
    required this.sectionKey,
    required this.label,
    required this.query,
    required this.createdAt,
  });

  SavedContactGroup copyWith({
    String? id,
    String? sectionKey,
    String? label,
    String? query,
    DateTime? createdAt,
  }) {
    return SavedContactGroup(
      id: id ?? this.id,
      sectionKey: sectionKey ?? this.sectionKey,
      label: label ?? this.label,
      query: query ?? this.query,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
