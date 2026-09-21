/// Minimal passage model for challenge questions, matching the student app's PassageModel.
class PassageModel {
  int id;
  String content;
  String? imageUrl;
  String? title;

  PassageModel({
    required this.id,
    this.imageUrl,
    required this.content,
    this.title,
  });

  factory PassageModel.fromJson(Map<String, dynamic> json) {
    return PassageModel(
      id: (json['id'] as num).toInt(),
      content: json['content'] ?? '',
      imageUrl: json['image_url'],
      title: json['title'],
    );
  }

  factory PassageModel.fromMap(Map<String, dynamic> map) =>
      PassageModel.fromJson(map);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'image_url': imageUrl,
      'title': title,
    };
  }
}
