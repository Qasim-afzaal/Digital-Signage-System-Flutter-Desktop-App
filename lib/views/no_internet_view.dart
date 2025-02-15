import 'package:flutter/material.dart';

import 'package:digital_signage/widgets/center_image_widget.dart';
import 'package:digital_signage/widgets/text_widget.dart';

class NoInternetView extends StatefulWidget {
  const NoInternetView({super.key});

  @override
  State<NoInternetView> createState() => _NoInternetViewState();
}

class _NoInternetViewState extends State<NoInternetView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Image.asset(
            "assets/images/background.png",
            fit: BoxFit.cover, // Ensures the image covers the entire screen
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
          ),
          // Positioned text on top of the background
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomImageWidget(
                  imagePath: 'assets/images/Browser.png',
                ),
                SimpleText(
                  text: "No Internet",
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                SimpleText(
                  text:
                      "Wifi is still trying to connect, but it’s taking longer than normal.\nCheck that your Wifi is on and connected.",
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
