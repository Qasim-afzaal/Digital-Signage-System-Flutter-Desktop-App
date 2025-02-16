import 'package:flutter/material.dart';

class RetryView extends StatefulWidget {
  const RetryView({super.key});

  @override
  State<RetryView> createState() => _RetryViewState();
}

class _RetryViewState extends State<RetryView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.blueGrey[900],
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20.0),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 100,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              "Try Again Later",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              "API response failure",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
