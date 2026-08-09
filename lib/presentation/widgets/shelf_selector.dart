import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/models/user_shelf.dart';
import '../pages/login_page.dart';

class ShelfSelector extends StatefulWidget {
  final String bookId;

  const ShelfSelector({super.key, required this.bookId});

  @override
  State<ShelfSelector> createState() => _ShelfSelectorState();
}

class _ShelfSelectorState extends State<ShelfSelector> {
  List<UserShelf> _shelves = [];
  bool _isAuthenticated = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    final authRepo = context.read<IAuthRepository>();
    final user = await authRepo.getCurrentUser();
    
    final isAuth = !user.isAnonymous;
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
      });
    }

    if (isAuth) {
      final libRepo = context.read<ILibraryRepository>();
      final shelves = await libRepo.getUserShelves();
      if (mounted) {
        setState(() {
          _shelves = shelves;
        });
      }
    }
  }

  void _showAuthDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign in to save to shelves'),
        content: const Text('Create an account or sign in to build your custom collection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ).then((_) => _checkAuthAndLoad());
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Future<void> _addToShelf(String shelfId) async {
    setState(() => _isUpdating = true);
    try {
      final libRepo = context.read<ILibraryRepository>();
      await libRepo.addBookToShelf(shelfId, widget.bookId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to shelf')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add to shelf')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated && _shelves.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: OutlinedButton(
          onPressed: _showAuthDialog,
          child: const Text('Add to Custom Shelf'),
        ),
      );
    }

    if (_shelves.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: _isUpdating 
        ? const Center(child: CircularProgressIndicator())
        : DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Add to Custom Shelf',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _shelves.map((s) => DropdownMenuItem(
              value: s.id,
              child: Text(s.name),
            )).toList(),
            onChanged: (val) {
              if (val != null) {
                _addToShelf(val);
              }
            },
            initialValue: null,
          ),
    );
  }
}
