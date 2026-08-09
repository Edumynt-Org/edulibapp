class DictionaryDefinition {
  final String definition;
  final String? example;

  const DictionaryDefinition({
    required this.definition,
    this.example,
  });

  factory DictionaryDefinition.fromJson(Map<String, dynamic> json) {
    return DictionaryDefinition(
      definition: json['definition'] as String,
      example: json['example'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'definition': definition,
    'example': example,
  };
}

class DictionaryMeaning {
  final String partOfSpeech;
  final List<DictionaryDefinition> definitions;

  const DictionaryMeaning({
    required this.partOfSpeech,
    required this.definitions,
  });

  factory DictionaryMeaning.fromJson(Map<String, dynamic> json) {
    return DictionaryMeaning(
      partOfSpeech: json['partOfSpeech'] as String? ?? json['partOfSpeech'] ?? '',
      definitions: (json['definitions'] as List?)
          ?.map((e) => DictionaryDefinition.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'partOfSpeech': partOfSpeech,
    'definitions': definitions.map((e) => e.toJson()).toList(),
  };
}

class DictionaryEntry {
  final String word;
  final String? phonetic;
  final List<DictionaryMeaning> meanings;

  const DictionaryEntry({
    required this.word,
    this.phonetic,
    required this.meanings,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      word: json['word'] as String? ?? '',
      phonetic: json['phonetic'] as String?,
      meanings: (json['meanings'] as List?)
          ?.map((e) => DictionaryMeaning.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'phonetic': phonetic,
    'meanings': meanings.map((e) => e.toJson()).toList(),
  };
}
