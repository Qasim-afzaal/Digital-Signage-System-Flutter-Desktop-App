import 'package:flutter/material.dart';

import 'package:digital_signage/widgets/center_image_widget.dart';
import 'package:digital_signage/widgets/text_widget.dart';

class ConnectingView extends StatefulWidget {
  const ConnectingView({super.key});

  @override
  State<ConnectingView> createState() => _ConnectingViewState();
}

class _ConnectingViewState extends State<ConnectingView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
         
          Image.asset(
            "assets/images/background.png",
            fit: BoxFit.cover,
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
          ),
        
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomImageWidget(
                  imagePath: 'assets/images/Wifi.png',
                ),
                SimpleText(
                  text: "Try Again Later",
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                SimpleText(
                  text:
                      "Api response failure",
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
