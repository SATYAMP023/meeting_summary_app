import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import 'recordings_tab.dart';
import 'projects_tab.dart';

class RecordTab extends StatefulWidget {
  const RecordTab({super.key});

  @override
  _RecordTabState createState() => _RecordTabState();
}

class _RecordTabState extends State<RecordTab> {
  final audioService = AudioService();
  final player = AudioPlayer();

  bool isRecording = false;
  bool isRecorded = false;
  bool isPlaying = false;

  String? filePath;

  int seconds = 0;
  Timer? timer;

  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  double speed = 1.0;

  List<double> amplitudes = [];
  StreamSubscription? ampSub;

  // ⏱️ TIMER
  void startTimer() {
    seconds = 0;
    timer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() => seconds++);
    });
  }

  void stopTimer() {
    timer?.cancel();
  }

  String formatTime(int s) {
    final min = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return "$min:$sec";
  }

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
        position = Duration.zero;
      });
    });
  }

  // 🎤 START
  void startRecording() async {
    final path = await audioService.startRecording();

    if (path != null) {
      setState(() {
        isRecording = true;
        isRecorded = false;
        filePath = path;
        amplitudes.clear();
      });

      startTimer();

      ampSub?.cancel();
      ampSub = audioService.amplitudeStream?.listen((amp) {
        final value = amp.current;
        setState(() {
          amplitudes.add(value);
          if (amplitudes.length > 50) amplitudes.removeAt(0);
        });
      });
    }
  }

  // 🛑 STOP
  void stopRecording() async {
    final path = await audioService.stopRecording();

    stopTimer();

    setState(() {
      isRecording = false;
      isRecorded = true;
      filePath = path;
    });
  }

  // ▶️ PLAY
  Future<void> playAudio() async {
    if (filePath != null) {
      await player.stop();
      await player.setPlaybackRate(speed);
      await player.play(DeviceFileSource(filePath!));
      setState(() => isPlaying = true);
    }
  }

  void seekAudio(double value) async {
    await player.seek(Duration(seconds: value.toInt()));
  }

  // 💾 SAVE
void saveRecording() {
  if (filePath == null) return;

  if (ProjectStore.projects.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please create a project first from the Projects tab"),
        backgroundColor: Color(0xFF7C6EF7),
      ),
    );
    return;
  }

  // Show project picker
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF13131A),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final titleController = TextEditingController(
          text: 'Meeting ${DateTime.now().day}/${DateTime.now().month}');
      return StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Save to Project',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white)),
              const SizedBox(height: 16),

              // Meeting title
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Meeting title',
                  labelStyle: const TextStyle(color: Color(0xFF8888A8)),
                  filled: true,
                  fillColor: const Color(0xFF1C1C27),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Choose project',
                style: TextStyle(fontSize: 13, color: Color(0xFF8888A8))),
              const SizedBox(height: 10),

              // Project list
              ...ProjectStore.projects.map((p) => GestureDetector(
                onTap: () async {
                  final file = File(filePath!);
                  final meeting = MeetingRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text.trim().isEmpty
                        ? 'Meeting ${DateTime.now().day}/${DateTime.now().month}'
                        : titleController.text.trim(),
                    date: DateTime.now(),
                    durationMinutes: (seconds / 60).ceil(),
                    audioPath: filePath!,
                  );
                  await ProjectStore.addMeetingToProject(p.id, meeting);
                  Navigator.pop(ctx);
                  resetState();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Saved to ${p.name}'),
                      backgroundColor: Color(p.colorValue),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C27),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                    color: const Color(0xFF7C6EF7).withOpacity(0.3)
                  ),
                  child: Row(children: [
                    Text(p.emoji,
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(p.name,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w600))),
                    Text('${p.meetings.length} meetings',
                      style: const TextStyle(
                        color: Color(0xFF7C6EF7),
                        fontSize: 12,
                      )
                  ]),
                ),
              )),
            ],
          ),
        ),
      );
    },
  );
}
  void discardRecording() {
    if (filePath != null) {
      final file = File(filePath!);
      if (file.existsSync()) file.deleteSync();
    }
    resetState();
  }

  void resetState() {
    setState(() {
      isRecording = false;
      isRecorded = false;
      isPlaying = false;
      filePath = null;
      seconds = 0;
      position = Duration.zero;
      duration = Duration.zero;
      amplitudes.clear();
    });
  }

  @override
  void dispose() {
    player.dispose();
    ampSub?.cancel();
    super.dispose();
  }

  // 🎨 WAVEFORM
// 🎨 WAVEFORM (FIXED - NO SLIDING BUG)
Widget buildWaveform() {
  return SizedBox(
    height: 100,
    width: double.infinity,
    child: Align(
      alignment: Alignment.center, // ✅ always centered
      child: SizedBox(
        width: 260, // ✅ fixed width (prevents sliding)
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: amplitudes.map((amp) {
            double height = (amp + 50) * 1.5;

            return AnimatedContainer(
              duration: Duration(milliseconds: 60),
              curve: Curves.easeOut,
              margin: EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: height.clamp(5, 90),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }).toList(),
        ),
      ),
    ),
  );
}

  // 💤 IDLE UI
  Widget buildIdleUI() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_none, size: 80, color: Colors.grey.shade400),
            SizedBox(height: 20),
            Text(
              "Start Recording",
              style: TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Tap below to record your meeting",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 40),
            GestureDetector(
              onTap: startRecording,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 20,
                    )
                  ],
                ),
                child: Icon(Icons.mic, size: 40, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 40),

            // ⏱️ TIMER
            if (isRecording || isRecorded)
              Text(
                formatTime(seconds),
                style: TextStyle(
                  fontSize: 42,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

            SizedBox(height: 30),

            // 💤 IDLE
            if (!isRecording && !isRecorded) buildIdleUI(),

            // 🎤 RECORDING
            if (isRecording) ...[
              buildWaveform(),
              SizedBox(height: 30),
              GestureDetector(
                onTap: stopRecording,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                  child: Icon(Icons.stop, color: Colors.white, size: 36),
                ),
              ),
            ],

            // 🎧 RECORDED
            if (isRecorded) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Slider(
                      min: 0,
                      max: duration.inSeconds == 0
                          ? 1
                          : duration.inSeconds.toDouble(),
                      value: position.inSeconds
                          .toDouble()
                          .clamp(0, duration.inSeconds.toDouble()),
                      onChanged: seekAudio,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatTime(position.inSeconds),
                            style: TextStyle(color: Colors.white)),
                        Text(formatTime(duration.inSeconds),
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                    SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      children: [
                        IconButton(
                          iconSize: 40,
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_circle
                                : Icons.play_circle,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            if (isPlaying) {
                              await player.pause();
                              setState(() => isPlaying = false);
                            } else {
                              await playAudio();
                            }
                          },
                        ),
                        DropdownButton<double>(
                          dropdownColor: Colors.black,
                          value: speed,
                          style: TextStyle(color: Colors.white),
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
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: saveRecording,
                          child: Text("Save"),
                        ),
                        ElevatedButton(
                          onPressed: discardRecording,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          child: Text("Discard"),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],

            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}