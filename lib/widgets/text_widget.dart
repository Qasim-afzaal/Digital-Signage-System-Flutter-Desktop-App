import 'package:flutter/material.dart';

class SimpleText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  const SimpleText({
    required this.text,
    this.fontSize = 13.0,
    this.fontWeight = FontWeight.normal,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      textAlign: TextAlign.center,
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }
}
