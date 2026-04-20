import 'package:flutter/material.dart';
import 'app_configure.dart';
import 'screens/quiz_screen.dart';
import 'services/trivia_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const apiKey = String.fromEnvironment('QUIZ_API_KEY');
  if (apiKey.isEmpty) {
    throw Exception('Missing QUIZ_API_KEY. Use --dart-define.');
  }
  final qs = await TriviaService.fetchQuestions(apiKey: apiKey, limit: 10);
  for (final q in qs) {
    print(q.question);
    print('  Correct: ${q.correctAnswer}');
  }
  runApp(const QuizApp());
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const QuizScreen(),
    );
  }
}
