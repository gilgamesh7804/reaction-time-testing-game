import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reaction Game',
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: ReactionGame(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ReactionGame extends StatefulWidget {
  @override
  _ReactionGameState createState() => _ReactionGameState();
}

class _ReactionGameState extends State<ReactionGame> {
  List<FallingCircle> circles = [];
  int score = 0;
  bool isGameOver = false;
  Random random = Random();

  Duration spawnInterval = Duration(milliseconds: 600); // Faster spawn interval
  double fallDuration = 2.0; // Faster fall duration (seconds)
  Timer? gameLoop;
  Timer? difficultyTimer;

  List<int> reactionTimesMs = [];

  @override
  void initState() {
    super.initState();
    startGame();
  }

  void startGame() {
    gameLoop = Timer.periodic(spawnInterval, (timer) {
      if (isGameOver) {
        timer.cancel();
        return;
      }

      final circleKey = UniqueKey();
      final spawnTime = DateTime.now();

      setState(() {
        circles.add(
          FallingCircle(
            key: circleKey,
            x: random.nextDouble(),
            fallDuration: fallDuration,
            spawnTime: spawnTime,
            onTap: () {
              final tapTime = DateTime.now();
              final reactionTime = tapTime.difference(spawnTime).inMilliseconds;
              reactionTimesMs.add(reactionTime);

              setState(() {
                score += 1;
                circles.removeWhere((c) => c.key == circleKey);
              });
            },
            onMiss: () {
              gameOver();
            },
          ),
        );
      });
    });

    difficultyTimer = Timer.periodic(Duration(seconds: 10), (_) {
      increaseDifficulty();
    });
  }

  void increaseDifficulty() {
    setState(() {
      fallDuration = (fallDuration - 0.2).clamp(0.8, 10.0);
      int newInterval = (spawnInterval.inMilliseconds - 100).clamp(300, 10000);
      spawnInterval = Duration(milliseconds: newInterval);

      gameLoop?.cancel();
      gameLoop = Timer.periodic(spawnInterval, (_) {
        if (isGameOver) return;

        final circleKey = UniqueKey();
        final spawnTime = DateTime.now();

        setState(() {
          circles.add(
            FallingCircle(
              key: circleKey,
              x: random.nextDouble(),
              fallDuration: fallDuration,
              spawnTime: spawnTime,
              onTap: () {
                final tapTime = DateTime.now();
                final reactionTime = tapTime
                    .difference(spawnTime)
                    .inMilliseconds;
                reactionTimesMs.add(reactionTime);

                setState(() {
                  score += 1;
                  circles.removeWhere((c) => c.key == circleKey);
                });
              },
              onMiss: () {
                gameOver();
              },
            ),
          );
        });
      });
    });
  }

  void gameOver() {
    setState(() {
      isGameOver = true;
      gameLoop?.cancel();
      difficultyTimer?.cancel();
      circles.clear();
    });

    double avgReaction = 0;
    if (reactionTimesMs.isNotEmpty) {
      avgReaction =
          reactionTimesMs.reduce((a, b) => a + b) / reactionTimesMs.length;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("Game Over", style: TextStyle(color: Colors.white)),
        content: Text(
          "Final Score: $score\n"
          "Avg Reaction: ${avgReaction.toStringAsFixed(0)} ms",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                score = 0;
                reactionTimesMs.clear();
                isGameOver = false;
                fallDuration = 2.0;
                spawnInterval = Duration(milliseconds: 600);
                startGame();
              });
            },
            child: Text(
              "Play Again",
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    gameLoop?.cancel();
    difficultyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ...circles,
        Positioned(
          top: 40,
          left: 20,
          child: Text(
            "Score: $score",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ],
    );
  }
}

class FallingCircle extends StatefulWidget {
  final double x;
  final double fallDuration;
  final DateTime spawnTime;
  final VoidCallback onTap;
  final VoidCallback onMiss;

  const FallingCircle({
    required Key key,
    required this.x,
    required this.fallDuration,
    required this.spawnTime,
    required this.onTap,
    required this.onMiss,
  }) : super(key: key);

  @override
  _FallingCircleState createState() => _FallingCircleState();
}

class _FallingCircleState extends State<FallingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: Duration(milliseconds: (widget.fallDuration * 1000).toInt()),
      vsync: this,
    )..forward();

    animation = Tween<double>(begin: 0, end: 1).animate(controller)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onMiss();
        }
      });

    controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    double leftPos = widget.x * (screenWidth - 50);

    return Positioned(
      top: animation.value * (screenHeight - 50),
      left: leftPos,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          widget.onTap();
          controller.stop();
        },
        child: Container(
          width: 80, // Increased hitbox width
          height: 80, // Increased hitbox height
          alignment: Alignment.center,
          child: Container(
            width: 50, // Visible circle size stays 50x50
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.cyanAccent, Colors.blueAccent.shade700],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
