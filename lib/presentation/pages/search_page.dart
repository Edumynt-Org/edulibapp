import 'package:flutter/material.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/models/book.dart';
import 'book_details_page.dart';

class CatalogSearchDelegate extends SearchDelegate<Book?> {
  final ILibraryRepository repository;

  CatalogSearchDelegate(this.repository);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<Book>>(
      future: repository.searchCatalog(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(child: Text('No results found.'));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final book = results[index];
            return ListTile(
              leading: book.coverUrl != null
                  ? Image.network(book.coverUrl!, width: 50, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.book))
                  : const Icon(Icons.book),
              title: Text(book.title),
              subtitle: Text(book.author),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => BookDetailsPage(slug: book.slug)),
                );
              },
            );
          },
        );
      },
    );
  }
}
