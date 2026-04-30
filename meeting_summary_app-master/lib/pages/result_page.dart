import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ResultPage extends StatelessWidget {
  final String summary;
  final String fullText;
  final String audioPath;

  const ResultPage({super.key, 
    required this.summary,
    required this.fullText,
    required this.audioPath,
  });

  void shareData() {
    final text = '''
📄 Summary:

$summary

📝 Full Text:

$fullText
''';

    Share.shareXFiles(
      [XFile(audioPath)],
      text: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Result")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              "📄 Summary:\n\n$summary",
              style: TextStyle(fontSize: 16),
            ),

            SizedBox(height: 20),

            Text(
              "📝 Full Text:\n\n$fullText",
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),

            SizedBox(height: 30),

            ElevatedButton(
              onPressed: shareData,
              child: Text("Share (WhatsApp etc.)"),
            )
          ],
        ),
      ),
    );
  }
}