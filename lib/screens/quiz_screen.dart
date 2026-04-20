import 'package:flutter/material.dart';

import '../app_configure.dart';
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

  // ---------------------------
  // ADAPTIVE DIFFICULTY ENGINE
  // ---------------------------
  List<bool> _recentCorrect = []; // last 3 answers
  List<int> _recentTimes = []; // last 3 response times (ms)
  int _proficiency = 0; // confidence score
  int _momentum = 0; // improvement or decline
  DateTime? _questionStartTime; // track response time
  String _currentDifficulty = "easy"; // default difficulty

  // Difficulty smoothing
  String _lastSuggestedDifficulty = "easy";
  int _difficultyStability = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  // ---------------------------
  // LOAD QUESTIONS
  // ---------------------------
  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final questions = await TriviaService.fetchQuestions(
        apiKey: AppConfig.quizApiKey,
        limit: 10,
        difficulty: _currentDifficulty,
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
        if (error.toString().contains("SocketException")) {
          _errorMessage = "No internet connection. Please check your network.";
        } else {
          _errorMessage = error.toString();
        }
        _loading = false;
      });
    }
  }

  // ---------------------------
  // PREPARE QUESTION
  // ---------------------------
  void _prepareQuestion() {
    if (_questions.isEmpty) return;
    _currentAnswers = _questions[_currentIndex].shuffledAnswers;
    _answered = false;
    _selectedAnswer = null;
    _questionStartTime = DateTime.now();
  }

  // ---------------------------
  // DIFFICULTY SCORING
  // ---------------------------
  int _pointsForDifficulty(String difficulty) {
    switch (difficulty.toUpperCase()) {
      case 'HARD':
        return 3;
      case 'MEDIUM':
        return 2;
      default:
        return 1;
    }
  }

  // ---------------------------
  // ADAPTIVE DIFFICULTY LOGIC
  // ---------------------------
  String _chooseNextDifficulty() {
    String suggested;

    // Streak rules
    if (_recentCorrect.length == 3 &&
        _recentCorrect.where((c) => c).length == 3) {
      suggested = "hard";
    } else if (_recentCorrect.length == 3 &&
        _recentCorrect.where((c) => !c).length >= 2) {
      suggested = "easy";
    } else if (_proficiency >= 3) {
      suggested = "hard";
    } else if (_proficiency <= -2) {
      suggested = "easy";
    } else {
      suggested = "medium";
    }

    // Momentum influence
    if (_momentum >= 2) suggested = "hard";
    if (_momentum <= -2) suggested = "easy";

    // Difficulty smoothing: require 2 consecutive suggestions
    if (suggested == _lastSuggestedDifficulty) {
      _difficultyStability++;
    } else {
      _difficultyStability = 1;
      _lastSuggestedDifficulty = suggested;
    }

    if (_difficultyStability >= 2) {
      return suggested;
    }

    return _currentDifficulty; // stay until stable
  }

  // ---------------------------
  // ANSWER TAP
  // ---------------------------
  void _onAnswerTap(String answer) {
    if (_answered) return;

    final q = _questions[_currentIndex];
    final correct = q.correctAnswer;
    final isCorrect = answer == correct;

    // Track correctness
    _recentCorrect.add(isCorrect);
    if (_recentCorrect.length > 3) _recentCorrect.removeAt(0);

    // Track response time
    final elapsed = DateTime.now()
        .difference(_questionStartTime!)
        .inMilliseconds;
    _recentTimes.add(elapsed);
    if (_recentTimes.length > 3) _recentTimes.removeAt(0);

    // Confidence scoring
    _proficiency += isCorrect ? 2 : -1;
    if (elapsed < 2000) _proficiency += 1;
    if (elapsed > 6000) _proficiency -= 1;
    if (elapsed > 4000 && elapsed < 6000) _proficiency -= 1;

    // Clamp score
    _proficiency = _proficiency.clamp(-5, 5);

    // Momentum scoring
    if (isCorrect) {
      _momentum += 1;
    } else {
      _momentum -= 1;
    }
    _momentum = _momentum.clamp(-3, 3);

    // Choose next difficulty
    _currentDifficulty = _chooseNextDifficulty();

    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      if (isCorrect) {
        _score += _pointsForDifficulty(q.difficulty);
      }
    });

    // Feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isCorrect ? 'Correct!' : 'Wrong! Correct: $correct'),
        backgroundColor: isCorrect
            ? Colors.green.shade700
            : Colors.red.shade700,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  // ---------------------------
  // NEXT QUESTION
  // ---------------------------
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

  // ---------------------------
  // BUTTON COLORS
  // ---------------------------
  Color _buttonColor(String option) {
    if (!_answered) return Colors.white;
    final correct = _questions[_currentIndex].correctAnswer;
    if (option == correct) return Colors.green.shade100;
    if (option == _selectedAnswer) return Colors.red.shade100;
    return Colors.grey.shade100;
  }

  // ---------------------------
  // BUILD UI
  // ---------------------------
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

    Color diffColor = {
      "easy": Colors.green,
      "medium": Colors.orange,
      "hard": Colors.red,
    }[_currentDifficulty]!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentIndex + 1} / ${_questions.length}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Difficulty: ${_currentDifficulty.toUpperCase()}',
                style: TextStyle(fontWeight: FontWeight.bold, color: diffColor),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Confidence Bar
            LinearProgressIndicator(
              value: (_proficiency + 5) / 10,
              backgroundColor: Colors.grey.shade300,
              color: _proficiency >= 0 ? Colors.green : Colors.red,
              minHeight: 10,
            ),
            const SizedBox(height: 16),

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

            if (_answered)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentIndex + 1 == _questions.length
                        ? 'See Results →'
                        : 'Next Question →',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
