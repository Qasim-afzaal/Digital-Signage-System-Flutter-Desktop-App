import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:digital_signage/view_models/mqtt_view_model.dart';
import 'package:digital_signage/widgets/center_image_widget.dart';
import 'package:digital_signage/widgets/text_widget.dart';

class DigivisionView extends StatefulWidget {
  const DigivisionView({super.key});

  @override
  State<DigivisionView> createState() => _DigivisionViewState();
}

class _DigivisionViewState extends State<DigivisionView> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final urlLauncherViewModel =
        Provider.of<MqttViewModel>(context, listen: false);

    return Scaffold(
      body: GestureDetector(
        onPanUpdate: (details) {
          print("Touch Position: ${details.localPosition}");
        },
        child: Stack(
          children: [
            Image.asset(
              "assets/images/background.png",
              fit: BoxFit.cover,
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(
                        "assets/images/Logo.png",
                        height: 220,
                        width: 220,
                      ),
                      const CustomImageWidget(
                        imagePath: 'assets/images/barcode.png',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(30.0, 0, 0, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SimpleText(
                        text: "To get started enter the code below at ",
                      ),
                      GestureDetector(
                        onTap: () => urlLauncherViewModel
                            .launchUrl(''),
                        child: const SimpleText(
                          text: "",
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SimpleText(
                        text: urlLauncherViewModel.topic,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
