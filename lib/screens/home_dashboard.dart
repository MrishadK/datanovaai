import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:datanovaai/providers/theme_provider.dart';
import 'package:datanovaai/providers/dataset_provider.dart';
import 'package:datanovaai/screens/dataset_workspace.dart';
import 'package:datanovaai/screens/settings_page.dart';

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  bool _isDragging = false;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'json'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        _processFile(result.files.single.path!);
      }
    } catch (e) {
      _showSnackbar('File picker error: $e', isError: true);
    }
  }

  Future<void> _processFile(String path) async {
    final notifier = ref.read(datasetProvider.notifier);
    
    // Check if backend is connected. If not, alert the user but try anyway
    final isConnected = ref.read(datasetProvider).isBackendConnected;
    if (!isConnected) {
      _showSnackbar('Offline Mode: Some AI recommendation features will be limited until backend is connected.', isWarning: true);
    }

    final success = await notifier.importFile(path);
    if (success && mounted) {
      _showSnackbar('Successfully loaded ${ref.read(datasetProvider).filename}');
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const DatasetWorkspace(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      _showSnackbar(ref.read(datasetProvider).errorMessage ?? 'Failed to load dataset.', isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = false, bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError
            ? AppColors.danger
            : isWarning
                ? AppColors.warning
                : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final datasetState = ref.watch(datasetProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar Nav
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              border: Border(
                right: BorderSide(
                  color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000),
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 35),
                // Brand Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.analytics_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'DATANOVA AI',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                
                // Sidebar Options
                _buildSidebarItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Import Center',
                  isActive: true,
                  onTap: () {},
                ),
                _buildSidebarItem(
                  icon: Icons.table_chart_rounded,
                  label: 'Dataset Workspace',
                  isActive: false,
                  enabled: datasetState.hasDataset,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const DatasetWorkspace()),
                    );
                  },
                ),
                _buildSidebarItem(
                  icon: Icons.settings_rounded,
                  label: 'System Settings',
                  isActive: false,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SettingsPage()),
                    );
                  },
                ),
                const Spacer(),
                
                // Connection Indicator Card
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x0EFFFFFF) : const Color(0x0E000000),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0x16FFFFFF) : const Color(0x16000000),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: datasetState.isBackendConnected ? AppColors.success : AppColors.danger,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              datasetState.isBackendConnected ? 'Backend Connected' : 'Offline Mode Active',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            Text(
                              'Port: 8000',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),

          // Main Dashboard Page
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Next-Gen Automated Preparation',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'DataNova AI Ingestion Hub',
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          // Theme Switch Button
                          IconButton(
                            icon: Icon(
                              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              size: 22,
                            ),
                            onPressed: () {
                              ref.read(themeProvider.notifier).toggleTheme();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 35),

                      // Quick Stats Row
                      Row(
                        children: [
                          _buildStatCard(
                            title: 'Status',
                            value: datasetState.isBackendConnected ? 'Active' : 'Offline',
                            color: datasetState.isBackendConnected ? AppColors.success : AppColors.warning,
                            icon: Icons.rss_feed_rounded,
                          ),
                          const SizedBox(width: 20),
                          _buildStatCard(
                            title: 'Supported Imports',
                            value: 'CSV, XLSX, JSON',
                            color: AppColors.primary,
                            icon: Icons.library_books_rounded,
                          ),
                          const SizedBox(width: 20),
                          _buildStatCard(
                            title: 'Active Session',
                            value: datasetState.hasDataset ? datasetState.filename : 'No File Loaded',
                            color: datasetState.hasDataset ? AppColors.secondary : AppColors.danger,
                            icon: Icons.insert_drive_file_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 35),

                      // Drag and Drop Zone
                      Expanded(
                        child: DropTarget(
                          onDragDone: (details) {
                            if (details.files.isNotEmpty) {
                              _processFile(details.files.first.path);
                            }
                          },
                          onDragEntered: (details) {
                            setState(() => _isDragging = true);
                          },
                          onDragExited: (details) {
                            setState(() => _isDragging = false);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _isDragging
                                  ? AppColors.primary.withOpacity(0.08)
                                  : isDark
                                      ? const Color(0xFF0F172A).withOpacity(0.4)
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _isDragging
                                    ? AppColors.primary
                                    : isDark
                                        ? const Color(0x2AFFFFFF)
                                        : const Color(0x2A000000),
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                              boxShadow: _isDragging
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.2),
                                        blurRadius: 30,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Upload Icon
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.cloud_upload_rounded,
                                      size: 55,
                                      color: _isDragging ? AppColors.primary : (isDark ? Colors.white60 : Colors.black54),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Drag & Drop Dataset File Here',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Acceptable formats: CSV, Excel (.xlsx, .xls), JSON files up to 500MB',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: isDark ? Colors.white38 : Colors.black45,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  ElevatedButton.icon(
                                    onPressed: _pickFile,
                                    icon: const Icon(Icons.search_rounded, size: 18),
                                    label: const Text('Browse Files'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Loading Overlay
                if (datasetState.isLoading)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            strokeWidth: 5,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Parsing dataset and calculating profile metrics...',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isActive,
    bool enabled = true,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isActive
        ? AppColors.primary
        : !enabled
            ? (isDark ? Colors.white24 : Colors.black26)
            : (isDark ? Colors.white60 : Colors.black54);

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: ListTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
        selected: isActive,
        selectedTileColor: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000),
        onTap: enabled ? onTap : null,
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
