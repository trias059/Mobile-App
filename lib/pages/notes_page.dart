import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/model/note_model.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with TickerProviderStateMixin {
  late Box<NoteModel> noteBox;
  late TabController _tabController;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> categories = [
    {'key': 'all', 'name': 'Semua', 'icon': Icons.notes, 'color': Colors.grey},
    {'key': 'learning', 'name': 'Belajar', 'icon': Icons.school, 'color': Colors.blue},
    {'key': 'idea', 'name': 'Ide', 'icon': Icons.lightbulb, 'color': Colors.orange},
    {'key': 'general', 'name': 'Umum', 'icon': Icons.note, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    noteBox = Hive.box<NoteModel>('notes');
    _tabController = TabController(length: categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<NoteModel> _getFilteredNotes() {
    List<NoteModel> notes = noteBox.values.toList();

    // Filter by category
    if (_selectedCategory != 'all') {
      notes = notes.where((note) => note.category == _selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      notes = notes.where((note) =>
      note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          note.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          note.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()))
      ).toList();
    }

    // Sort: pinned first, then by updated date
    notes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return notes;
  }

  void _showNoteDialog({NoteModel? note, int? index}) {
    final isEditing = note != null;
    final titleController = TextEditingController(text: note?.title ?? '');
    final contentController = TextEditingController(text: note?.content ?? '');
    String selectedCategory = note?.category ?? 'general';
    List<String> tags = List.from(note?.tags ?? []);
    String colorCode = note?.colorCode ?? '#2196F3';
    bool isPinned = note?.isPinned ?? false;

    final availableColors = [
      '#2196F3', '#4CAF50', '#FF9800', '#9C27B0',
      '#F44336', '#00BCD4', '#FFEB3B', '#795548'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(int.parse(colorCode.replaceFirst('#', '0xFF'))),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEditing ? 'Edit Note' : 'Tambah Note Baru',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setDialogState(() {
                            isPinned = !isPinned;
                          });
                        },
                        icon: Icon(
                          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Judul Note',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.title),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Content
                        TextField(
                          controller: contentController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Isi Note',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notes),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Category
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: categories.skip(1).map((cat) => DropdownMenuItem<String>(
                            value: cat['key'] as String,
                            child: Row(
                              children: [
                                Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 20),
                                const SizedBox(width: 8),
                                Text(cat['name'] as String),
                              ],
                            ),
                          )).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCategory = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Color Selection
                        const Text('Pilih Warna:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: availableColors.map((color) => GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                colorCode = color;
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorCode == color ? Colors.black : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: colorCode == color
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (titleController.text.isNotEmpty) {
                            final now = DateTime.now();
                            final newNote = NoteModel(
                              title: titleController.text,
                              content: contentController.text,
                              createdAt: note?.createdAt ?? now,
                              updatedAt: now,
                              category: selectedCategory,
                              tags: tags,
                              isPinned: isPinned,
                              colorCode: colorCode,
                            );

                            if (isEditing && index != null) {
                              noteBox.putAt(index, newNote);
                            } else {
                              noteBox.add(newNote);
                            }
                            Navigator.pop(context);
                          }
                        },
                        child: Text(isEditing ? 'Update' : 'Simpan'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteNote(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Note'),
        content: const Text('Yakin ingin menghapus note ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              noteBox.deleteAt(index);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note berhasil dihapus')),
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(NoteModel note, int index) {
    final cardColor = Color(int.parse(note.colorCode.replaceFirst('#', '0xFF')));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showNoteDialog(note: note, index: index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [cardColor.withOpacity(0.1), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    if (note.isPinned)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.push_pin, color: cardColor, size: 16),
                      ),
                    Expanded(
                      child: Text(
                        note.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cardColor.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        note.categoryDisplayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: cardColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteNote(index),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.content.isNotEmpty) ...[
                      Text(
                        note.content,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          note.formattedDate,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (note.tags.isNotEmpty)
                          Wrap(
                            spacing: 4,
                            children: note.tags.take(2).map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cardColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cardColor,
                                ),
                              ),
                            )).toList(),
                          ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari notes...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear),
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              // Category Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: categories.map((cat) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat['icon'], size: 16),
                      const SizedBox(width: 4),
                      Text(cat['name']),
                    ],
                  ),
                )).toList(),
                onTap: (index) {
                  setState(() {
                    _selectedCategory = categories[index]['key'];
                  });
                },
              ),
            ],
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: noteBox.listenable(),
        builder: (context, Box<NoteModel> box, _) {
          final filteredNotes = _getFilteredNotes();

          if (filteredNotes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _searchQuery.isNotEmpty ? Icons.search_off : Icons.note_add,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Tidak ada note yang ditemukan'
                        : 'Belum ada notes',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  if (_searchQuery.isEmpty)
                    const Text(
                      'Tap + untuk mulai membuat catatan',
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredNotes.length,
            itemBuilder: (context, index) {
              final note = filteredNotes[index];
              final originalIndex = box.values.toList().indexOf(note);
              return _buildNoteCard(note, originalIndex);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteDialog(),
        tooltip: 'Tambah Note',
        child: const Icon(Icons.add),
      ),
    );
  }
}