import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:datanovaai/providers/theme_provider.dart';
import 'package:datanovaai/screens/splash_screen.dart';
import 'package:datanovaai/services/backend_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize window manager for native desktop window controls
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 820),
    minimumSize: Size(1024, 768),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    title: 'DataNova AI — Next-Generation Automated Data Preprocessing Platform',
    titleBarStyle: TitleBarStyle.normal,
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Auto-start Python FastAPI backend service in the background
  BackendLauncher.start();

  runApp(
    const ProviderScope(
      child: MainApp(),
    ),
  );
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initPreventClose();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initPreventClose() async {
    // Prevent the default window close behavior so we can clean up the python backend first
    await windowManager.setPreventClose(true);
  }

  @override
  void onWindowClose() async {
    // 1. Gracefully stop the backend server process
    await BackendLauncher.stop();
    // 2. Destroy the window to exit the application
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    
    return MaterialApp(
      title: 'DataNova AI',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

