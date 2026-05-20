import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendLauncher {
  static Process? _process;
  static bool _isStarting = false;

  static Process? get process => _process;

  /// Pings the server to check if it's already running
  static Future<bool> isServerRunning() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/')).timeout(
        const Duration(milliseconds: 1000),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['status'] == 'online';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Automatically launches the Python FastAPI server in the background
  static Future<void> start() async {
    if (_process != null || _isStarting) {
      print('Backend server launcher is already active.');
      return;
    }

    _isStarting = true;

    try {
      // 1. Check if the server is already running (e.g., from manual startup)
      final running = await isServerRunning();
      if (running) {
        print('Backend server is already running on port 8000. Skipping automatic startup.');
        _isStarting = false;
        return;
      }

      print('Starting local Python FastAPI backend server...');

      // 2. Identify the backend project directory path
      // When running in debug mode (flutter run), Directory.current is the project root folder.
      String projectRoot = Directory.current.path;
      String backendDir = '$projectRoot\\backend';

      // Verify that the backend directory exists
      if (!Directory(backendDir).existsSync()) {
        // Try fallback relative path (e.g. if we are in built assets)
        backendDir = '.\\backend';
        if (!Directory(backendDir).existsSync()) {
          print('Error: Backend directory not found at: $backendDir');
          _isStarting = false;
          return;
        }
      }

      print('Backend working directory: $backendDir');

      // 3. Spawn Python process in the background
      // Use "python" with "-u" (unbuffered output) to ensure fast log streaming
      _process = await Process.start(
        'python',
        ['-u', 'main.py'],
        workingDirectory: backendDir,
        runInShell: true,
      );

      print('Python FastAPI backend process spawned successfully (PID: ${_process!.pid}).');

      // 4. Stream stdout/stderr for diagnostics
      _process!.stdout.transform(utf8.decoder).listen((data) {
        print('[Backend stdout]: ${data.trim()}');
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        print('[Backend stderr]: ${data.trim()}');
      });

      // Handle process exit
      _process!.exitCode.then((code) {
        print('Backend process exited with code: $code');
        _process = null;
        _isStarting = false;
      });

    } catch (e) {
      print('Failed to auto-start Python backend process: $e');
      print('Please ensure Python 3 is installed and added to your system PATH.');
      _process = null;
      _isStarting = false;
    }
  }

  /// Terminates the local Python backend server
  static Future<void> stop() async {
    if (_process != null) {
      print('Stopping Python FastAPI backend process (PID: ${_process!.pid})...');
      final killed = _process!.kill();
      print('Backend process termination signal sent: $killed');
      _process = null;
    }
    _isStarting = false;
  }
}
