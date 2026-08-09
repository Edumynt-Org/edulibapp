import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/models/review.dart';
import '../pages/login_page.dart';

class ReviewsSection extends StatefulWidget {
  final String bookId;
  const ReviewsSection({super.key, required this.bookId});

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _checkPendingReview();
  }

  Future<void> _loadReviews() async {
    try {
      final repo = context.read<ILibraryRepository>();
      final reviews = await repo.getReviewsForBook(widget.bookId);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load reviews';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkPendingReview() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString('pending_review_${widget.bookId}');
    if (pending == 'open') {
      await prefs.remove('pending_review_${widget.bookId}');
      final authRepo = context.read<IAuthRepository>();
      final user = await authRepo.getCurrentUser();
      if (!user.isAnonymous) {
        if (mounted) {
          _showReviewModal();
        }
      }
    }
  }

  Future<void> _handleWriteReview() async {
    final authRepo = context.read<IAuthRepository>();
    final user = await authRepo.getCurrentUser();
    if (user.isAnonymous) {
      _showAuthDialog();
    } else {
      _showReviewModal();
    }
  }

  void _showAuthDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign in to write a review'),
        content: const Text('Create an account or sign in before sharing your rating with the community.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('pending_review_${widget.bookId}', 'open');
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                ).then((_) => _checkPendingReview());
              }
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showReviewModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ReviewForm(
          bookId: widget.bookId,
          onSubmitted: () {
            Navigator.pop(ctx);
            _loadReviews();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    double avgRating = 0.0;
    if (_reviews.isNotEmpty) {
      avgRating = _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reviews.isEmpty ? '—' : avgRating.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                StarRating(rating: avgRating),
                const SizedBox(height: 4),
                Text('Based on ${_reviews.length} review${_reviews.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.grey)),
              ],
            ),
            FilledButton.tonalIcon(
              onPressed: _handleWriteReview,
              icon: const Icon(Icons.edit),
              label: const Text('Write a Review'),
            ),
          ],
        ),
        const Divider(height: 48),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_reviews.isEmpty)
          const Text('No reviews yet. Be the first to share your thoughts.', style: TextStyle(color: Colors.grey)),
        ..._reviews.map((r) => Column(
          children: [
            ReviewCard(review: r),
            const Divider(),
          ],
        )).toList(),
      ],
    );
  }
}

class StarRating extends StatelessWidget {
  final double rating;
  const StarRating({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        if (rating >= index + 1) return const Icon(Icons.star, color: Colors.amber, size: 20);
        if (rating > index) return const Icon(Icons.star_half, color: Colors.amber, size: 20);
        return const Icon(Icons.star_border, color: Colors.amber, size: 20);
      }),
    );
  }
}

class ReviewCard extends StatefulWidget {
  final Review review;
  const ReviewCard({super.key, required this.review});

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  late bool _revealed;

  @override
  void initState() {
    super.initState();
    _revealed = !widget.review.containsSpoilers;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Reader review', style: TextStyle(fontWeight: FontWeight.bold)),
              StarRating(rating: widget.review.rating),
            ],
          ),
          const SizedBox(height: 4),
          if (widget.review.title != null && widget.review.title!.isNotEmpty)
            Text(widget.review.title!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          !_revealed
            ? InkWell(
                onTap: () => setState(() => _revealed = true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('⚠️ Spoiler Alert — Tap to view review contents.', textAlign: TextAlign.center),
                ),
              )
            : MarkdownBody(data: widget.review.body),
        ],
      ),
    );
  }
}

class ReviewForm extends StatefulWidget {
  final String bookId;
  final VoidCallback onSubmitted;
  const ReviewForm({super.key, required this.bookId, required this.onSubmitted});

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  double _rating = 0.0;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _containsSpoilers = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Write a Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text('Rating: ${_rating.toStringAsFixed(1)} / 5'),
          Slider(
            value: _rating,
            min: 0,
            max: 5,
            divisions: 10,
            onChanged: (val) => setState(() => _rating = val),
          ),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title (optional)'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyController,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Review (Markdown supported)', border: OutlineInputBorder()),
          ),
          CheckboxListTile(
            title: const Text('This review contains spoilers'),
            value: _containsSpoilers,
            onChanged: (val) => setState(() => _containsSpoilers = val ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Publish Review'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_rating == 0 || _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a rating and write a review.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final repo = context.read<ILibraryRepository>();
      final authRepo = context.read<IAuthRepository>();
      final user = await authRepo.getCurrentUser();
      await repo.createReview(ReviewDraft(
        profileId: user.id,
        bookId: widget.bookId,
        rating: _rating,
        title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        body: _bodyController.text.trim(),
        containsSpoilers: _containsSpoilers,
      ));
      widget.onSubmitted();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to publish review')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
