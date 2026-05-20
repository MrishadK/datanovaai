import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:datanovaai/providers/theme_provider.dart';
import 'package:datanovaai/providers/dataset_provider.dart';
import 'package:datanovaai/providers/chat_provider.dart';
import 'package:datanovaai/screens/visualization_page.dart';
import 'package:datanovaai/screens/model_training_page.dart';
import 'package:datanovaai/services/api_client.dart';

class DatasetWorkspace extends ConsumerStatefulWidget {
  const DatasetWorkspace({super.key});

  @override
  ConsumerState<DatasetWorkspace> createState() => _DatasetWorkspaceState();
}

class _DatasetWorkspaceState extends ConsumerState<DatasetWorkspace> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isChatOpen = true;
  String _selectedCleanCategory = 'missing'; // missing, outliers, encoding, engineering

  // Imputation Form State
  String? _imputeCol;
  String _imputeMethod = 'mean';

  // Outliers Form State
  String? _outlierCol;
  String _outlierMethod = 'iqr';
  String _outlierAction = 'drop';
  double _outlierThreshold = 3.0;

  // Encoding Form State
  final List<String> _encodeCols = [];
  String _encodeMethod = 'onehot';

  // Engineering Form State
  String? _engCol;
  String _engMethod = 'datetime'; // datetime, tfidf
  int _maxFeatures = 50;

  // Chat Input Controller
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final datasetState = ref.watch(datasetProvider);
    final chatState = ref.watch(chatProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!datasetState.hasDataset) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workspace')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.table_rows_rounded, size: 70, color: Colors.grey),
              const SizedBox(height: 16),
              Text('No dataset loaded yet.', style: GoogleFonts.outfit(fontSize: 18)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Return to Dashboard'),
              )
            ],
          ),
        ),
      );
    }

    // Default select dropdown columns if null
    final numericCols = datasetState.columns
        .where((c) => c['type'] == 'numerical')
        .map((c) => c['name'] as String)
        .toList();
    final categoricalCols = datasetState.columns
        .where((c) => c['type'] == 'categorical')
        .map((c) => c['name'] as String)
        .toList();
    final datetimeCols = datasetState.columns
        .where((c) => c['type'] == 'datetime')
        .map((c) => c['name'] as String)
        .toList();
    final textCols = datasetState.columns
        .where((c) => c['type'] == 'text')
        .map((c) => c['name'] as String)
        .toList();

    final allCols = datasetState.columns.map((c) => c['name'] as String).toList();

    _imputeCol ??= allCols.isNotEmpty ? allCols.first : null;
    _outlierCol ??= numericCols.isNotEmpty ? numericCols.first : null;
    _engCol ??= allCols.isNotEmpty ? allCols.first : null;

    return Scaffold(
      body: Column(
        children: [
          // Top Control Toolbar
          _buildTopToolbar(datasetState, isDark),
          
          Expanded(
            child: Row(
              children: [
                // Left Panel: Cleaning Panel Options
                _buildLeftCleaningPanel(datasetState, allCols, numericCols, categoricalCols, datetimeCols, textCols, isDark),
                
                // Center Panel: Paginated Data preview or summary overview
                _buildCenterPreviewPanel(datasetState, isDark),
                
                // Right Panel: AI Chat assistant panel
                if (_isChatOpen) _buildRightChatPanel(chatState, isDark),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- UI Layout Blocks ---

  Widget _buildTopToolbar(DatasetState state, bool isDark) {
    return Container(
      height: 65,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
        border: Border(
          bottom: BorderSide(color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000)),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          
          // Dataset Name Tag
          Icon(Icons.insert_drive_file_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            state.filename,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 12),
          
          // Row/Col badges
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${state.rowsCount} Rows x ${state.columnsCount} Columns',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const Spacer(),

          // History Operations
          IconButton(
            icon: const Icon(Icons.undo_rounded, size: 18),
            tooltip: 'Undo',
            onPressed: state.history.length > 1 ? () => ref.read(datasetProvider.notifier).undo() : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded, size: 18),
            tooltip: 'Redo',
            onPressed: () => ref.read(datasetProvider.notifier).redo(), // notifier handles endpoint boundaries
          ),
          IconButton(
            icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
            tooltip: 'Reset Dataset',
            onPressed: () => ref.read(datasetProvider.notifier).reset(),
          ),
          const SizedBox(width: 15),
          const VerticalDivider(width: 1, indent: 20, endIndent: 20),
          const SizedBox(width: 15),

          // Primary Navigation Triggers
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const VisualizationPage()),
              );
            },
            icon: const Icon(Icons.bar_chart_rounded, size: 16),
            label: const Text('Visualizations'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ModelTrainingPage()),
              );
            },
            icon: const Icon(Icons.model_training_rounded, size: 16),
            label: const Text('AutoML Training'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 10),
          
          // Chat Toggle
          IconButton(
            icon: Icon(_isChatOpen ? Icons.speaker_notes_off_rounded : Icons.speaker_notes_rounded, size: 20),
            tooltip: 'Toggle AI Assistant',
            onPressed: () => setState(() => _isChatOpen = !_isChatOpen),
          )
        ],
      ),
    );
  }

  Widget _buildLeftCleaningPanel(
    DatasetState state,
    List<String> allCols,
    List<String> numericCols,
    List<String> categoricalCols,
    List<String> datetimeCols,
    List<String> textCols,
    bool isDark,
  ) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        border: Border(right: BorderSide(color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cleaning Panels Menu
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cleaning Tools',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                // Quick dropdown switch category
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCleanCategory,
                    items: const [
                      DropdownMenuItem(value: 'missing', child: Text('Missing Values')),
                      DropdownMenuItem(value: 'outliers', child: Text('Outlier Handling')),
                      DropdownMenuItem(value: 'encoding', child: Text('Encodings')),
                      DropdownMenuItem(value: 'engineering', child: Text('Feature Eng.')),
                      DropdownMenuItem(value: 'recommendations', child: Text('AI Recommendations')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCleanCategory = val);
                    },
                    style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _buildCleaningForm(state, allCols, numericCols, categoricalCols, datetimeCols, textCols, isDark),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCleaningForm(
    DatasetState state,
    List<String> allCols,
    List<String> numericCols,
    List<String> categoricalCols,
    List<String> datetimeCols,
    List<String> textCols,
    bool isDark,
  ) {
    if (_selectedCleanCategory == 'missing') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormTitle('Impute Missing Values', Icons.opacity_rounded),
          const SizedBox(height: 15),
          _buildLabel('Select Column to Impute'),
          _buildDropdown(
            value: _imputeCol,
            items: allCols,
            onChanged: (val) => setState(() => _imputeCol = val),
          ),
          const SizedBox(height: 15),
          _buildLabel('Imputation Strategy'),
          _buildDropdown(
            value: _imputeMethod,
            items: const ['mean', 'median', 'mode', 'ffill', 'bfill'],
            onChanged: (val) => setState(() => _imputeMethod = val!),
          ),
          const SizedBox(height: 25),
          _buildApplyButton(
            onPressed: () {
              if (_imputeCol != null) {
                ref.read(datasetProvider.notifier).cleanMissingValues(_imputeCol!, _imputeMethod);
                _showSnackbar('Imputing missing values in $_imputeCol');
              }
            },
          ),
          const SizedBox(height: 20),
          _buildWarningCard('Mean/Median can only be applied to numerical fields. Mode will apply Mode series or fallback to text labels.'),
        ],
      );
    } else if (_selectedCleanCategory == 'outliers') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormTitle('Outlier Detection & Removal', Icons.analytics_outlined),
          const SizedBox(height: 15),
          _buildLabel('Numerical Column'),
          _buildDropdown(
            value: _outlierCol,
            items: numericCols,
            onChanged: (val) => setState(() => _outlierCol = val),
          ),
          const SizedBox(height: 15),
          _buildLabel('Detection Method'),
          _buildDropdown(
            value: _outlierMethod,
            items: const ['iqr', 'zscore', 'isoforest'],
            onChanged: (val) => setState(() => _outlierMethod = val!),
          ),
          const SizedBox(height: 15),
          _buildLabel('Transformation Action'),
          _buildDropdown(
            value: _outlierAction,
            items: const ['detect', 'drop', 'cap'],
            onChanged: (val) => setState(() => _outlierAction = val!),
          ),
          if (_outlierMethod == 'zscore') ...[
            const SizedBox(height: 15),
            _buildLabel('Z-Score Threshold (${_outlierThreshold.toStringAsFixed(1)})'),
            Slider(
              value: _outlierThreshold,
              min: 1.5,
              max: 5.0,
              divisions: 7,
              label: _outlierThreshold.toStringAsFixed(1),
              onChanged: (val) => setState(() => _outlierThreshold = val),
            ),
          ],
          const SizedBox(height: 25),
          _buildApplyButton(
            onPressed: () {
              if (_outlierCol != null) {
                if (_outlierAction == 'detect') {
                  // Direct trigger to check count without saving stack
                  ref.read(apiClientProvider).handleOutliers(_outlierCol!, _outlierMethod, 'detect', threshold: _outlierThreshold).then((res) {
                    final data = res['data'];
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Outliers Detection Results'),
                        content: Text('Detected ${data['outlier_count']} outliers (${data['outlier_percentage']}%) in column "$_outlierCol".'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Dismiss'))
                        ],
                      ),
                    );
                  });
                } else {
                  ref.read(datasetProvider.notifier).handleOutliers(
                    _outlierCol!,
                    _outlierMethod,
                    _outlierAction,
                    threshold: _outlierThreshold,
                  );
                  _showSnackbar('Applying outlier transformation on $_outlierCol');
                }
              }
            },
          ),
        ],
      );
    } else if (_selectedCleanCategory == 'encoding') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormTitle('Feature Encodings & Scaling', Icons.code_rounded),
          const SizedBox(height: 15),
          _buildLabel('Encoding / Scaling strategy'),
          _buildDropdown(
            value: _encodeMethod,
            items: const ['onehot', 'label', 'normalize', 'standardize'],
            onChanged: (val) => setState(() => _encodeMethod = val!),
          ),
          const SizedBox(height: 15),
          _buildLabel('Select Columns (Select all that apply)'),
          const SizedBox(height: 5),
          
          // Column checklists
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: ListView.builder(
              itemCount: (_encodeMethod == 'normalize' || _encodeMethod == 'standardize' ? numericCols : categoricalCols).length,
              itemBuilder: (context, i) {
                final list = (_encodeMethod == 'normalize' || _encodeMethod == 'standardize' ? numericCols : categoricalCols);
                if (list.isEmpty) return const SizedBox();
                final col = list[i];
                return CheckboxListTile(
                  title: Text(col, style: GoogleFonts.inter(fontSize: 12)),
                  value: _encodeCols.contains(col),
                  dense: true,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _encodeCols.add(col);
                      } else {
                        _encodeCols.remove(col);
                      }
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 25),
          _buildApplyButton(
            onPressed: () {
              if (_encodeCols.isEmpty) {
                _showSnackbar('Please select at least one column.', isError: true);
                return;
              }
              if (_encodeMethod == 'onehot' || _encodeMethod == 'label') {
                ref.read(datasetProvider.notifier).encodeColumns(_encodeCols, _encodeMethod);
              } else {
                ref.read(datasetProvider.notifier).scaleColumns(_encodeCols, _encodeMethod);
              }
              _showSnackbar('Applying preprocessing on ${_encodeCols.length} columns.');
              _encodeCols.clear();
            },
          ),
        ],
      );
    } else if (_selectedCleanCategory == 'engineering') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormTitle('Feature Engineering Tools', Icons.build_rounded),
          const SizedBox(height: 15),
          _buildLabel('Feature Category'),
          _buildDropdown(
            value: _engMethod,
            items: const ['datetime', 'tfidf'],
            onChanged: (val) => setState(() => _engMethod = val!),
          ),
          const SizedBox(height: 15),
          _buildLabel('Target Column'),
          _buildDropdown(
            value: _engCol,
            items: _engMethod == 'datetime' ? datetimeCols : textCols,
            onChanged: (val) => setState(() => _engCol = val),
          ),
          if (_engMethod == 'tfidf') ...[
            const SizedBox(height: 15),
            _buildLabel('TF-IDF Max Features ($_maxFeatures)'),
            Slider(
              value: _maxFeatures.toDouble(),
              min: 10,
              max: 200,
              divisions: 19,
              label: _maxFeatures.toString(),
              onChanged: (val) => setState(() => _maxFeatures = val.toInt()),
            ),
          ],
          const SizedBox(height: 25),
          _buildApplyButton(
            onPressed: () {
              if (_engCol == null) {
                _showSnackbar('No suitable columns found for this extraction type.', isError: true);
                return;
              }
              if (_engMethod == 'datetime') {
                ref.read(datasetProvider.notifier).extractDatetime(_engCol!);
              } else {
                ref.read(datasetProvider.notifier).vectorizeText(_engCol!, _maxFeatures);
              }
              _showSnackbar('Extracting features from $_engCol');
            },
          ),
        ],
      );
    } else { // recommendations category
      final recs = state.aiRecommendations;
      if (state.isLoadingRecommendations) {
        return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
      }
      if (recs == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 30),
                const SizedBox(height: 12),
                const Text('AI Suggestions unavailable.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.read(datasetProvider.notifier).loadRecommendations(),
                  child: const Text('Generate Recommendations'),
                ),
              ],
            ),
          ),
        );
      }

      final drops = List<dynamic>.from(recs['columns_to_drop'] ?? []);
      final encs = List<dynamic>.from(recs['encoding_recommendations'] ?? []);
      final scalings = List<dynamic>.from(recs['scaling_recommendations'] ?? []);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormTitle('AI Recommendations', Icons.psychology_rounded),
          const SizedBox(height: 10),
          Text(recs['general_summary'] ?? '', style: GoogleFonts.inter(fontSize: 12, height: 1.5, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          
          if (drops.isNotEmpty) ...[
            _buildLabel('SUGGESTED DROPS'),
            ...drops.map((d) => _buildSuggestionCard(
              title: 'Drop ${d['column']}',
              subtitle: d['reason'],
              icon: Icons.delete_outline_rounded,
              color: AppColors.danger,
              onApply: () {
                // Call clean out or encode
                // Quick drop can just be done via custom command or just ask AI chat
                ref.read(chatProvider.notifier).sendMessage('Apply recommendation to drop column "${d['column']}"');
                _showSnackbar('AI Copilot requested to handle drop: ${d['column']}');
              }
            )),
            const SizedBox(height: 15),
          ],
          
          if (encs.isNotEmpty) ...[
            _buildLabel('SUGGESTED ENCODINGS'),
            ...encs.map((e) => _buildSuggestionCard(
              title: 'Encode ${e['column']}',
              subtitle: '${e['method']}: ${e['reason']}',
              icon: Icons.code_rounded,
              color: AppColors.primary,
              onApply: () {
                setState(() {
                  _selectedCleanCategory = 'encoding';
                  _encodeMethod = e['method'].toString().toLowerCase().contains('one-hot') ? 'onehot' : 'label';
                  if (!_encodeCols.contains(e['column'])) _encodeCols.add(e['column']);
                });
              }
            )),
            const SizedBox(height: 15),
          ],

          if (scalings.isNotEmpty) ...[
            _buildLabel('SUGGESTED SCALINGS'),
            ...scalings.map((s) => _buildSuggestionCard(
              title: 'Scale ${s['column']}',
              subtitle: '${s['method']}: ${s['reason']}',
              icon: Icons.linear_scale_rounded,
              color: AppColors.secondary,
              onApply: () {
                setState(() {
                  _selectedCleanCategory = 'encoding';
                  _encodeMethod = s['method'].toString().toLowerCase().contains('standard') ? 'standardize' : 'normalize';
                  if (!_encodeCols.contains(s['column'])) _encodeCols.add(s['column']);
                });
              }
            )),
          ],
        ],
      );
    }
  }

  Widget _buildCenterPreviewPanel(DatasetState state, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          // Tab selector bar
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1220) : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            ),
            child: Row(
              children: [
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Data Preview (First 100 Rows)'),
                    Tab(text: 'Summary Schema Analysis'),
                  ],
                  labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  indicatorColor: AppColors.primary,
                ),
                const Spacer(),
                
                // Active Step log info
                if (state.history.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 20.0),
                    child: Text(
                      'Last action: ${state.history.lastWhere((step) => step['is_active'])['description']}',
                      style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          
          // Tab Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: DATA PREVIEW TABLE
                _buildDataGrid(state, isDark),
                
                // TAB 2: PROFILE SCHEMA DETAILS
                _buildSchemaDetails(state, isDark),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDataGrid(DatasetState state, bool isDark) {
    if (state.previewData.isEmpty) {
      return const Center(child: Text('No preview data available.'));
    }

    final columns = state.previewData.first.keys.toList();
    final colTypes = state.columnTypes;

    return Container(
      color: isDark ? const Color(0xFF090D16) : const Color(0xFFFAFAFA),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              ),
              border: TableBorder.all(
                color: isDark ? Colors.white10 : Colors.black12,
                width: 0.5,
              ),
              columnSpacing: 28,
              headingRowHeight: 45,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 40,
              columns: columns.map((col) {
                final type = colTypes[col] ?? 'categorical';
                return DataColumn(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _getColumnIcon(type),
                      const SizedBox(width: 8),
                      Text(
                        col,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              rows: state.previewData.map((row) {
                return DataRow(
                  cells: columns.map((col) {
                    final value = row[col];
                    final isNull = value == null;
                    return DataCell(
                      Text(
                        isNull ? 'NaN' : value.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isNull
                              ? AppColors.danger
                              : isDark
                                  ? Colors.white70
                                  : Colors.black87,
                          fontWeight: isNull ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSchemaDetails(DatasetState state, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: state.columns.length,
      itemBuilder: (context, i) {
        final col = state.columns[i];
        final type = col['type'];
        final nullCount = col['null_count'];
        final nullPct = col['null_percentage'];
        final stats = col['stats'];

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column Type Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _getColumnIcon(type, size: 24),
              ),
              const SizedBox(width: 20),
              
              // Column schema details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      col['name'],
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type: ${type.toString().toUpperCase()} (${col['native_dtype']}) | Unique Count: ${col['unique_count']}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    
                    // Missing percentage indicator
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (100 - nullPct) / 100,
                              backgroundColor: AppColors.danger.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$nullCount Nulls ($nullPct%)',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: nullCount > 0 ? AppColors.danger : Colors.grey),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              
              // Right detailed stats (mean, std, top categories)
              if (stats != null) ...[
                Container(
                  width: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats.containsKey('mean') ? 'Numerical Metrics' : 'Top Categories',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      if (stats.containsKey('mean')) ...[
                        _buildStatRow('Mean', stats['mean']),
                        _buildStatRow('Median', stats['median']),
                        _buildStatRow('Min', stats['min']),
                        _buildStatRow('Max', stats['max']),
                      ] else if (stats.containsKey('top_values')) ...[
                        ...Map<String, dynamic>.from(stats['top_values'] ?? {}).entries.map((e) {
                          return _buildStatRow(e.key, e.value);
                        }),
                      ]
                    ],
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildRightChatPanel(ChatState chatState, bool isDark) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        border: Border(left: BorderSide(color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000))),
      ),
      child: Column(
        children: [
          // Chat Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI Data Assistant',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  tooltip: 'Clear Chat History',
                  onPressed: () => ref.read(chatProvider.notifier).clearHistory(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Chat Message History bubble stream
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.all(12),
              itemCount: chatState.messages.length,
              itemBuilder: (context, i) {
                final bubble = chatState.messages[i];
                final isUser = bubble.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.primary
                          : isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                      ),
                      border: isUser
                          ? null
                          : Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: Text(
                      bubble.content,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.4,
                        color: isUser ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          if (chatState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
              ),
            ),
            
          const Divider(height: 1),
          
          // Chat Input panel
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        ref.read(chatProvider.notifier).sendMessage(val);
                        _chatController.clear();
                        _scrollToBottom();
                      }
                    },
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Ask AI: "Why are there nulls?"...',
                      hintStyle: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
                  onPressed: () {
                    final query = _chatController.text;
                    if (query.trim().isNotEmpty) {
                      ref.read(chatProvider.notifier).sendMessage(query);
                      _chatController.clear();
                      _scrollToBottom();
                    }
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- Inner Utility Widgets Builder Helpers ---

  Widget _buildFormTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
        )
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items.map((val) {
            return DropdownMenuItem<T>(
              value: val,
              child: Text(val.toString(), style: GoogleFonts.inter(fontSize: 12)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildApplyButton({required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          'Apply Transformation',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildWarningCard(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 10, color: AppColors.warning, height: 1.4),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSuggestionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onApply,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onApply,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              child: Text('Configure suggestion', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value) {
    String displayVal = value == null ? 'None' : value.toString();
    if (value is double) displayVal = value.toStringAsFixed(3);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
          Text(displayVal, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _getColumnIcon(String type, {double size = 16}) {
    if (type == 'numerical') {
      return Icon(Icons.tag_rounded, color: AppColors.primary, size: size);
    } else if (type == 'categorical') {
      return Icon(Icons.category_rounded, color: AppColors.success, size: size);
    } else if (type == 'datetime') {
      return Icon(Icons.calendar_today_rounded, color: AppColors.warning, size: size);
    } else {
      return Icon(Icons.text_format_rounded, color: AppColors.danger, size: size);
    }
  }
}
