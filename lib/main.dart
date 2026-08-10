import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:powersync/powersync.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

import 'config/app_config.dart';

import 'data/powersync/app_schema.dart';
import 'data/powersync/powersync_library_repository.dart';
import 'data/powersync/powersync_profile_repository.dart';
import 'data/powersync/powersync_sync_connector.dart';
import 'data/directus/directus_auth_repository.dart';
import 'domain/repositories/library_repository.dart';
import 'domain/repositories/profile_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'presentation/pages/app_shell.dart';
import 'application/services/audio_player_service.dart';
import 'presentation/widgets/global_audio_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize PowerSync DB
  final dir = await getApplicationSupportDirectory();
  final path = join(dir.path, 'powersync-sqlite.db');
  
  final db = PowerSyncDatabase(
    schema: appSchema,
    path: path,
  );
  await db.initialize();
  
  // Connect PowerSync to sync service (fetches JWT from Next.js API)
  final syncConnector = PowerSyncSyncConnector(db);
  syncConnector.connect(); // Start syncing in the background

  // Initialize Repositories
  final libraryRepository = PowerSyncLibraryRepository(db);
  final profileRepository = PowerSyncProfileRepository(db);
  final authRepository = DirectusAuthRepository(
    baseUrl: AppConfig.directusUrl,
    client: http.Client(),
    syncConnector: syncConnector,
  );

  runApp(MyApp(
    libraryRepository: libraryRepository,
    authRepository: authRepository,
    profileRepository: profileRepository,
  ));
}

class MyApp extends StatelessWidget {
  final ILibraryRepository libraryRepository;
  final IAuthRepository authRepository;
  final IProfileRepository profileRepository;

  const MyApp({
    super.key,
    required this.libraryRepository,
    required this.authRepository,
    required this.profileRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ILibraryRepository>.value(value: libraryRepository),
        Provider<IAuthRepository>.value(value: authRepository),
        Provider<IProfileRepository>.value(value: profileRepository),
        ChangeNotifierProvider<AudioPlayerService>(
          create: (_) => AudioPlayerService(libraryRepository),
        ),
      ],
      child: MaterialApp(
        title: 'Edumynt Library',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFD0BCFF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        builder: (context, child) {
          return Stack(
            children: [
              ?child,
              const GlobalAudioPlayer(),
            ],
          );
        },
        home: const AppShell(),
      ),
    );
  }
}
