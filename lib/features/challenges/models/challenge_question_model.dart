import 'dart:convert';

class ChallengeQuestionModel {
  final String id;
  final String setId;
  final int orderIndex;
  final String questionText;
  final List<String> choices;
  final String correctChoice;
  final String explanation;
  final String explanationEn;
  final String explanationAm;
  final String? imageUrl;

  ChallengeQuestionModel({
    required this.id,
    required this.setId,
    required this.orderIndex,
    required this.questionText,
    required this.choices,
    this.correctChoice = '',
    this.explanation = '',
    this.explanationEn = '',
    this.explanationAm = '',
    this.imageUrl,
  });

  bool get hasExplanation => explanation.isNotEmpty || explanationEn.isNotEmpty || explanationAm.isNotEmpty;
  bool get hasBothExplanations => explanationEn.isNotEmpty && explanationAm.isNotEmpty;

  factory ChallengeQuestionModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedChoices = [];
    final rawChoices = json['choices'];
    if (rawChoices is List) {
      parsedChoices = rawChoices.map((e) {
        if (e is Map) {
          return e['text']?.toString() ?? e.values.first?.toString() ?? '';
        }
        return e.toString();
      }).toList();
    } else if (rawChoices is String) {
      try {
        final decoded = jsonDecode(rawChoices);
        if (decoded is List) {
          parsedChoices = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        parsedChoices = [rawChoices];
      }
    }

    final expEn = json['explanation_en']?.toString() ?? '';
    final expAm = json['explanation_am']?.toString() ?? '';
    final rawExp = json['explanation']?.toString() ?? '';
    final defaultExp = rawExp.isNotEmpty ? rawExp : (expEn.isNotEmpty ? expEn : expAm);

    return ChallengeQuestionModel(
      id: json['id']?.toString() ?? '',
      setId: json['set_id']?.toString() ?? '',
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 1,
      questionText: json['question_text']?.toString() ?? '',
      choices: parsedChoices,
      correctChoice: json['correct_choice']?.toString() ?? '',
      explanation: defaultExp,
      explanationEn: expEn.isNotEmpty ? expEn : rawExp,
      explanationAm: expAm,
      imageUrl: json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final defaultExp = explanation.isNotEmpty ? explanation : (explanationEn.isNotEmpty ? explanationEn : explanationAm);
    return {
      if (id.isNotEmpty) 'id': id,
      'set_id': setId,
      'order_index': orderIndex,
      'question_text': questionText,
      'choices': choices,
      'correct_choice': correctChoice,
      'explanation': defaultExp,
      if (explanationEn.isNotEmpty) 'explanation_en': explanationEn,
      if (explanationAm.isNotEmpty) 'explanation_am': explanationAm,
      'image_url': imageUrl,
    };
  }

  ChallengeQuestionModel copyWith({
    String? id,
    String? setId,
    int? orderIndex,
    String? questionText,
    List<String>? choices,
    String? correctChoice,
    String? explanation,
    String? explanationEn,
    String? explanationAm,
    String? imageUrl,
  }) {
    return ChallengeQuestionModel(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      orderIndex: orderIndex ?? this.orderIndex,
      questionText: questionText ?? this.questionText,
      choices: choices ?? this.choices,
      correctChoice: correctChoice ?? this.correctChoice,
      explanation: explanation ?? this.explanation,
      explanationEn: explanationEn ?? this.explanationEn,
      explanationAm: explanationAm ?? this.explanationAm,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
