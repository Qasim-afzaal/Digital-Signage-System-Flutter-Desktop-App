import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:digital_signage/view_models/mqtt_view_model.dart';
import 'package:digital_signage/widgets/center_image_widget.dart';
import 'package:digital_signage/widgets/text_widget.dart';

class DownloadingView extends StatefulWidget {
  const DownloadingView({super.key});

  @override
  State<DownloadingView> createState() => _DownloadingViewState();
}

class _DownloadingViewState extends State<DownloadingView> {
  @override
  Widget build(BuildContext context) {
 
    final downloadViewModel = Provider.of<MqttViewModel>(context);

    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            "assets/images/background.png",
            fit: BoxFit.cover,
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CustomImageWidget(
                  imagePath: 'assets/images/Cloud.png',
                ),
                const SimpleText(
                  text: "Downloading...",
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                const SimpleText(
                  text: "Your content is being downloaded. Thank you for your patience.",
                ),
                const SizedBox(height: 20), 
                if (downloadViewModel.state == MqttState.downloading)
                  Column(
                    children: [
                      SizedBox(
                        width: 200, 
                        child: LinearProgressIndicator(
                          value: downloadViewModel.overallProgress,
                          backgroundColor: Colors.grey[300], 
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(downloadViewModel.overallProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
