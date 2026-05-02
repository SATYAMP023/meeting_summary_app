import 'package:flutter/material.dart';
import 'record_tab.dart';
import 'recordings_tab.dart';
import 'projects_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ProjectsTab(onRecordTap: () => setState(() => currentIndex = 1)),
      RecordTab(),
      RecordingsTab(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => setState(() => currentIndex = i),
        backgroundColor: const Color(0xFF0D0D14),
        indicatorColor: const Color(0xFF7C6EF7).withOpacity(0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined, color: Color(0xFF8888A8)),
            selectedIcon: Icon(Icons.folder, color: Color(0xFF7C6EF7)),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none, color: Color(0xFF8888A8)),
            selectedIcon: Icon(Icons.mic, color: Color(0xFF7C6EF7)),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined, color: Color(0xFF8888A8)),
            selectedIcon: Icon(Icons.list_alt, color: Color(0xFF7C6EF7)),
            label: 'Recordings',
          ),
        ],
      ),
    );
  }
}