import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/models/chapter.dart';
import '../widgets/reader_engine.dart';

class ReaderPage extends StatefulWidget {
  final String chapterSlug;

  const ReaderPage({Key? key, required this.chapterSlug}) : super(key: key);

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  Chapter? _chapter;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChapter();
  }

  Future<void> _loadChapter() async {
    try {
      final repo = context.read<ILibraryRepository>();
      final chapter = await repo.getChapter(widget.chapterSlug);
      
      if (mounted) {
        if (chapter != null) {
          setState(() {
            _chapter = chapter;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Chapter not found';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load chapter. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _chapter == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error ?? 'Chapter not found')),
      );
    }

    return ReaderEngine(chapter: _chapter!);
  }
}
