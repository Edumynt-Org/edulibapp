import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../pages/login_page.dart';

class FollowButton extends StatefulWidget {
  final String targetProfileId;
  final IProfileRepository repository;

  const FollowButton({
    super.key,
    required this.targetProfileId,
    required this.repository,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool _isFollowing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final authRepo = context.read<IAuthRepository>();
    final user = await authRepo.getCurrentUser();
    if (!user.isAnonymous) {
      widget.repository.setCurrentUserId(user.id);
    }
    
    final status = await widget.repository.checkIsFollowing(widget.targetProfileId);
    if (mounted) {
      setState(() {
        _isFollowing = status;
        _isLoading = false;
      });
    }
  }

  void _showAuthDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign in to follow'),
        content: const Text('Create an account or sign in to build your reading network.'),
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
              ).then((_) => _checkStatus());
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFollow() async {
    final authRepo = context.read<IAuthRepository>();
    final user = await authRepo.getCurrentUser();
    
    if (user.isAnonymous) {
      _showAuthDialog();
      return;
    }
    
    widget.repository.setCurrentUserId(user.id);
    final previousState = _isFollowing;
    
    // Optimistic UI update
    setState(() {
      _isFollowing = !previousState;
    });

    try {
      if (previousState) {
        await widget.repository.unfollowUser(widget.targetProfileId);
      } else {
        await widget.repository.followUser(widget.targetProfileId);
      }
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _isFollowing = previousState;
        });
      }
      debugPrint('Follow action failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ElevatedButton(
        onPressed: null,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return ElevatedButton(
      onPressed: _toggleFollow,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isFollowing ? Colors.grey[200] : Theme.of(context).primaryColor,
        foregroundColor: _isFollowing ? Colors.black87 : Colors.white,
        elevation: 0,
      ),
      child: Text(_isFollowing ? 'Unfollow' : 'Follow'),
    );
  }
}
