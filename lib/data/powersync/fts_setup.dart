import 'package:powersync/powersync.dart';
import 'package:edulibapp/data/powersync/app_schema.dart';

Future<void> configureFts(PowerSyncDatabase db) async {
  String getInternalName(String tableName) {
    return appSchema.tables.firstWhere(
      (t) => t.name == tableName, 
      orElse: () => Table(tableName, []),
    ).internalName;
  }


  // Create FTS5 virtual table
  await db.execute('''
    CREATE VIRTUAL TABLE IF NOT EXISTS fts_books
    USING fts5(id UNINDEXED, title, description, search_terms, tokenize='unicode61');
  ''');

  // Populate initially if empty
  await db.execute('''
    INSERT INTO fts_books(id, title, description, search_terms)
    SELECT 
      b.id, 
      b.title, 
      b.description,
      (
        COALESCE((SELECT group_concat(a.name, ' ') FROM authors a JOIN book_authors ba ON a.id = ba.author_id WHERE ba.book_id = b.id), '') || ' ' ||
        COALESCE((SELECT group_concat(g.name, ' ') FROM genres g JOIN book_genres bg ON g.id = bg.genre_id WHERE bg.book_id = b.id), '') || ' ' ||
        COALESCE((SELECT group_concat(c.name, ' ') FROM categories c JOIN book_categories bc ON c.id = bc.category_id WHERE bc.book_id = b.id), '') || ' ' ||
        COALESCE((SELECT group_concat(s.name, ' ') FROM series s JOIN series_books sb ON s.id = sb.series_id WHERE sb.book_id = b.id), '')
      ) as search_terms
    FROM books b
    WHERE b.id NOT IN (SELECT id FROM fts_books);
  ''');

  // Helper macro to update a book's search terms
  final updateSearchTermsSql = '''
      UPDATE fts_books
      SET search_terms = (
        COALESCE((SELECT group_concat(a.name, ' ') FROM authors a JOIN book_authors ba ON a.id = ba.author_id WHERE ba.book_id = fts_books.id), '') || ' ' ||
        COALESCE((SELECT group_concat(g.name, ' ') FROM genres g JOIN book_genres bg ON g.id = bg.genre_id WHERE bg.book_id = fts_books.id), '') || ' ' ||
        COALESCE((SELECT group_concat(c.name, ' ') FROM categories c JOIN book_categories bc ON c.id = bc.category_id WHERE bc.book_id = fts_books.id), '') || ' ' ||
        COALESCE((SELECT group_concat(s.name, ' ') FROM series s JOIN series_books sb ON s.id = sb.series_id WHERE sb.book_id = fts_books.id), '')
      )
  ''';

  // Trigger for books insert
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_insert_trigger_books AFTER INSERT ON ${getInternalName('books')}
    BEGIN
      INSERT INTO fts_books(id, title, description, search_terms)
      VALUES (
        NEW.id,
        json_extract(NEW.data, '\$.title'),
        json_extract(NEW.data, '\$.description'),
        ''
      );
      $updateSearchTermsSql WHERE id = NEW.id;
    END;
  ''');

  // Trigger for books update
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_update_trigger_books AFTER UPDATE ON ${getInternalName('books')}
    BEGIN
      UPDATE fts_books
      SET title = json_extract(NEW.data, '\$.title'),
          description = json_extract(NEW.data, '\$.description')
      WHERE id = NEW.id;
    END;
  ''');

  // Trigger for books delete
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_delete_trigger_books AFTER DELETE ON ${getInternalName('books')}
    BEGIN
      DELETE FROM fts_books WHERE id = OLD.id;
    END;
  ''');

  // book_authors triggers
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_insert_trigger_book_authors AFTER INSERT ON ${getInternalName('book_authors')}
    BEGIN
      $updateSearchTermsSql WHERE id = json_extract(NEW.data, '\$.book_id');
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_update_trigger_book_authors AFTER UPDATE ON ${getInternalName('book_authors')}
    BEGIN
      $updateSearchTermsSql WHERE id = json_extract(NEW.data, '\$.book_id');
      $updateSearchTermsSql WHERE id = json_extract(OLD.data, '\$.book_id');
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_delete_trigger_book_authors AFTER DELETE ON ${getInternalName('book_authors')}
    BEGIN
      $updateSearchTermsSql WHERE id = json_extract(OLD.data, '\$.book_id');
    END;
  ''');

  // authors triggers
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_insert_trigger_authors AFTER INSERT ON ${getInternalName('authors')}
    BEGIN
      $updateSearchTermsSql WHERE id IN (SELECT book_id FROM book_authors WHERE author_id = NEW.id);
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_update_trigger_authors AFTER UPDATE ON ${getInternalName('authors')}
    BEGIN
      $updateSearchTermsSql WHERE id IN (SELECT book_id FROM book_authors WHERE author_id = NEW.id);
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_delete_trigger_authors AFTER DELETE ON ${getInternalName('authors')}
    BEGIN
      $updateSearchTermsSql WHERE id IN (SELECT book_id FROM book_authors WHERE author_id = OLD.id);
    END;
  ''');

  // book_genres triggers
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_insert_trigger_book_genres AFTER INSERT ON ${getInternalName('book_genres')}
    BEGIN
      $updateSearchTermsSql WHERE id = json_extract(NEW.data, '\$.book_id');
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_update_trigger_book_genres AFTER UPDATE ON ${getInternalName('book_genres')}
    BEGIN
      $updateSearchTermsSql WHERE id = json_extract(NEW.data, '\$.book_id');
      $updateSearchTermsSql WHERE id = json_extract(OLD.data, '\$.book_id');
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_delete_trigger_book_genres AFTER DELETE ON ${getInternalName('book_genres')}
    BEGIN
      $updateSearchTermsSql WHERE id = json_extract(OLD.data, '\$.book_id');
    END;
  ''');

  // genres triggers
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_insert_trigger_genres AFTER INSERT ON ${getInternalName('genres')}
    BEGIN
      $updateSearchTermsSql WHERE id IN (SELECT book_id FROM book_genres WHERE genre_id = NEW.id);
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_update_trigger_genres AFTER UPDATE ON ${getInternalName('genres')}
    BEGIN
      $updateSearchTermsSql WHERE id IN (SELECT book_id FROM book_genres WHERE genre_id = NEW.id);
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_delete_trigger_genres AFTER DELETE ON ${getInternalName('genres')}
    BEGIN
      $updateSearchTermsSql WHERE id IN (SELECT book_id FROM book_genres WHERE genre_id = OLD.id);
    END;
  ''');

  // book_categories triggers
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_insert_trigger_book_categories AFTER INSERT ON ${getInternalName('book_categories')}
    BEGIN
      $updateSearchTermsSql WHERE id = json_extract(NEW.data, '\$.book_id');
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_update_trigger_book_categories AFTER UPDATE ON ${getInternalName('book_categories')}
    BEGIN
      $updateSearchTermsSql WHERE id = json_extract(NEW.data, '\$.book_id');
      $updateSearchTermsSql WHERE id = json_extract(OLD.data, '\$.book_id');
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_delete_trigger_book_categories AFTER DELETE ON ${getInternalName('book_categories')}
    BEGIN
      $updateSearchTermsSql WHERE id = json_extract(OLD.data, '\$.book_id');
    END;
  ''');

  // categories triggers
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_insert_trigger_categories AFTER INSERT ON ${getInternalName('categories')}
    BEGIN
      $updateSearchTermsSql WHERE id IN (SELECT book_id FROM book_categories WHERE category_id = NEW.id);
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_update_trigger_categories AFTER UPDATE ON ${getInternalName('categories')}
    BEGIN
      $updateSearchTermsSql WHERE id IN (SELECT book_id FROM book_categories WHERE category_id = NEW.id);
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_delete_trigger_categories AFTER DELETE ON ${getInternalName('categories')}
    BEGIN
      $updateSearchTermsSql WHERE id IN (SELECT book_id FROM book_categories WHERE category_id = OLD.id);
    END;
  ''');

  // series_books triggers
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_insert_trigger_series_books AFTER INSERT ON ${getInternalName('series_books')}
    BEGIN
      $updateSearchTermsSql WHERE id = json_extract(NEW.data, '\$.book_id');
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_update_trigger_series_books AFTER UPDATE ON ${getInternalName('series_books')}
    BEGIN
      $updateSearchTermsSql WHERE id = json_extract(NEW.data, '\$.book_id');
      $updateSearchTermsSql WHERE id = json_extract(OLD.data, '\$.book_id');
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_delete_trigger_series_books AFTER DELETE ON ${getInternalName('series_books')}
    BEGIN
      $updateSearchTermsSql WHERE id = json_extract(OLD.data, '\$.book_id');
    END;
  ''');

  // series triggers
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_insert_trigger_series AFTER INSERT ON ${getInternalName('series')}
    BEGIN
      $updateSearchTermsSql WHERE id IN (SELECT book_id FROM series_books WHERE series_id = NEW.id);
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_update_trigger_series AFTER UPDATE ON ${getInternalName('series')}
    BEGIN
      $updateSearchTermsSql WHERE id IN (SELECT book_id FROM series_books WHERE series_id = NEW.id);
    END;
  ''');
  await db.execute('''
    CREATE TRIGGER IF NOT EXISTS fts_delete_trigger_series AFTER DELETE ON ${getInternalName('series')}
    BEGIN
      $updateSearchTermsSql WHERE id IN (SELECT book_id FROM series_books WHERE series_id = OLD.id);
    END;
  ''');
}
