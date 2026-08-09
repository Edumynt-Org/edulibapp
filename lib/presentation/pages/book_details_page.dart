import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/models/book_details.dart';
import 'reader_page.dart';
import '../../domain/models/audio_edition.dart' as ae;
import '../../domain/models/audio_chapter.dart' as ac;
import '../../application/services/audio_player_service.dart';
import '../widgets/library_status_selector.dart';
import '../widgets/shelf_selector.dart';
import '../widgets/reviews_section.dart';

class BookDetailsPage extends StatefulWidget {
  final String slug;

  const BookDetailsPage({super.key, required this.slug});

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> with SingleTickerProviderStateMixin {
  late Future<BookDetails?> _bookFuture;
  late TabController _tabController;
  
  Edition? _selectedTextEdition;
  AudioEdition? _selectedAudioEdition;
  Object? _selectedTocEdition;

  int _detailsSegmentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = context.read<ILibraryRepository>();
    _bookFuture = repository.getBookDetails(widget.slug).then((book) {
      if (book != null) {
        if (book.editions.isNotEmpty) {
          _selectedTextEdition = book.editions.first;
          _selectedTocEdition = _selectedTextEdition;
        }
        if (book.audioEditions.isNotEmpty) {
          _selectedAudioEdition = book.audioEditions.first;
          _selectedTocEdition ??= _selectedAudioEdition;
        }
      }
      return book;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<BookDetails?>(
        future: _bookFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: const Text('Book Details')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Book Details')),
              body: Center(child: Text('Error: ${snapshot.error}')),
            );
          }

          final book = snapshot.data;
          if (book == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Book Details')),
              body: const Center(child: Text('Book not found.')),
            );
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: Text(book.title),
                  pinned: true,
                  floating: true,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildCover(book.coverUrl),
                        const SizedBox(height: 24),
                        Text(
                          book.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'By ${book.author}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        LibraryStatusSelector(bookId: book.id),
                        const SizedBox(height: 8),
                        ShelfSelector(bookId: book.id),
                        const SizedBox(height: 16),
                        _buildActionButtons(context, book),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Content'),
                        Tab(text: 'Details'),
                        Tab(text: 'Reviews'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildContentTab(book),
                _buildDetailsTab(book),
                _buildReviewsTab(book),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCover(String? coverUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: coverUrl != null
          ? Image.network(
              coverUrl,
              height: 240,
              width: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildPlaceholder(),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 240,
      width: 160,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.book, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, BookDetails book) {
    return Row(
      children: [
        if (book.editions.isNotEmpty)
          Expanded(
            child: _buildReadButton(context, book),
          ),
        if (book.editions.isNotEmpty && book.audioEditions.isNotEmpty)
          const SizedBox(width: 16),
        if (book.audioEditions.isNotEmpty)
          Expanded(
            child: _buildListenButton(context, book),
          ),
      ],
    );
  }

  Widget _buildReadButton(BuildContext context, BookDetails book) {
    if (book.editions.length == 1) {
      return FilledButton.icon(
        onPressed: _onReadPressed,
        icon: const Icon(Icons.menu_book),
        label: const Text('Read'),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
              ),
            ),
            onPressed: _onReadPressed,
            icon: const Icon(Icons.menu_book),
            label: const Text('Read'),
          ),
        ),
        const SizedBox(width: 1),
        Expanded(
          flex: 1,
          child: FilledButton(
            style: FilledButton.styleFrom(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
              ),
              padding: EdgeInsets.zero,
            ),
            onPressed: () => _showEditionSelector(context, book.editions, true),
            child: const Icon(Icons.arrow_drop_down),
          ),
        ),
      ],
    );
  }

  Widget _buildListenButton(BuildContext context, BookDetails book) {
    if (book.audioEditions.length == 1) {
      return OutlinedButton.icon(
        onPressed: _onListenPressed,
        icon: const Icon(Icons.headphones),
        label: const Text('Listen'),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
              ),
            ),
            onPressed: _onListenPressed,
            icon: const Icon(Icons.headphones),
            label: const Text('Listen'),
          ),
        ),
        const SizedBox(width: 1),
        Expanded(
          flex: 1,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
              ),
              padding: EdgeInsets.zero,
            ),
            onPressed: () => _showEditionSelector(context, book.audioEditions, false),
            child: const Icon(Icons.arrow_drop_down),
          ),
        ),
      ],
    );
  }

  void _onReadPressed() {
    if (_selectedTextEdition != null && _selectedTextEdition!.chapters.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderPage(
            chapterSlug: _selectedTextEdition!.chapters.first.slug,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No content available to read.')),
      );
    }
  }

  void _onListenPressed() {
    if (_selectedAudioEdition != null) {
      _bookFuture.then((book) {
        if (book != null) {
          _playAudioChapter(_selectedAudioEdition!, book, 0);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audio edition available.')),
      );
    }
  }

  void _playAudioChapter(AudioEdition detailAudioEdition, BookDetails book, int index) {
    final mappedChapters = <ac.AudioChapter>[];
    for (final part in detailAudioEdition.parts) {
      for (final chapter in part.audioChapters) {
        mappedChapters.add(ac.AudioChapter(
          id: chapter.id,
          bookId: book.id,
          editionId: detailAudioEdition.id,
          title: chapter.title,
          slug: chapter.slug,
          audioFileUrl: chapter.audioFile ?? '',
          durationSeconds: chapter.durationSeconds ?? 0,
          linkedTextChapter: chapter.linkedTextChapter,
        ));
      }
    }
    for (final chapter in detailAudioEdition.audioChapters) {
        mappedChapters.add(ac.AudioChapter(
          id: chapter.id,
          bookId: book.id,
          editionId: detailAudioEdition.id,
          title: chapter.title,
          slug: chapter.slug,
          audioFileUrl: chapter.audioFile ?? '',
          durationSeconds: chapter.durationSeconds ?? 0,
          linkedTextChapter: chapter.linkedTextChapter,
        ));
    }

    final audioEdition = ae.AudioEdition(
      id: detailAudioEdition.id,
      bookId: book.id,
      title: detailAudioEdition.title ?? book.title,
      slug: detailAudioEdition.slug ?? book.slug,
      language: detailAudioEdition.language ?? 'en',
      cover: detailAudioEdition.cover ?? book.coverUrl,
      narratorName: detailAudioEdition.narratorName,
      chapters: mappedChapters,
    );

    context.read<AudioPlayerService>().playEdition(audioEdition, index);
  }

  void _showEditionSelector(BuildContext context, List<dynamic> editions, bool isText) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  isText ? 'Select Text Edition' : 'Select Audio Edition',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(),
              ...editions.map((edition) {
                final isSelected = isText 
                  ? edition == _selectedTextEdition 
                  : edition == _selectedAudioEdition;
                return ListTile(
                  title: Text(edition.title ?? (isText ? 'Text Edition' : 'Audio Edition')),
                  subtitle: Text(edition.language ?? 'Unknown Language'),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () {
                    setState(() {
                      if (isText) {
                        _selectedTextEdition = edition;
                        _selectedTocEdition = edition;
                      } else {
                        _selectedAudioEdition = edition;
                        _selectedTocEdition = edition;
                      }
                    });
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContentTab(BookDetails book) {
    if (_selectedTocEdition == null) {
      return const Center(child: Text('No content available.'));
    }

    if (_selectedTocEdition is Edition) {
      final edition = _selectedTocEdition as Edition;
      if (edition.parts.isEmpty && edition.chapters.isEmpty) {
        return const Center(child: Text('No chapters found for this edition.'));
      }
      return ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (edition.parts.isNotEmpty)
            ...edition.parts.map((part) => ExpansionTile(
              title: Text(part.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: part.description != null ? Text(part.description!) : null,
              children: part.chapters.map((chapter) => ListTile(
                title: Text(chapter.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReaderPage(chapterSlug: chapter.slug),
                    ),
                  );
                },
              )).toList(),
            ))
          else if (edition.chapters.isNotEmpty)
            ...edition.chapters.map((chapter) => ListTile(
              title: Text(chapter.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReaderPage(chapterSlug: chapter.slug),
                  ),
                );
              },
            )),
        ],
      );
    } else if (_selectedTocEdition is AudioEdition) {
      final audioEdition = _selectedTocEdition as AudioEdition;
      if (audioEdition.parts.isEmpty && audioEdition.audioChapters.isEmpty) {
        return const Center(child: Text('No audio chapters found for this edition.'));
      }
      
      final children = <Widget>[];
      int globalIndex = 0;
      
      if (audioEdition.parts.isNotEmpty) {
        for (final part in audioEdition.parts) {
          final partChildren = <Widget>[];
          for (final chapter in part.audioChapters) {
            final currentIndex = globalIndex++;
            partChildren.add(ListTile(
              title: Text(chapter.title),
              trailing: const Icon(Icons.play_circle_outline),
              onTap: () => _playAudioChapter(audioEdition, book, currentIndex),
            ));
          }
          children.add(ExpansionTile(
            title: Text(part.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: part.description != null ? Text(part.description!) : null,
            children: partChildren,
          ));
        }
      } else if (audioEdition.audioChapters.isNotEmpty) {
        for (final chapter in audioEdition.audioChapters) {
          final currentIndex = globalIndex++;
          children.add(ListTile(
            title: Text(chapter.title),
            trailing: const Icon(Icons.play_circle_outline),
            onTap: () => _playAudioChapter(audioEdition, book, currentIndex),
          ));
        }
      }
      
      return ListView(
        padding: const EdgeInsets.all(16.0),
        children: children,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDetailsTab(BookDetails book) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Book')),
              ButtonSegment(value: 1, label: Text('Edition')),
            ],
            selected: {_detailsSegmentIndex},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                _detailsSegmentIndex = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 24),
          if (_detailsSegmentIndex == 0)
            _buildBookDetailsView(book)
          else
            _buildEditionDetailsView(),
        ],
      ),
    );
  }

  Widget _buildBookDetailsView(BookDetails book) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          book.description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 24),
        if (book.originalTitle != null) ...[
          _buildDetailRow('Original Title', book.originalTitle!),
          const SizedBox(height: 8),
        ],
        if (book.originalLanguage != null) ...[
          _buildDetailRow('Original Language', book.originalLanguage!),
          const SizedBox(height: 8),
        ],
        if (book.firstPublishedYear != null) ...[
          _buildDetailRow('First Published', book.firstPublishedYear!.toString()),
        ],
      ],
    );
  }

  Widget _buildEditionDetailsView() {
    if (_selectedTocEdition == null) {
      return const Text('No edition selected.');
    }

    if (_selectedTocEdition is Edition) {
      final edition = _selectedTocEdition as Edition;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (edition.title != null) ...[
            _buildDetailRow('Title', edition.title!),
            const SizedBox(height: 8),
          ],
          if (edition.format != null) ...[
            _buildDetailRow('Format', edition.format!),
            const SizedBox(height: 8),
          ],
          if (edition.isbn != null) ...[
            _buildDetailRow('ISBN', edition.isbn!),
            const SizedBox(height: 8),
          ],
          if (edition.pages != null) ...[
            _buildDetailRow('Pages', edition.pages!.toString()),
            const SizedBox(height: 8),
          ],
          if (edition.language != null) ...[
            _buildDetailRow('Language', edition.language!),
          ],
        ],
      );
    } else if (_selectedTocEdition is AudioEdition) {
      final audioEdition = _selectedTocEdition as AudioEdition;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (audioEdition.title != null) ...[
            _buildDetailRow('Title', audioEdition.title!),
            const SizedBox(height: 8),
          ],
          if (audioEdition.narratorName != null) ...[
            _buildDetailRow('Narrator', audioEdition.narratorName!),
            const SizedBox(height: 8),
          ],
          if (audioEdition.language != null) ...[
            _buildDetailRow('Language', audioEdition.language!),
            const SizedBox(height: 8),
          ],
          _buildDetailRow('Status', audioEdition.isComplete ? 'Complete' : 'Incomplete'),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  Widget _buildReviewsTab(BookDetails book) {
    return ReviewsSection(bookId: book.id);
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
