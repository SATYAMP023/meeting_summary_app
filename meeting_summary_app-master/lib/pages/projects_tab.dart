import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Models ───────────────────────────────────────────────

class Member {
  final String id;
  final String name;
  final String phone;
  final int colorValue;

  Member({
    required this.id,
    required this.name,
    required this.phone,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  String get initials => name.trim().split(' ')
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .take(2).join();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'colorValue': colorValue,
  };

  factory Member.fromJson(Map<String, dynamic> j) => Member(
    id: j['id'],
    name: j['name'],
    phone: json['phone'] ?? '',
    colorValue: j['colorValue'],
  );
}

class MeetingRecord {
  final String id;
  final String title;
  final DateTime date;
  final int durationMinutes;
  final String audioPath;
  String? summary;
  String? fullText;

  MeetingRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.durationMinutes,
    required this.audioPath,
    this.summary,
    this.fullText,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    'durationMinutes': durationMinutes,
    'audioPath': audioPath,
    'summary': summary,
    'fullText': fullText,
  };

  factory MeetingRecord.fromJson(Map<String, dynamic> j) => MeetingRecord(
    id: j['id'],
    title: j['title'],
    date: DateTime.parse(j['date']),
    durationMinutes: j['durationMinutes'] ?? 0,
    audioPath: j['audioPath'] ?? '',
    summary: j['summary'],
    fullText: j['fullText'],
  );
}

class Project {
  final String id;
  String name;
  String emoji;
  int colorValue;
  List<MeetingRecord> meetings;
  List<Member> members;        // ← ADD THIS
  final DateTime createdAt;

  Project({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    required this.meetings,
    List<Member>? members,     // ← ADD THIS
    required this.createdAt,
  }) : members = members ?? [];  // ← ADD THIS

  // update toJson:
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'colorValue': colorValue,
    'meetings': meetings.map((m) => m.toJson()).toList(),
    'members': members.map((m) => m.toJson()).toList(),  // ← ADD THIS
    'createdAt': createdAt.toIso8601String(),
  };

  // update fromJson:
  factory Project.fromJson(Map<String, dynamic> j) => Project(
    id: j['id'],
    name: j['name'],
    emoji: j['emoji'],
    colorValue: j['colorValue'],
    createdAt: DateTime.parse(j['createdAt']),
    meetings: (j['meetings'] as List)
        .map((m) => MeetingRecord.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
    members: ((j['members'] ?? []) as List)  // ← ADD THIS
        .map((m) => Member.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
  );
}

// ─── Global project store ─────────────────────────────────
class ProjectStore {
  static List<Project> projects = [];

  static Future<void> addMember(String projectId, Member member) async {
    final p = projects.firstWhere((p) => p.id == projectId);
    p.members.add(member);
    await save();
  }

  static Future<void> deleteMember(String projectId, String memberId) async {
    final p = projects.firstWhere((p) => p.id == projectId);
    p.members.removeWhere((m) => m.id == memberId);
    await save();
  }

  static Future<void> load() async {
    final raw = await StorageService.loadProjects();
    projects = raw.map((e) => Project.fromJson(e)).toList();
  }

  static Future<void> save() async {
    await StorageService.saveProjects(
      projects.map((p) => p.toJson()).toList(),
    );
  }

  static Future<void> addProject(Project p) async {
    projects.add(p);
    await save();
  }

  static Future<void> deleteProject(String id) async {
    projects.removeWhere((p) => p.id == id);
    await save();
  }

  static Future<void> addMeetingToProject(
      String projectId, MeetingRecord meeting) async {
    final p = projects.firstWhere((p) => p.id == projectId);
    p.meetings.add(meeting);
    await save();
  }

  static Future<void> updateMeetingSummary(
      String projectId, String meetingId, String summary, String fullText) async {
    final p = projects.firstWhere((p) => p.id == projectId);
    final m = p.meetings.firstWhere((m) => m.id == meetingId);
    m.summary = summary;
    m.fullText = fullText;
    await save();
  }

  static Future<void> deleteMeeting(
      String projectId, String meetingId) async {
    final p = projects.firstWhere((p) => p.id == projectId);
    p.meetings.removeWhere((m) => m.id == meetingId);
    await save();
  }
}

// ─── ProjectsTab ──────────────────────────────────────────
class ProjectsTab extends StatefulWidget {
  final VoidCallback onRecordTap;
  const ProjectsTab({super.key, required this.onRecordTap});

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await ProjectStore.load();
    setState(() => _loading = false);
  }

  List<Project> get _filtered => _searchQuery.isEmpty
      ? ProjectStore.projects
      : ProjectStore.projects.where((p) =>
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.meetings.any((m) =>
              m.title.toLowerCase().contains(_searchQuery.toLowerCase()))).toList();

  int get _totalMeetings =>
      ProjectStore.projects.fold(0, (s, p) => s + p.meetings.length);

  int get _totalMinutes =>
      ProjectStore.projects.fold(0,
        (s, p) => s + p.meetings.fold(0, (a, m) => a + m.durationMinutes));

  void _addProject() {
    final nameController = TextEditingController();
    final emojis = ['🚀','🎯','💼','⚡','🔬','🎨','📊','🌍','🛠️','🎵'];
    String selectedEmoji = '🚀';
    final colors = [
      0xFF7C6EF7, 0xFFE8625A, 0xFF4ECDC4,
      0xFFF7C948, 0xFF56CCF2, 0xFF6FCF97,
    ];
    int selectedColor = colors[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF13131A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Project',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white)),
              const SizedBox(height: 20),

              // Emoji picker
              const Text('Pick an icon',
                style: TextStyle(fontSize: 13, color: Color(0xFF8888A8))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: emojis.map((e) => GestureDetector(
                  onTap: () => setModal(() => selectedEmoji = e),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: selectedEmoji == e
                          ? Color(selectedColor).withOpacity(0.2)
                          : const Color(0xFF1C1C27),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedEmoji == e
                            ? Color(selectedColor) : Colors.transparent,
                      ),
                    ),
                    child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 20))),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),

              // Color picker
              const Text('Pick a color',
                style: TextStyle(fontSize: 13, color: Color(0xFF8888A8))),
              const SizedBox(height: 10),
              Row(
                children: colors.map((c) => GestureDetector(
                  onTap: () => setModal(() => selectedColor = c),
                  child: Container(
                    width: 32, height: 32,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Color(c), shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedColor == c
                            ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),

              // Name input
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Project name...',
                  hintStyle: const TextStyle(color: Color(0xFF8888A8)),
                  filled: true,
                  fillColor: const Color(0xFF1C1C27),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C6EF7),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    final p = Project(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text.trim(),
                      emoji: selectedEmoji,
                      colorValue: selectedColor,
                      meetings: [],
                      createdAt: DateTime.now(),
                    );
                    await ProjectStore.addProject(p);
                    setState(() {});
                    Navigator.pop(ctx);
                  },
                  child: const Text('Create Project',
                    style: TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 15, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteProject(Project p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        title: const Text('Delete Project',
            style: TextStyle(color: Colors.white)),
        content: Text('Delete "${p.name}" and all its meetings?',
            style: const TextStyle(color: Color(0xFF8888A8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await ProjectStore.deleteProject(p.id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF7C6EF7)));
    }

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Projects',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: -0.5)),
                  Text(
                    '${ProjectStore.projects.length} active · $_totalMeetings recordings',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF8888A8)),
                  ),
                ]),
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF7C6EF7),
                  child: Text('SP',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search meetings or projects...',
                hintStyle: const TextStyle(
                    color: Color(0xFF8888A8), fontSize: 14),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFF8888A8), size: 18),
                filled: true,
                fillColor: const Color(0xFF13131A),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Colors.white.withOpacity(0.07)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Colors.white.withOpacity(0.07)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFF7C6EF7), width: 1),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _StatCard(
                  value: '${ProjectStore.projects.length}',
                  label: 'Projects'),
              const SizedBox(width: 10),
              _StatCard(value: '$_totalMeetings', label: 'Meetings'),
              const SizedBox(width: 10),
              _StatCard(
                  value: '${_totalMinutes ~/ 60}h ${_totalMinutes % 60}m',
                  label: 'Recorded'),
            ]),
          ),

          const SizedBox(height: 20),

          // Section label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your Projects',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w700, color: Colors.white)),
                GestureDetector(
                  onTap: _addProject,
                  child: const Text('+ New',
                    style: TextStyle(fontSize: 13,
                        color: Color(0xFF7C6EF7),
                        fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Projects list
          Expanded(
            child: ProjectStore.projects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📁', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        const Text('No projects yet',
                          style: TextStyle(color: Colors.white,
                              fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text('Create a project to organize your meetings',
                          style: TextStyle(color: Color(0xFF8888A8),
                              fontSize: 13),
                          textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C6EF7),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          onPressed: _addProject,
                          child: const Text('Create First Project',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding:
                          const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        ..._filtered.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ProjectCard(
                            project: p,
                            onRecordTap: widget.onRecordTap,
                            onDelete: () => _deleteProject(p),
                            onChanged: () => setState(() {}),
                          ),
                        )),
                        // New project button
                        GestureDetector(
                          onTap: _addProject,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFF7C6EF7)
                                      .withOpacity(0.3),
                                  width: 1.5),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add,
                                    color: Color(0xFF7C6EF7), size: 20),
                                SizedBox(width: 8),
                                Text('New Project',
                                  style: TextStyle(
                                      color: Color(0xFF7C6EF7),
                                      fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFF7C6EF7), Color(0xFFB09FFF)],
            ).createShader(b),
            child: Text(value,
              style: const TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(height: 2),
          Text(label,
            style: const TextStyle(fontSize: 10,
                color: Color(0xFF8888A8), letterSpacing: 0.5)),
        ]),
      ),
    );
  }
}

// ─── Project Card ─────────────────────────────────────────
class _ProjectCard extends StatefulWidget {
  final Project project;
  final VoidCallback onRecordTap;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _ProjectCard({
    required this.project,
    required this.onRecordTap,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard>
    with SingleTickerProviderStateMixin {

  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  // Default project color (instead of p.color)
  final Color projectColor = const Color(0xFF7C6EF7);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final h = d.hour > 12 ? d.hour - 12 : d.hour == 0 ? 12 : d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} · $h:$m $ampm';
  }

  void _deleteMeeting(MeetingRecord m) async {
    await ProjectStore.deleteMeeting(widget.project.id, m.id);
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [

              // Top Color Bar
              Container(height: 3, color: projectColor),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: projectColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          p.emoji ?? "📁",
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: 0.5).animate(_anim),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF8888A8),
                      ),
                    ),
                  ],
                ),
              ),

              // Expand Section
              SizeTransition(
                sizeFactor: _anim,
                child: Column(
                  children: [

                    const Divider(height: 1, color: Color(0xFF1C1C27)),

                    // Members Title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        'Members (${p.members.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    if (p.members.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          "No members added",
                          style: TextStyle(color: Color(0xFF8888A8)),
                        ),
                      )
                    else
                      ...p.members.map(
                            (m) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: m.color,
                            child: Text(
                              m.initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            m.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            m.phone,
                            style: const TextStyle(
                                color: Color(0xFF8888A8)),
                          ),
                        ),
                      ),

                    const Divider(height: 1, color: Color(0xFF1C1C27)),

                    // Meetings
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: GestureDetector(
                        onTap: widget.onRecordTap,
                        child: Text(
                          '+ Record',
                          style: TextStyle(
                            fontSize: 12,
                            color: projectColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    if (p.meetings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'No recordings yet',
                          style: TextStyle(
                            color: Color(0xFF8888A8),
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ...p.meetings.map(
                            (m) => ListTile(
                          title: Text(
                            m.title,
                            style:
                            const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            _formatDate(m.date),
                            style: const TextStyle(
                                color: Color(0xFF8888A8)),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFF8888A8),
                            ),
                            onPressed: () =>
                                _deleteMeeting(m),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}