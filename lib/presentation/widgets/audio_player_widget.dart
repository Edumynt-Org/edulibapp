import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../domain/models/audio_edition.dart';
import '../../domain/models/audio_chapter.dart';
import '../../domain/models/audio_progress.dart';
import '../../domain/repositories/library_repository.dart';
import 'dart:async';

class AudioPlayerWidget extends StatefulWidget {
  final AudioEdition edition;
  final int initialChapterIndex;

  const AudioPlayerWidget({
    super.key,
    required this.edition,
    this.initialChapterIndex = 0,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  late int _currentIndex;
  bool _isLoading = true;
  Timer? _saveProgressTimer;
  Timer? _sleepTimer;
  
  double _playbackRate = 1.0;
  int? _sleepTimerSeconds; // null: no timer, -1: EOC
  bool _sleepTimerActive = false;

  int? _syncPromptPercent;
  bool _syncHandled = false;

  AudioChapter get _currentChapter => widget.edition.chapters[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialChapterIndex;
    _player = AudioPlayer();
    _init();

    _saveProgressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_player.playing) {
        _saveProgress();
      }
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_sleepTimerSeconds == -1 && _sleepTimerActive) {
          _saveProgress();
          _player.pause();
          setState(() {
            _sleepTimerActive = false;
            _sleepTimerSeconds = null;
          });
        } else {
          _nextTrack();
        }
      }
    });
  }

  Future<void> _init() async {
    setState(() {
      _isLoading = true;
      _syncPromptPercent = null;
      _syncHandled = false;
    });
    try {
      final repo = context.read<ILibraryRepository>();
      final progress = await repo.getAudioProgress(widget.edition.bookId, _currentChapter.id);
      
      final url = _currentChapter.audioFileUrl;
      await _player.setUrl(url);
      
      if (progress != null) {
        await _player.seek(Duration(seconds: progress.positionSeconds));
      } else if (_currentChapter.linkedTextChapter != null && !_syncHandled) {
        final textProgress = await repo.getChapterProgress(_currentChapter.linkedTextChapter!);
        if (textProgress != null && textProgress.progressPercent > 0) {
          setState(() {
            _syncPromptPercent = textProgress.progressPercent;
          });
        }
      }
    } catch (e) {
      debugPrint("Error initializing audio: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProgress() async {
    if (!mounted) return;
    try {
      final repo = context.read<ILibraryRepository>();
      final position = _player.position.inSeconds;
      final duration = _player.duration?.inSeconds ?? _currentChapter.durationSeconds;
      
      final progress = AudioProgress(
        bookId: widget.edition.bookId,
        audioChapterId: _currentChapter.id,
        positionSeconds: position,
        durationSeconds: duration,
        status: 'started',
        lastListenedAt: DateTime.now(),
      );
      await repo.saveAudioProgress(progress);
    } catch (e) {
      debugPrint("Error saving progress: \$e");
    }
  }

  void _nextTrack() async {
    await _saveProgress();
    if (_currentIndex < widget.edition.chapters.length - 1) {
      setState(() {
        _currentIndex++;
        _isLoading = true;
      });
      await _init();
      _player.play();
    }
  }

  void _prevTrack() async {
    await _saveProgress();
    if (_player.position.inSeconds > 3) {
      _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isLoading = true;
      });
      await _init();
      _player.play();
    }
  }

  void _skip(int seconds) {
    final current = _player.position;
    final newPos = current + Duration(seconds: seconds);
    _player.seek(newPos);
  }

  void _setPlaybackRate(double rate) {
    setState(() => _playbackRate = rate);
    _player.setSpeed(rate);
  }

  void _setSleepTimer(int? seconds) {
    _sleepTimer?.cancel();
    setState(() {
      _sleepTimerSeconds = seconds;
      _sleepTimerActive = seconds != null;
    });
    if (seconds == null || seconds == -1) {
      _player.setVolume(1.0);
      return;
    }

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_player.playing) return;
      
      setState(() {
        if (_sleepTimerSeconds != null && _sleepTimerSeconds! > 0) {
          _sleepTimerSeconds = _sleepTimerSeconds! - 1;
          if (_sleepTimerSeconds! <= 4) {
            // Fade out
            final newVolume = (_player.volume - 0.25).clamp(0.0, 1.0);
            _player.setVolume(newVolume);
          }
          if (_sleepTimerSeconds! <= 0) {
            _player.pause();
            _player.setVolume(1.0);
            _sleepTimerActive = false;
            _sleepTimerSeconds = null;
            timer.cancel();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _saveProgressTimer?.cancel();
    _sleepTimer?.cancel();
    _saveProgress(); // Final save before destruction
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? d) {
    if (d == null) return "0:00";
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return "$min:${sec.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (widget.edition.chapters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sync Prompt
            if (_syncPromptPercent != null)
              Container(
                color: Colors.blue.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Resume listening from your reading progress (~$_syncPromptPercent%)?",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final dur = _player.duration?.inSeconds ?? _currentChapter.durationSeconds;
                        if (dur > 0) {
                          final newPos = (dur * (_syncPromptPercent! / 100)).round();
                          _player.seek(Duration(seconds: newPos));
                          _player.play();
                        }
                        setState(() {
                          _syncPromptPercent = null;
                          _syncHandled = true;
                        });
                      },
                      child: const Text("Yes"),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _syncPromptPercent = null;
                          _syncHandled = true;
                        });
                      },
                      child: const Text("No"),
                    ),
                  ],
                ),
              ),
            // Info Row
            Row(
              children: [
                if (widget.edition.cover != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(widget.edition.cover!, width: 40, height: 40, fit: BoxFit.cover),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_currentChapter.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(widget.edition.title, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress Bar
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final pos = snapshot.data ?? Duration.zero;
                final dur = _player.duration ?? Duration(seconds: _currentChapter.durationSeconds);
                return Row(
                  children: [
                    Text(_formatDuration(pos), style: const TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: pos.inSeconds.toDouble().clamp(0, dur.inSeconds.toDouble()),
                        max: dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0,
                        onChanged: (v) {
                          _player.seek(Duration(seconds: v.toInt()));
                        },
                      ),
                    ),
                    Text(_formatDuration(dur), style: const TextStyle(fontSize: 12)),
                  ],
                );
              },
            ),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: _prevTrack,
                ),
                IconButton(
                  icon: const Icon(Icons.replay_10),
                  onPressed: () => _skip(-15),
                  tooltip: "-15s",
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  )
                else
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final playing = playerState?.playing ?? false;
                      return IconButton(
                        iconSize: 48,
                        icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                        onPressed: () {
                          if (playing) {
                            _player.pause();
                          } else {
                            _player.play();
                          }
                        },
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.forward_30),
                  onPressed: () => _skip(30),
                  tooltip: "+30s",
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: _currentIndex < widget.edition.chapters.length - 1 ? _nextTrack : null,
                ),
              ],
            ),
            // Advanced Controls
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<double>(
                  value: _playbackRate,
                  style: Theme.of(context).textTheme.bodySmall,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.speed, size: 16),
                  items: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0].map((rate) {
                    return DropdownMenuItem<double>(
                      value: rate,
                      child: Text("\${rate}x"),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) _setPlaybackRate(val);
                  },
                ),
                Row(
                  children: [
                    if (_sleepTimerActive && _sleepTimerSeconds != null && _sleepTimerSeconds! > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          _formatDuration(Duration(seconds: _sleepTimerSeconds!)),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ),
                    DropdownButton<int?>(
                      value: _sleepTimerSeconds,
                      style: Theme.of(context).textTheme.bodySmall,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.timer, size: 16),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text("No Timer")),
                        const DropdownMenuItem<int?>(value: 15 * 60, child: Text("15 min")),
                        const DropdownMenuItem<int?>(value: 30 * 60, child: Text("30 min")),
                        const DropdownMenuItem<int?>(value: 60 * 60, child: Text("60 min")),
                        const DropdownMenuItem<int?>(value: -1, child: Text("End of Chapter")),
                      ],
                      onChanged: _setSleepTimer,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
