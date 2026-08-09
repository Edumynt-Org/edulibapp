import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/library_repository.dart';


class LibraryStatusSelector extends StatefulWidget {
  final String bookId;

  const LibraryStatusSelector({super.key, required this.bookId});

  @override
  State<LibraryStatusSelector> createState() => _LibraryStatusSelectorState();
}

class _LibraryStatusSelectorState extends State<LibraryStatusSelector> {
  String? _currentStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPendingAction();
  }

  Future<void> _checkPendingAction() async {
    final prefs = await SharedPreferences.getInstance();
    
    final pendingStatus = prefs.getString('pending_status_${widget.bookId}');
    if (pendingStatus != null) {
      await prefs.remove('pending_status_${widget.bookId}');
      await _updateStatus(pendingStatus);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      final libraryRepo = context.read<ILibraryRepository>();
      await libraryRepo.updateBookStatus(widget.bookId, newStatus);
      setState(() => _currentStatus = newStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update library status')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleStatusSelect(String newStatus) async {
    await _updateStatus(newStatus);
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String>(
          value: _currentStatus,
          hint: const Text('Add to Library...'),
          icon: const Icon(Icons.arrow_drop_down),
          isExpanded: true,
          onChanged: _isLoading ? null : (value) {
            if (value != null) _handleStatusSelect(value);
          },
          items: const [
            DropdownMenuItem(value: 'want_to_read', child: Text('Want to Read')),
            DropdownMenuItem(value: 'reading', child: Text('Reading')),
            DropdownMenuItem(value: 'completed', child: Text('Completed')),
            DropdownMenuItem(value: 'paused', child: Text('Paused')),
            DropdownMenuItem(value: 'dropped', child: Text('Dropped')),
          ],
        ),
      ),
    );
  }
}
