class AppConfig {
  static const quizApiKey = String.fromEnvironment('QUIZ_API_KEY');

  static void validateApiKey() {
    if (quizApiKey.isEmpty) {
      throw Exception('Missing QUIZ_API_KEY. Run with --dart-define.');
    }
  }
}
