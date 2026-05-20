import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:datanovaai/providers/theme_provider.dart';
import 'package:datanovaai/providers/dataset_provider.dart';
import 'package:datanovaai/screens/home_dashboard.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _showRetry = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
    
    _checkServerConnection();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkServerConnection() async {
    setState(() {
      _showRetry = false;
    });
    
    // Allow animation to play for at least 1.8 seconds for smooth transitions
    await Future.delayed(const Duration(milliseconds: 1800));
    
    // Check local API connection
    await ref.read(datasetProvider.notifier).checkConnection();
    final isConnected = ref.read(datasetProvider).isBackendConnected;

    if (isConnected) {
      _navigateToHome();
    } else {
      setState(() {
        _showRetry = true;
      });
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeDashboard(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.3,
            colors: isDark
                ? [
                    const Color(0xFF1E1E38), // Glowing core
                    const Color(0xFF070712), // Deep outer space
                  ]
                : [
                    const Color(0xFFE0E7FF), // Soft violet core
                    const Color(0xFFF3F4F6), // Warm silk gray
                  ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing glass-morphic logo shell
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x12FFFFFF) : const Color(0x0A000000),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark ? const Color(0x1FFFFFFF) : const Color(0x1F000000),
                      width: 1.5,
                    ),
                    boxShadow: isDark
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.15),
                              blurRadius: 40,
                              spreadRadius: 5,
                            )
                          ]
                        : [],
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ).createShader(bounds),
                    child: Icon(
                      Icons.analytics_rounded,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Typography
                Text(
                  'DATANOVA AI',
                  style: GoogleFonts.outfit(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Next-Gen Automated Data Prep Platform',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 60),

                // Connection Check or Loader
                if (!_showRetry) ...[
                  SpinKitDoubleBounce(
                    color: AppColors.primary,
                    size: 45.0,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Initializing local data services...',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary.withOpacity(0.7) : AppColors.lightTextSecondary.withOpacity(0.7),
                    ),
                  ),
                ] else ...[
                  // Glassmorphic retry panel
                  Container(
                    width: 420,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x1F1E293B) : const Color(0x1F9CA3AF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0x2AFFFFFF) : const Color(0x2A000000),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: AppColors.warning,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Local Backend Offline',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'DataNova AI requires a local data science server. Make sure your Python server is running on localhost:8000.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _checkServerConnection,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry Connection'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: _navigateToHome,
                              icon: const Icon(Icons.cloud_off_rounded, size: 18),
                              label: const Text('Proceed Offline'),
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? Colors.white70 : Colors.black87,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
