import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/models/user_shelf.dart';
import '../pages/shelf_page.dart';

class CustomShelvesList extends StatefulWidget {
  final bool isAuthenticated;

  const CustomShelvesList({super.key, required this.isAuthenticated});

  @override
  State<CustomShelvesList> createState() => _CustomShelvesListState();
}

class _CustomShelvesListState extends State<CustomShelvesList> {
  List<UserShelf> _shelves = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.isAuthenticated) {
      _loadShelves();
    } else {
      _loading = false;
    }
  }
  
  @override
  void didUpdateWidget(CustomShelvesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAuthenticated && !oldWidget.isAuthenticated) {
      _loadShelves();
    }
  }

  Future<void> _loadShelves() async {
    setState(() => _loading = true);
    try {
      final repo = context.read<ILibraryRepository>();
      final shelves = await repo.getUserShelves();
      if (mounted) {
        setState(() {
          _shelves = shelves;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateShelfModal(BuildContext context) {
    if (!widget.isAuthenticated) {
      // Typically trigger auth login redirect here if intercepting, 
      // but in this list, we only show 'Create' button if authenticated usually
      return;
    }

    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isPrivate = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16, right: 16, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create New Shelf', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Switch(
                        value: isPrivate,
                        onChanged: (val) => setStateSB(() => isPrivate = val),
                      ),
                      const Text('Private (Only you can see this shelf)'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) return;
                        final repo = ctx.read<ILibraryRepository>();
                        await repo.createCustomShelf(
                          nameController.text.trim(),
                          isPrivate,
                          description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _loadShelves();
                        }
                      },
                      child: const Text('Create'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAuthenticated) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Custom Shelves', style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () => _showCreateShelfModal(context),
              child: const Text('Create'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_shelves.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('You have no custom shelves yet.'),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _shelves.length,
            itemBuilder: (context, index) {
              final shelf = _shelves[index];
              return Card(
                child: ListTile(
                  title: Text(shelf.name),
                  subtitle: Text(shelf.description ?? 'No description', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: shelf.isPrivate ? const Icon(Icons.lock, size: 16) : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ShelfPage(shelf: shelf)),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}
