import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/models/audio_edition.dart';
import '../../domain/models/audio_chapter.dart';
import '../../domain/models/audio_progress.dart';
import '../../domain/repositories/library_repository.dart';
import 'dart:async';

class AudioPlayerService extends ChangeNotifier {
  final ILibraryRepository _repository;
  
  AudioPlayerService(this._repository) {
    _player = AudioPlayer();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
         _nextTrack();
      }
      notifyListeners();
    });
    _player.positionStream.listen((_) => notifyListeners());
    _player.durationStream.listen((_) => notifyListeners());

    _saveProgressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_player.playing) {
        _saveProgress();
      }
    });
  }

  late final AudioPlayer _player;
  Timer? _saveProgressTimer;

  AudioEdition? _currentEdition;
  int _currentIndex = 0;
  bool _isLoading = false;

  AudioEdition? get currentEdition => _currentEdition;
  AudioChapter? get currentChapter => _currentEdition?.chapters.isNotEmpty == true && _currentIndex < _currentEdition!.chapters.length ? _currentEdition!.chapters[_currentIndex] : null;
  AudioPlayer get player => _player;
  bool get isLoading => _isLoading;
  int get currentIndex => _currentIndex;

  Future<void> playEdition(AudioEdition edition, int chapterIndex) async {
    _currentEdition = edition;
    _currentIndex = chapterIndex;
    notifyListeners();
    await _initCurrentChapter();
    _player.play();
  }
  
  Future<void> _initCurrentChapter() async {
    if (currentChapter == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final progress = await _repository.getAudioProgress(currentEdition!.bookId, currentChapter!.id);
      await _player.setUrl(currentChapter!.audioFileUrl);
      if (progress != null) {
        await _player.seek(Duration(seconds: progress.positionSeconds));
      }
    } catch (e) {
      debugPrint("Error initializing audio: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void play() => _player.play();
  void pause() => _player.pause();
  void seek(Duration position) => _player.seek(position);

  Future<void> _saveProgress() async {
    if (currentChapter == null || currentEdition == null) return;
    try {
      final position = _player.position.inSeconds;
      final duration = _player.duration?.inSeconds ?? currentChapter!.durationSeconds;
      final progress = AudioProgress(
        bookId: currentEdition!.bookId,
        audioChapterId: currentChapter!.id,
        positionSeconds: position,
        durationSeconds: duration,
        status: 'started',
        lastListenedAt: DateTime.now(),
      );
      await _repository.saveAudioProgress(progress);
    } catch (e) {
      debugPrint("Error saving progress: $e");
    }
  }

  Future<void> _nextTrack() async {
    if (currentEdition == null) return;
    await _saveProgress();
    if (_currentIndex < currentEdition!.chapters.length - 1) {
      _currentIndex++;
      await _initCurrentChapter();
      _player.play();
    }
  }
  
  Future<void> prevTrack() async {
    if (currentEdition == null) return;
    await _saveProgress();
    if (_player.position.inSeconds > 3) {
      _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      await _initCurrentChapter();
      _player.play();
    }
  }

  Future<void> nextTrack() => _nextTrack();

  void skip(int seconds) {
    final current = _player.position;
    final newPos = current + Duration(seconds: seconds);
    _player.seek(newPos);
  }

  void stopAndDismiss() {
    _player.stop();
    _saveProgress();
    _currentEdition = null;
    notifyListeners();
  }
  
  void setPlaybackRate(double rate) {
    _player.setSpeed(rate);
  }

  @override
  void dispose() {
    _saveProgressTimer?.cancel();
    _saveProgress();
    _player.dispose();
    super.dispose();
  }
}
