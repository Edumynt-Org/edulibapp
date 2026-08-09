import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/models/user_shelf.dart';
import 'book_details_page.dart';

class ShelfPage extends StatefulWidget {
  final UserShelf shelf;

  const ShelfPage({super.key, required this.shelf});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  List<UserShelfItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final repo = context.read<ILibraryRepository>();
    try {
      final items = await repo.getShelfItems(widget.shelf.id);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeItem(String bookId) async {
    final repo = context.read<ILibraryRepository>();
    await repo.removeBookFromShelf(widget.shelf.id, bookId);
    _loadItems();
  }

  Future<void> _moveUp(int index) async {
    if (index == 0) return;
    setState(() {
      final temp = _items[index - 1];
      _items[index - 1] = _items[index];
      _items[index] = temp;
    });
    final repo = context.read<ILibraryRepository>();
    await repo.reorderShelf(widget.shelf.id, _items.map((e) => e.bookId).toList());
  }

  Future<void> _moveDown(int index) async {
    if (index == _items.length - 1) return;
    setState(() {
      final temp = _items[index + 1];
      _items[index + 1] = _items[index];
      _items[index] = temp;
    });
    final repo = context.read<ILibraryRepository>();
    await repo.reorderShelf(widget.shelf.id, _items.map((e) => e.bookId).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shelf.name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.shelf.description != null && widget.shelf.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.shelf.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                if (widget.shelf.isPrivate)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('Private Shelf', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('This shelf is empty.'))
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final book = item.book;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: book?.coverUrl != null
                                    ? Image.network(book!.coverUrl!, width: 40, height: 60, fit: BoxFit.cover)
                                    : Container(width: 40, height: 60, color: Colors.grey[300]),
                                title: Text(book?.title ?? 'Unknown Book'),
                                subtitle: Text(book?.author ?? 'Unknown Author'),
                                onTap: () {
                                  if (book != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => BookDetailsPage(slug: book.slug)),
                                    );
                                  }
                                },
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_upward, size: 20),
                                      onPressed: index > 0 ? () => _moveUp(index) : null,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.arrow_downward, size: 20),
                                      onPressed: index < _items.length - 1 ? () => _moveDown(index) : null,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                      onPressed: () => _removeItem(item.bookId),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
