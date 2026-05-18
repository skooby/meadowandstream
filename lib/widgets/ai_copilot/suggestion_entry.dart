class SuggestionEntry {
  String id;
  String title;
  String description;
  String prompt;
  int? color;

  SuggestionEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.prompt,
    this.color,
  });

  factory SuggestionEntry.fromJson(Map<String, dynamic> json) {
    return SuggestionEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      prompt: json['prompt'] as String,
      color: json['color'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'prompt': prompt,
      'color': color,
    };
  }
}
