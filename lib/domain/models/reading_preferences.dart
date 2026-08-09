class ReadingPreferences {
  final String? profileId;
  final String fontFamily;
  final int fontSizePx;
  final String lineSpacing;
  final String theme;
  final String margins;

  const ReadingPreferences({
    this.profileId,
    this.fontFamily = 'serif',
    this.fontSizePx = 18,
    this.lineSpacing = 'normal',
    this.theme = 'light',
    this.margins = 'normal',
  });

  ReadingPreferences copyWith({
    String? profileId,
    String? fontFamily,
    int? fontSizePx,
    String? lineSpacing,
    String? theme,
    String? margins,
  }) {
    return ReadingPreferences(
      profileId: profileId ?? this.profileId,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSizePx: fontSizePx ?? this.fontSizePx,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      theme: theme ?? this.theme,
      margins: margins ?? this.margins,
    );
  }
}
