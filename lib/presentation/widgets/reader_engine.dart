import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../domain/models/chapter.dart';
import '../../domain/models/reading_preferences.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/models/annotation.dart';
import '../../domain/models/dictionary_entry.dart';

enum ReaderMode { scroll, paginated }

class ReaderEngine extends StatefulWidget {
  final Chapter chapter;
  final int initialProgress;

  const ReaderEngine({
    Key? key,
    required this.chapter,
    this.initialProgress = 0,
  }) : super(key: key);

  @override
  State<ReaderEngine> createState() => _ReaderEngineState();
}

class _ReaderEngineState extends State<ReaderEngine> {
  ReaderMode _mode = ReaderMode.scroll;
  int _progress = 0;
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  Timer? _debounce;
  ReadingPreferences _prefs = const ReadingPreferences();
  bool _isLoadingPrefs = true;

  List<String> _paragraphs = [];
  
  List<Annotation> _annotations = [];
  String? _selectedText;
  int? _syncPromptPercent;
  bool _syncHandled = false;

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress;
    _paragraphs = widget.chapter.content.split('\n\n').where((s) => s.trim().isNotEmpty).toList();
    _scrollController.addListener(_onScroll);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final repo = context.read<ILibraryRepository>();
    final prefs = await repo.getReadingPreferences();
    final annotations = await repo.getAnnotations(widget.chapter.id);
    if (mounted) {
      setState(() {
        _prefs = prefs;
        _annotations = annotations;
        _isLoadingPrefs = false;
      });
    }

    if (!_syncHandled) {
      final audioSync = await repo.getLinkedAudioProgress(widget.chapter.id);
      if (audioSync != null && audioSync.progressPercent > 0 && mounted) {
        setState(() {
          _syncPromptPercent = audioSync.progressPercent;
        });
      }
    }
  }

  Future<void> _addAnnotation(String type, {String? color, String? note}) async {
    if (type == 'highlight' && (_selectedText == null || _selectedText!.isEmpty)) return;
    
    final repo = context.read<ILibraryRepository>();
    final annotation = Annotation(
      id: '',
      profileId: 'guest',
      chapterId: widget.chapter.id,
      annotationType: type,
      color: color,
      selectedText: type == 'highlight' ? _selectedText : null,
      noteText: note,
      startPosition: type == 'highlight' ? '0' : null, // Simplification for Flutter selection
      endPosition: type == 'highlight' ? _selectedText?.length.toString() : null,
      createdAt: DateTime.now(),
    );
    
    final saved = await repo.addAnnotation(annotation);
    setState(() {
      _annotations.add(saved);
      if (type == 'highlight') _selectedText = null;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type added locally in <50ms!')));
    }
  }

  Future<void> _lookupDictionary() async {
    if (_selectedText == null || _selectedText!.isEmpty) return;
    
    final word = _selectedText!.trim();
    if (word.split(RegExp(r'\s+')).length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a single word.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => _DictionarySheet(word: word),
    );
  }

  void _updatePref({
    String? fontFamily,
    int? fontSizePx,
    String? lineSpacing,
    String? theme,
    String? margins,
  }) {
    final newPrefs = _prefs.copyWith(
      fontFamily: fontFamily,
      fontSizePx: fontSizePx,
      lineSpacing: lineSpacing,
      theme: theme,
      margins: margins,
    );
    setState(() => _prefs = newPrefs);
    context.read<ILibraryRepository>().updateReadingPreferences(newPrefs);
  }

  void _flushSave() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      context.read<ILibraryRepository>().updateChapterProgress(
        widget.chapter.id, 
        _progress, 
        _mode == ReaderMode.scroll ? (_scrollController.hasClients ? _scrollController.offset.round() : 0) : (_pageController.hasClients ? _pageController.page?.round() ?? 0 : 0),
      );
    }
  }

  @override
  void dispose() {
    _flushSave();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_mode == ReaderMode.scroll && _scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      if (maxScroll > 0) {
        final percent = ((currentScroll / maxScroll) * 100).round().clamp(0, 100);
        _updateProgress(percent, currentScroll.round());
      } else {
        _updateProgress(100, 0);
      }
    }
  }

  void _onPageChanged(int pageIndex, int totalPages) {
    if (totalPages > 1) {
      final percent = ((pageIndex / (totalPages - 1)) * 100).round().clamp(0, 100);
      _updateProgress(percent, pageIndex); // Store page index in scroll position for paginated mode
    } else {
      _updateProgress(100, 0);
    }
  }

  void _updateProgress(int percent, int position) {
    if (_progress != percent) {
      setState(() => _progress = percent);
    }
    
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      context.read<ILibraryRepository>().updateChapterProgress(
        widget.chapter.id, 
        percent, 
        position,
      );
    });
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == ReaderMode.scroll ? ReaderMode.paginated : ReaderMode.scroll;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_paragraphs.isEmpty) return;
      if (_mode == ReaderMode.paginated && _pageController.hasClients) {
        final percent = _progress / 100.0;
        final targetPage = (percent * (_paragraphs.length - 1)).round();
        _pageController.jumpToPage(targetPage);
      } else if (_mode == ReaderMode.scroll && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final percent = _progress / 100.0;
        _scrollController.jumpTo(percent * maxScroll);
      }
    });
  }

  void _acceptSync() {
    if (_syncPromptPercent != null) {
      final percent = _syncPromptPercent! / 100.0;
      if (_mode == ReaderMode.paginated && _pageController.hasClients && _paragraphs.isNotEmpty) {
        final targetPage = (percent * (_paragraphs.length - 1)).round();
        _pageController.jumpToPage(targetPage);
      } else if (_mode == ReaderMode.scroll && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(percent * maxScroll);
      }
      setState(() {
        _progress = _syncPromptPercent!;
      });
    }
    setState(() {
      _syncPromptPercent = null;
      _syncHandled = true;
    });
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  const Text('Theme', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _prefs.theme,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'light', child: Text('Light')),
                      DropdownMenuItem(value: 'dark', child: Text('Dark')),
                      DropdownMenuItem(value: 'sepia', child: Text('Sepia')),
                      DropdownMenuItem(value: 'amoled', child: Text('AMOLED')),
                    ],
                    onChanged: (v) { setSheetState(() => _prefs = _prefs.copyWith(theme: v)); _updatePref(theme: v); },
                  ),
                  const SizedBox(height: 16),
                  const Text('Font Family', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _prefs.fontFamily,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'serif', child: Text('Serif')),
                      DropdownMenuItem(value: 'sans', child: Text('Sans-Serif')),
                      DropdownMenuItem(value: 'mono', child: Text('Monospace')),
                    ],
                    onChanged: (v) { setSheetState(() => _prefs = _prefs.copyWith(fontFamily: v)); _updatePref(fontFamily: v); },
                  ),
                  const SizedBox(height: 16),
                  Text('Font Size (${_prefs.fontSizePx}px)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _prefs.fontSizePx.toDouble(),
                    min: 12,
                    max: 32,
                    divisions: 10,
                    onChanged: (v) { setSheetState(() => _prefs = _prefs.copyWith(fontSizePx: v.round())); _updatePref(fontSizePx: v.round()); },
                  ),
                  const SizedBox(height: 16),
                  const Text('Line Spacing', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _prefs.lineSpacing,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'compact', child: Text('Compact')),
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'relaxed', child: Text('Relaxed')),
                    ],
                    onChanged: (v) { setSheetState(() => _prefs = _prefs.copyWith(lineSpacing: v)); _updatePref(lineSpacing: v); },
                  ),
                  const SizedBox(height: 16),
                  const Text('Margins', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _prefs.margins,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'compact', child: Text('Compact')),
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'relaxed', child: Text('Relaxed')),
                    ],
                    onChanged: (v) { setSheetState(() => _prefs = _prefs.copyWith(margins: v)); _updatePref(margins: v); },
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPrefs) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final theme = Theme.of(context);
    
    Color bgColor;
    Color textColor;
    switch (_prefs.theme) {
      case 'dark':
        bgColor = const Color(0xFF111827);
        textColor = Colors.white;
        break;
      case 'sepia':
        bgColor = const Color(0xFFF4ECD8);
        textColor = const Color(0xFF5B4636);
        break;
      case 'amoled':
        bgColor = Colors.black;
        textColor = const Color(0xFFE5E7EB);
        break;
      case 'light':
      default:
        bgColor = const Color(0xFFFDFBF7);
        textColor = const Color(0xFF111827);
        break;
    }
    
    double margin;
    switch (_prefs.margins) {
      case 'compact': margin = 8.0; break;
      case 'relaxed': margin = 32.0; break;
      case 'normal':
      default: margin = 16.0; break;
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        title: Text(widget.chapter.title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('$_progress%', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: textColor),
            tooltip: 'Typography & Theme',
            onPressed: _showSettingsSheet,
          ),
          IconButton(
            icon: Icon(_mode == ReaderMode.scroll ? Icons.auto_stories : Icons.vertical_align_bottom, color: textColor),
            tooltip: 'Toggle View Mode',
            onPressed: _toggleMode,
          ),
          IconButton(
            icon: Icon(Icons.bookmark_add, color: textColor),
            tooltip: 'Add Bookmark',
            onPressed: () => _addAnnotation('bookmark'),
          ),
        ],
      ),
      floatingActionButton: _selectedText != null && _selectedText!.isNotEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedText!.trim().split(RegExp(r'\s+')).length == 1) ...[
                  FloatingActionButton.extended(
                    heroTag: 'define',
                    onPressed: _lookupDictionary,
                    label: const Text('Define'),
                    icon: const Icon(Icons.menu_book),
                    backgroundColor: Colors.blueAccent,
                  ),
                  const SizedBox(width: 8),
                ],
                FloatingActionButton.extended(
                  heroTag: 'highlight',
                  onPressed: () => _addAnnotation('highlight', color: '#fde047'),
                  label: const Text('Highlight'),
                  icon: const Icon(Icons.highlight),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (_syncPromptPercent != null)
              Container(
                color: Colors.blue.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Resume reading from your listening progress (~$_syncPromptPercent%)?",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _acceptSync,
                      child: const Text("Yes"),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _syncPromptPercent = null;
                          _syncHandled = true;
                        });
                      },
                      child: const Text("No"),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(margin),
                child: _mode == ReaderMode.scroll 
                  ? _buildScrollReader(textColor)
                  : _buildPaginatedReader(textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollReader(Color textColor) {
    return SelectionArea(
      onSelectionChanged: (content) {
        if (content != null && content.plainText.isNotEmpty) {
          setState(() => _selectedText = content.plainText);
        } else {
          setState(() => _selectedText = null);
        }
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        child: MarkdownBody(
          data: _applyAnnotations(widget.chapter.content),
          styleSheet: _markdownStyle(textColor),
        ),
      ),
    );
  }

  Widget _buildPaginatedReader(Color textColor) {
    if (_paragraphs.isEmpty) return const Center(child: Text('Empty chapter'));

    return SelectionArea(
      onSelectionChanged: (content) {
        if (content != null && content.plainText.isNotEmpty) {
          setState(() => _selectedText = content.plainText);
        } else {
          setState(() => _selectedText = null);
        }
      },
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => _onPageChanged(index, _paragraphs.length),
        itemCount: _paragraphs.length,
        itemBuilder: (context, index) {
          return Center(
            child: SingleChildScrollView(
              child: MarkdownBody(
                data: _applyAnnotations(_paragraphs[index]),
                styleSheet: _markdownStyle(textColor),
              ),
            ),
          );
        },
      ),
    );
  }

  String _applyAnnotations(String text) {
    // Basic substitution to render bold text for highlights to prove it works offline
    String modified = text;
    for (var a in _annotations) {
      if (a.annotationType == 'highlight' && a.selectedText != null && a.selectedText!.isNotEmpty) {
        modified = modified.replaceAll(a.selectedText!, '**${a.selectedText}**');
      }
    }
    return modified;
  }

  MarkdownStyleSheet _markdownStyle(Color textColor) {
    double lineHeight;
    switch (_prefs.lineSpacing) {
      case 'compact': lineHeight = 1.4; break;
      case 'relaxed': lineHeight = 2.0; break;
      case 'normal':
      default: lineHeight = 1.6; break;
    }

    return MarkdownStyleSheet(
      p: TextStyle(
        color: textColor,
        fontSize: _prefs.fontSizePx.toDouble(),
        height: lineHeight,
        fontFamily: _prefs.fontFamily == 'sans' ? 'sans-serif' : _prefs.fontFamily == 'mono' ? 'monospace' : 'serif',
      ),
      h1: TextStyle(
        color: textColor,
        fontSize: _prefs.fontSizePx.toDouble() * 1.5,
        fontFamily: _prefs.fontFamily == 'sans' ? 'sans-serif' : _prefs.fontFamily == 'mono' ? 'monospace' : 'serif',
        fontWeight: FontWeight.bold,
      ),
      h2: TextStyle(
        color: textColor,
        fontSize: _prefs.fontSizePx.toDouble() * 1.3,
        fontFamily: _prefs.fontFamily == 'sans' ? 'sans-serif' : _prefs.fontFamily == 'mono' ? 'monospace' : 'serif',
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _DictionarySheet extends StatefulWidget {
  final String word;
  const _DictionarySheet({required this.word});

  @override
  State<_DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends State<_DictionarySheet> {
  DictionaryEntry? _entry;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final repo = context.read<ILibraryRepository>();
      final result = await repo.getDefinition(widget.word);
      if (mounted) {
        setState(() {
          if (result != null) {
            _entry = result;
          } else {
            _error = 'Dictionary unavailable offline for this word, or word not found.';
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Dictionary unavailable offline for this word, or word not found.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 200,
        child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
      );
    }

    if (_entry == null) return const SizedBox.shrink();

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Text(_entry!.word, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            if (_entry!.phonetic != null)
              Text(_entry!.phonetic!, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            ..._entry!.meanings.map((m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.partOfSpeech, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    ...m.definitions.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 8, left: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ${d.definition}'),
                              if (d.example != null)
                                Text('"${d.example}"', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        )),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

