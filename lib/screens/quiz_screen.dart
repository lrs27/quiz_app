import 'package:flutter/material.dart';
import '/app_configure.dart';
import '../models/question.dart';
import '../services/trivia_service.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Question> _questions = [];
  List<String> _currentAnswers = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _loading = true;
  bool _answered = false;
  String? _selectedAnswer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final questions = await TriviaService.fetchQuestions(
        apiKey: AppConfig.quizApiKey,
        limit: 10,
      );

      setState(() {
        _questions = questions;
        _currentIndex = 0;
        _score = 0;
        _prepareQuestion();
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  void _prepareQuestion() {
    if (_questions.isEmpty) return;
    _currentAnswers = _questions[_currentIndex].shuffledAnswers;
    _answered = false;
    _selectedAnswer = null;
  }

  void _onAnswerTap(String answer) {
    if (_answered) return;

    final correct = _questions[_currentIndex].correctAnswer;
    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      if (answer == correct) _score++;
    });

    Future.delayed(const Duration(milliseconds: 1500), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted) return;

    if (_currentIndex + 1 >= _questions.length) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(score: _score, total: _questions.length),
        ),
      );
      return;
    }

    setState(() {
      _currentIndex++;
      _prepareQuestion();
    });
  }

  Color _buttonColor(String option) {
    if (!_answered) return Colors.white;
    final correct = _questions[_currentIndex].correctAnswer;
    if (option == correct) return Colors.green.shade100;
    if (option == _selectedAnswer) return Colors.red.shade100;
    return Colors.grey.shade100;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                const Text('Error loading questions'),
                const SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadQuestions,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentIndex + 1} / ${_questions.length}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('Score: $_score')),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question.question,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ..._currentAnswers.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton(
                  onPressed: () => _onAnswerTap(option),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _buttonColor(option),
                  ),
                  child: Text(option),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
