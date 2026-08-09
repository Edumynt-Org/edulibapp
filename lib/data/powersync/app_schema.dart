import 'package:powersync/powersync.dart';

const appSchema = Schema([
  Table('books', [
    Column.text('title'),
    Column.text('slug'),
    Column.text('description'),
    Column.text('cover'),
    Column.text('original_title'),
    Column.text('original_language'),
    Column.integer('first_published_year'),
  ], indexes: [
    Index('title', [IndexedColumn('title')]),
    Index('slug', [IndexedColumn('slug')]),
  ]),
  Table('editions', [
    Column.text('book'),
    Column.text('format'),
    Column.text('isbn'),
    Column.integer('pages'),
    Column.text('title'),
    Column.text('slug'),
    Column.text('language'),
    Column.text('cover'),
  ], indexes: [
    Index('book', [IndexedColumn('book')]),
  ]),
  Table('authors', [
    Column.text('name'),
    Column.text('bio'),
  ]),
  Table('genres', [
    Column.text('name'),
    Column.text('slug'),
  ]),
  Table('categories', [
    Column.text('name'),
    Column.text('slug'),
  ]),
  Table('series', [
    Column.text('name'),
    Column.text('description'),
  ]),
  // Junction tables
  Table('book_authors', [
    Column.text('book'),
    Column.text('author'),
  ], indexes: [
    Index('book', [IndexedColumn('book')]),
    Index('author', [IndexedColumn('author')]),
  ]),
  Table('book_genres', [
    Column.text('book'),
    Column.text('genre'),
  ], indexes: [
    Index('book', [IndexedColumn('book')]),
    Index('genre', [IndexedColumn('genre')]),
  ]),
  Table('book_categories', [
    Column.text('book'),
    Column.text('category'),
  ], indexes: [
    Index('book', [IndexedColumn('book')]),
    Index('category', [IndexedColumn('category')]),
  ]),
  Table('series_books', [
    Column.text('series'),
    Column.text('book'),
    Column.integer('order'),
  ], indexes: [
    Index('series', [IndexedColumn('series')]),
    Index('book', [IndexedColumn('book')]),
  ]),
  Table('parts', [
    Column.text('edition'),
    Column.text('title'),
    Column.text('description'),
    Column.integer('sort_order'),
  ]),
  Table('chapters', [
    Column.text('title'),
    Column.text('slug'),
    Column.text('chapter_type'),
    Column.integer('counts_toward_completion'),
    Column.text('content'),
    Column.text('summary'),
  ]),
  Table('editions_chapters', [
    Column.text('editions_id'),
    Column.text('chapters_id'),
    Column.integer('sort_order'),
  ]),
  Table('parts_chapters', [
    Column.text('parts_id'),
    Column.text('chapters_id'),
    Column.integer('sort_order'),
  ]),
  Table('audio_editions', [
    Column.text('book'),
    Column.text('title'),
    Column.text('slug'),
    Column.text('language'),
    Column.text('cover'),
    Column.text('narrator_name'),
    Column.integer('is_complete'),
    Column.text('linked_text_edition'),
    Column.text('rights_status'),
  ]),
  Table('audio_parts', [
    Column.text('audio_edition'),
    Column.text('title'),
    Column.text('description'),
    Column.integer('sort_order'),
  ]),
  Table('audio_chapters', [
    Column.text('title'),
    Column.text('slug'),
    Column.text('audio_file'),
    Column.integer('duration_seconds'),
    Column.text('linked_text_chapter'),
    Column.text('rights_status'),
  ]),
  Table('audio_editions_audio_chapters', [
    Column.text('audio_editions_id'),
    Column.text('audio_chapters_id'),
    Column.integer('sort_order'),
  ]),
  Table('audio_parts_audio_chapters', [
    Column.text('audio_parts_id'),
    Column.text('audio_chapters_id'),
    Column.integer('sort_order'),
  ]),
  Table('book_lists', [
    Column.text('title'),
    Column.text('slug'),
    Column.text('list_type'),
    Column.integer('sort_order'),
    Column.text('cover'),
  ]),
  Table('book_list_items', [
    Column.text('list'),
    Column.text('book'),
    Column.integer('sort_order'),
    Column.text('note'),
  ], indexes: [
    Index('list', [IndexedColumn('list')]),
    Index('book', [IndexedColumn('book')]),
  ]),
  Table('chapter_progress', [
    Column.text('profile'),
    Column.text('book'),
    Column.text('edition'),
    Column.text('chapter'),
    Column.text('status'),
    Column.integer('progress_percent'),
    Column.integer('last_position'),
    Column.text('completed_at'),
    Column.text('last_read_at'),
  ], indexes: [
    Index('profile_chapter', [IndexedColumn('profile'), IndexedColumn('chapter')]),
  ]),
  Table('reading_preferences', [
    Column.text('profile'),
    Column.text('font_family'),
    Column.integer('font_size_px'),
    Column.text('line_spacing'),
    Column.text('theme'),
    Column.text('margins'),
  ], indexes: [
    Index('profile', [IndexedColumn('profile')]),
  ]),
  Table('annotations', [
    Column.text('profile'),
    Column.text('chapter_id'),
    Column.text('annotation_type'), // 'highlight', 'bookmark', 'note'
    Column.text('color'),
    Column.text('selected_text'),
    Column.text('note_text'),
    Column.text('start_position'), // CSS selector / Markdown node ref
    Column.text('end_position'),
    Column.text('created_at'),
  ], indexes: [
    Index('profile_chapter', [IndexedColumn('profile'), IndexedColumn('chapter_id')]),
  ]),
  Table('dictionary_cache', [
    Column.text('word'),
    Column.text('definition_json'),
    Column.text('timestamp'),
  ], indexes: [
    Index('word', [IndexedColumn('word')]),
  ]),
  Table('audio_progress', [
    Column.text('profile'),
    Column.text('book'),
    Column.text('audio_chapter'),
    Column.integer('position_seconds'),
    Column.integer('duration_seconds'),
    Column.text('status'),
    Column.text('completed_at'),
    Column.text('last_listened_at'),
  ], indexes: [
    Index('profile_chapter', [IndexedColumn('profile'), IndexedColumn('audio_chapter')]),
  ]),
]);
