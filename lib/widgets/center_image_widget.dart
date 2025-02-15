import 'package:flutter/material.dart';

class CustomImageWidget extends StatelessWidget {
  final String imagePath;

  const CustomImageWidget({
    required this.imagePath,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imagePath,
      height: 90,
      width: 90,
    );
  }
}
