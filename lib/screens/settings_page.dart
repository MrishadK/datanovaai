import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:datanovaai/providers/theme_provider.dart';
import 'package:datanovaai/providers/dataset_provider.dart';
import 'package:datanovaai/services/api_client.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _geminiController = TextEditingController();
  final TextEditingController _openaiController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  bool _obscureGemini = true;
  bool _obscureOpenAI = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _openaiController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geminiController.text = prefs.getString('gemini_key') ?? '';
      _openaiController.text = prefs.getString('openai_key') ?? '';
      _portController.text = prefs.getString('backend_port') ?? '8000';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save locally
    await prefs.setString('gemini_key', _geminiController.text.trim());
    await prefs.setString('openai_key', _openaiController.text.trim());
    await prefs.setString('backend_port', _portController.text.trim());

    // Update API Client endpoint port
    final client = ref.read(apiClientProvider);
    final cleanPort = _portController.text.trim();
    if (cleanPort.isNotEmpty) {
      client.baseUrl = 'http://127.0.0.1:$cleanPort/api';
    }

    // Ping backend connection to verify
    await ref.read(datasetProvider.notifier).checkConnection();

    // Proactively reload AI suggestions
    if (ref.read(datasetProvider).hasDataset) {
      await ref.read(datasetProvider.notifier).loadRecommendations();
    }

    _showSnackbar('Configurations updated successfully.');
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeNotifier = ref.read(themeProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'System Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DataNova Core Adjustments',
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Customize backend ports, visual interface themes, and configure LLM API key credentials to unlock cognitive cleaning co-pilots.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 30),

                // SECTION 1: VISUAL THEME
                _buildSectionHeader('Visual Interface Customization'),
                Card(
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.4) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Visual Theme Mode',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Switch(
                          value: isDark,
                          onChanged: (val) {
                            themeNotifier.toggleTheme();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // SECTION 2: API KEY CREDENTIALS
                _buildSectionHeader('AI API Keys Management'),
                Card(
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.4) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gemini Key Input
                        _buildLabel('GOOGLE STUDIO GEMINI API KEY'),
                        TextField(
                          controller: _geminiController,
                          obscureText: _obscureGemini,
                          style: GoogleFonts.inter(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'AIzaSy...',
                            hintStyle: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureGemini ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                              onPressed: () => setState(() => _obscureGemini = !_obscureGemini),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // OpenAI Key Input
                        _buildLabel('OPENAI DEVELOPER API KEY'),
                        TextField(
                          controller: _openaiController,
                          obscureText: _obscureOpenAI,
                          style: GoogleFonts.inter(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'sk-proj-...',
                            hintStyle: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureOpenAI ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                              onPressed: () => setState(() => _obscureOpenAI = !_obscureOpenAI),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            const Icon(Icons.shield_rounded, color: AppColors.success, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'API keys are stored completely offline on your local machine and only transmitted directly to official OpenAI/Google endpoints.',
                                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, height: 1.4),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // SECTION 3: BACKEND PORT CONFIG
                _buildSectionHeader('Python FastAPI Server Settings'),
                Card(
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.4) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('LOCAL SERVER CONNECTION PORT'),
                        TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: '8000',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 35),

                // SAVE BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save Configurations',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
      ),
    );
  }
}
