import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question.dart';

class TriviaService {
  static const String _baseUrl = 'https://quizapi.io/api/v1/questions';

  /// Fetches QuizAPI questions with optional filters.
  static Future<List<Question>> fetchQuestions({
    required String apiKey,
    int limit = 10,
    int offset = 0,
    String category = 'Programming',
    String difficulty = 'EASY',
    String type = 'MULTIPLE_CHOICE',
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Missing API key');
    }

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
        'category': category,
        'difficulty': difficulty,
        'type': type,
        'random': 'true',
      },
    );

    try {
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $apiKey'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('HTTP error: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception('API returned success=false');
      }

      final results = data['data'] as List? ?? [];

      return results
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Could not load questions: $e');
    }
  }
}
