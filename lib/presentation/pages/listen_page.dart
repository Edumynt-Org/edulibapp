import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/models/book_details.dart';
import '../../domain/models/audio_edition.dart' as ae;
import '../../domain/models/audio_chapter.dart' as ac;
import '../widgets/audio_player_widget.dart';

class ListenPage extends StatelessWidget {
  final String slug;

  const ListenPage({super.key, required this.slug});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ILibraryRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listen'),
      ),
      body: FutureBuilder<BookDetails?>(
        future: repository.getBookDetails(slug),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final book = snapshot.data;
          if (book == null) {
            return const Center(child: Text('Book not found.'));
          }

          if (book.audioEditions.isEmpty) {
            return const Center(child: Text('No audio edition available.'));
          }

          final detailAudioEdition = book.audioEditions.first;
          
          // Map to standard AudioEdition
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

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: audioEdition.cover != null
                            ? Image.network(
                                audioEdition.cover!,
                                height: 300,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlaceholder(),
                              )
                            : _buildPlaceholder(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        audioEdition.title,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        audioEdition.narratorName != null
                            ? 'Narrated by ${audioEdition.narratorName}'
                            : 'By ${book.author}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              if (mappedChapters.isNotEmpty)
                AudioPlayerWidget(edition: audioEdition)
              else
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No audio files found for this edition.'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 300,
      width: 200,
      color: Colors.grey.shade300,
      child: const Center(
        child: Icon(Icons.audiotrack, size: 64, color: Colors.grey),
      ),
    );
  }
}

