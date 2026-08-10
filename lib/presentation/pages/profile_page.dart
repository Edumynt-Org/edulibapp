import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/models/user_shelf.dart';
import '../widgets/follow_button.dart';
import 'shelf_page.dart';
import 'milestones_tab.dart';

class ProfilePage extends StatefulWidget {
  final String username;

  const ProfilePage({super.key, required this.username});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<UserShelf> _publicShelves = [];
  int _streakCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPublicShelves();
  }

  Future<void> _loadPublicShelves() async {
    final repo = context.read<ILibraryRepository>();
    try {
      final shelves = await repo.getPublicShelves(widget.username);
      final streak = await repo.getDailyStreakCount(widget.username);
      if (mounted) {
        setState(() {
          _publicShelves = shelves;
          _streakCount = streak;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("\${widget.username}'s Profile"),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Shelves & Info'),
              Tab(text: 'Milestones & Badges'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildShelvesTab(),
                  MilestonesTab(profileId: widget.username), // assuming username is used as profileId
                ],
              ),
      ),
    );
  }

  Widget _buildShelvesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  widget.username.substring(0, 1).toUpperCase(),
                  style: TextStyle(fontSize: 24, color: Colors.blue.shade900),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.username,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text('Public Bookshelves'),
                  if (_streakCount > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text('🔥'),
                          const SizedBox(width: 8),
                          Text(
                            '\${_streakCount} Day Streak',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const Spacer(),
              FollowButton(
                targetProfileId: widget.username,
                repository: context.read<IProfileRepository>(),
              ),
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Public Shelves', style: Theme.of(context).textTheme.titleLarge),
        ),
        Expanded(
          child: _publicShelves.isEmpty
              ? Center(child: Text("\${widget.username} hasn't made any shelves public yet."))
              : ListView.builder(
                  itemCount: _publicShelves.length,
                  itemBuilder: (context, index) {
                    final shelf = _publicShelves[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(shelf.name),
                        subtitle: Text(shelf.description ?? 'No description', maxLines: 2, overflow: TextOverflow.ellipsis),
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
        ),
      ],
    );
  }
}
