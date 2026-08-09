import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../application/services/audio_player_service.dart';

class GlobalAudioPlayer extends StatefulWidget {
  const GlobalAudioPlayer({super.key});

  @override
  State<GlobalAudioPlayer> createState() => _GlobalAudioPlayerState();
}

class _GlobalAudioPlayerState extends State<GlobalAudioPlayer> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, audioService, child) {
        if (audioService.currentEdition == null) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isExpanded ? MediaQuery.of(context).size.height : 76,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: _isExpanded
                  ? _buildExpanded(context, audioService)
                  : _buildMini(context, audioService),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMini(BuildContext context, AudioPlayerService audioService) {
    final chapter = audioService.currentChapter;
    final edition = audioService.currentEdition!;
    if (chapter == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = true),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              if (edition.cover != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(edition.cover!, width: 48, height: 48, fit: BoxFit.cover),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(chapter.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(edition.title, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _buildPlayPauseButton(audioService),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => audioService.stopAndDismiss(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded(BuildContext context, AudioPlayerService audioService) {
    final chapter = audioService.currentChapter;
    final edition = audioService.currentEdition!;
    if (chapter == null) return const SizedBox.shrink();

    return SafeArea(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: () => setState(() => _isExpanded = false),
              ),
              const Expanded(
                child: Text('Now Playing', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 48), // balance the close button
            ],
          ),
          const SizedBox(height: 24),
          if (edition.cover != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(edition.cover!, width: 240, height: 240, fit: BoxFit.cover),
            ),
          const SizedBox(height: 32),
          Text(chapter.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(edition.title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: _buildProgressBar(audioService),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.skip_previous, size: 36), onPressed: audioService.prevTrack),
              IconButton(icon: const Icon(Icons.replay_10, size: 36), onPressed: () => audioService.skip(-10)),
              _buildPlayPauseButton(audioService, size: 64),
              IconButton(icon: const Icon(Icons.forward_30, size: 36), onPressed: () => audioService.skip(30)),
              IconButton(icon: const Icon(Icons.skip_next, size: 36), onPressed: audioService.nextTrack),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const Padding(
             padding: EdgeInsets.all(16.0),
             child: Align(alignment: Alignment.centerLeft, child: Text('Chapters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: edition.chapters.length,
              itemBuilder: (context, index) {
                final ch = edition.chapters[index];
                final isCurrent = index == audioService.currentIndex;
                return ListTile(
                  title: Text(ch.title, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isCurrent ? Theme.of(context).colorScheme.primary : null)),
                  trailing: isCurrent ? const Icon(Icons.graphic_eq) : null,
                  onTap: () {
                     audioService.playEdition(edition, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseButton(AudioPlayerService audioService, {double size = 32}) {
    return StreamBuilder<PlayerState>(
      stream: audioService.player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final playing = playerState?.playing ?? false;
        if (audioService.isLoading) {
          return SizedBox(width: size, height: size, child: const CircularProgressIndicator());
        }
        return IconButton(
          iconSize: size,
          icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
          onPressed: () {
            if (playing) {
              audioService.pause();
            } else {
              audioService.play();
            }
          },
        );
      },
    );
  }

  Widget _buildProgressBar(AudioPlayerService audioService) {
    return StreamBuilder<Duration>(
      stream: audioService.player.positionStream,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final dur = audioService.player.duration ?? Duration(seconds: audioService.currentChapter?.durationSeconds ?? 1);
        return Row(
          children: [
            Text(_formatDuration(pos), style: const TextStyle(fontSize: 12)),
            Expanded(
              child: Slider(
                value: pos.inSeconds.toDouble().clamp(0.0, dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0),
                max: dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0,
                onChanged: (v) {
                  audioService.seek(Duration(seconds: v.toInt()));
                },
              ),
            ),
            Text(_formatDuration(dur), style: const TextStyle(fontSize: 12)),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration? d) {
    if (d == null) return "0:00";
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return "$min:${sec.toString().padLeft(2, '0')}";
  }
}
