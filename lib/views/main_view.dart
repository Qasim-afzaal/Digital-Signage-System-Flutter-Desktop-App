import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:digital_signage/view_models/mqtt_view_model.dart';
import 'package:digital_signage/widgets/text_widget.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final urlLauncherViewModel = Provider.of<MqttViewModel>(context, listen: false);

    return Scaffold(
      body: GestureDetector(
        onPanUpdate: (details) {
          print("Touch Position: \${details.localPosition}");
        },
        child: Container(
          color: Colors.blueGrey[900],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: 20,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      Icons.business,
                      size: 100,
                      color: Colors.white,
                    ),
                    Icon(
                      Icons.qr_code,
                      size: 100,
                      color: Colors.white,
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
                      onTap: () => urlLauncherViewModel.launchUrl(''),
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
        ),
      ),
    );
  }
}
