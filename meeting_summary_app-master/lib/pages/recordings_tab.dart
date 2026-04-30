import 'dart:io';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import 'result_page.dart';

class RecordingsStore {
  static List<Map<String, dynamic>> recordings = [];

  static void addRecording(
  String path,
  int durationSeconds,
  int fileSize,
  DateTime createdAt,
) {
  recordings.add({
    "path": path,
    "summary": null,
    "isSummarizing": false,
    "duration": durationSeconds,
    "size": fileSize,
    "createdAt": createdAt,
  });
}

static void deleteRecording(int index) {
  final path = recordings[index]["path"];
  final file = File(path);

  if (file.existsSync()) file.deleteSync();

  recordings.removeAt(index);
}
}

class RecordingsTab extends StatefulWidget {
  const RecordingsTab({super.key});

  @override
  _RecordingsTabState createState() => _RecordingsTabState();
}

class _RecordingsTabState extends State<RecordingsTab> {
  final AudioPlayer player = AudioPlayer();

  int? playingIndex;
  bool isPlaying = false;

  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  double speed = 1.0;

  @override
  void initState() {
    super.initState();

    player.onDurationChanged.listen((d) {
      setState(() => duration = d);
    });

    player.onPositionChanged.listen((p) {
      setState(() => position = p);
    });

    player.onPlayerComplete.listen((_) {
      setState(() {
        isPlaying = false;
        playingIndex = null;
        position = Duration.zero;
      });
    });
  }

String formatSize(int bytes) {
  if (bytes < 1024) return "$bytes B";
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
  return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
}

  String formatTime(int s) {
    final min = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return "$min:$sec";
  }

  Future<void> togglePlay(int index, String path) async {
    if (playingIndex == index && isPlaying) {
      await player.pause();
      setState(() => isPlaying = false);
    } else {
      await player.stop();
      await player.setPlaybackRate(speed);
      await player.play(DeviceFileSource(path));

      setState(() {
        playingIndex = index;
        isPlaying = true;
      });
    }
  }

  void seekAudio(double value) async {
    await player.seek(Duration(seconds: value.toInt()));
  }

  void getSummary(int index) async {
    setState(() {
      RecordingsStore.recordings[index]["isSummarizing"] = true;
    });

    try {
      final path = RecordingsStore.recordings[index]["path"];
      final result = await ApiService.uploadAudio(path);

      setState(() {
RecordingsStore.recordings[index]["summary"] =
    result["summary"] ?? result["text"] ?? "No summary available";

    RecordingsStore.recordings[index]["text"] =
    result["text"];
});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e")),
      );
    } finally {
      setState(() {
        RecordingsStore.recordings[index]["isSummarizing"] = false;
      });
    }
  }

  void deleteRecording(int index) {
    setState(() {
      RecordingsStore.deleteRecording(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (RecordingsStore.recordings.isEmpty) {
      return const Center(
        child: Text(
          "No recordings yet.\nStart from Record tab 🎤",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: RecordingsStore.recordings.length,
      itemBuilder: (context, index) {
        final recording = RecordingsStore.recordings[index];
        final path = recording["path"];

        final isThisPlaying = playingIndex == index && isPlaying;
        final hasSummary = recording["summary"] != null;
        final isSummarizing = recording["isSummarizing"] ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // 🔹 HEADER
                Row(
                  children: [
                    Icon(Icons.mic, color: Colors.redAccent),
                    SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Recording ${index + 1}",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                              "${formatTime(recording["duration"] ?? 0)} • ${formatSize(recording["size"] ?? 0)}",
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              recording["createdAt"] != null
                                  ? recording["createdAt"].toString().substring(0, 16)
                                  : "",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          Text(
                            hasSummary
                                ? "✅ Summary ready"
                                : "⏳ No summary yet",
                            style: TextStyle(
                              color: hasSummary
                                  ? Colors.green
                                  : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteRecording(index),
                    )
                  ],
                ),

                SizedBox(height: 10),

                // 🎚️ SEEK BAR (only for active item)
                if (isThisPlaying) ...[
                  Slider(
                    min: 0,
                    max: duration.inSeconds.toDouble() == 0
                        ? 1
                        : duration.inSeconds.toDouble(),
                    value: position.inSeconds
                        .toDouble()
                        .clamp(0, duration.inSeconds.toDouble()),
                    onChanged: seekAudio,
                  ),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatTime(position.inSeconds)),
                      Text(formatTime(duration.inSeconds)),
                    ],
                  ),
                ],

                SizedBox(height: 10),

                // 🎛️ CONTROLS
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => togglePlay(index, path),
                      icon: Icon(isThisPlaying
                          ? Icons.pause
                          : Icons.play_arrow),
                      label: Text(
                          isThisPlaying ? "Pause" : "Play"),
                    ),

                    SizedBox(width: 10),

                    // ⚡ SPEED
                    DropdownButton<double>(
                      value: speed,
                      items: [0.5, 1.0, 1.5, 2.0]
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text("${s}x"),
                              ))
                          .toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          speed = value;
                          await player.setPlaybackRate(speed);
                          setState(() {});
                        }
                      },
                    ),

                    SizedBox(width: 10),

                    // 📄 SUMMARY
                    if (isSummarizing)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...[
                      // ✅ Always show Summary button
                      ElevatedButton(
                        onPressed: () => getSummary(index),
                        child: Text(hasSummary ? "Re-Summary" : "Summary"),
                      ),

                      SizedBox(width: 10),

                      // ✅ Show View button ONLY if summary exists
                      if (hasSummary)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ResultPage(
                                  summary: recording["summary"],
                                  fullText: recording["text"],
                                  audioPath: path,
                                ),
                              ),
                            );
                          },
                          child: Text("View"),
                        ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}