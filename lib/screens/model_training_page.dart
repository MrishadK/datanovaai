import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:datanovaai/providers/theme_provider.dart';
import 'package:datanovaai/providers/dataset_provider.dart';
import 'package:datanovaai/services/api_client.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ModelTrainingPage extends ConsumerStatefulWidget {
  const ModelTrainingPage({super.key});

  @override
  ConsumerState<ModelTrainingPage> createState() => _ModelTrainingPageState();
}

class _ModelTrainingPageState extends ConsumerState<ModelTrainingPage> {
  String? _targetCol;
  final List<String> _selectedFeatures = [];
  double _testSize = 0.2;
  bool _selectAllFeatures = true;

  // Selected evaluation view model
  Map<String, dynamic>? _activeTrainedModel;

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _downloadModel(String modelName) async {
    final client = ref.read(apiClientProvider);
    final url = client.getModelExportUrl(modelName);
    
    _showSnackbar('Exporting trained ML pipeline. Please wait...');
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // Save to User's Downloads directory
        Directory? downloadDir = await getDownloadsDirectory();
        downloadDir ??= await getApplicationDocumentsDirectory();
        
        final safeName = modelName.replaceAll(' ', '_').toLowerCase();
        final savePath = '${downloadDir.path}/datanova_model_$safeName.pkl';
        
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        
        _showSnackbar('Trained model successfully saved to: $savePath');
      } else {
        _showSnackbar('Failed to download model from backend.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Export failed: $e', isError: true);
    }
  }

  Future<void> _downloadPDFReport() async {
    final client = ref.read(apiClientProvider);
    final url = client.getPDFReportUrl();
    
    _showSnackbar('Generating PDF Preprocessing Report...');
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Directory? downloadDir = await getDownloadsDirectory();
        downloadDir ??= await getApplicationDocumentsDirectory();
        
        final filename = ref.read(datasetProvider).filename.replaceAll('.', '_');
        final savePath = '${downloadDir.path}/datanova_report_$filename.pdf';
        
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        
        _showSnackbar('DataNova AI PDF Report saved to: $savePath');
      } else {
        _showSnackbar('Failed to generate report from backend.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Report failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final datasetState = ref.watch(datasetProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allCols = datasetState.columns.map((c) => c['name'] as String).toList();
    _targetCol ??= allCols.isNotEmpty ? allCols.last : null;

    // Features excluding target
    final featureCandidates = allCols.where((col) => col != _targetCol).toList();
    if (_selectedFeatures.isEmpty && _selectAllFeatures) {
      _selectedFeatures.addAll(featureCandidates);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'DataNova AutoML Command Center',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Row(
        children: [
          // Left Sidebar Configurations
          _buildConfigSidebar(featureCandidates, allCols, datasetState, isDark),

          // Center Workspace (Live comparison or detailed analytics)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: _buildMainBody(datasetState, isDark),
            ),
          )
        ],
      ),
    );
  }

  // --- Left Configuration Sidebar ---
  Widget _buildConfigSidebar(List<String> featureCandidates, List<String> allCols, DatasetState state, bool isDark) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        border: Border(right: BorderSide(color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000))),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormTitle('AutoML Setup', Icons.settings_input_component_rounded),
          const SizedBox(height: 20),
          
          _buildLabel('TARGET COLUMN (LABEL VARIABLE)'),
          _buildDropdown(
            value: _targetCol,
            items: allCols,
            onChanged: (val) {
              setState(() {
                _targetCol = val;
                _selectedFeatures.clear();
                _selectAllFeatures = true;
              });
            },
          ),
          const SizedBox(height: 20),

          _buildLabel('TRAINING FEATURES'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Select All Features', style: GoogleFonts.inter(fontSize: 12)),
              Checkbox(
                value: _selectAllFeatures,
                onChanged: (val) {
                  setState(() {
                    _selectAllFeatures = val ?? false;
                    _selectedFeatures.clear();
                    if (_selectAllFeatures) {
                      _selectedFeatures.addAll(featureCandidates);
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Feature scroll list
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: ListView.builder(
                itemCount: featureCandidates.length,
                itemBuilder: (context, i) {
                  final col = featureCandidates[i];
                  return CheckboxListTile(
                    title: Text(col, style: GoogleFonts.inter(fontSize: 12)),
                    value: _selectedFeatures.contains(col),
                    dense: true,
                    onChanged: (val) {
                      setState(() {
                        _selectAllFeatures = false;
                        if (val == true) {
                          _selectedFeatures.add(col);
                        } else {
                          _selectedFeatures.remove(col);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 15),

          _buildLabel('TEST RATIO SIZE: ${(_testSize * 100).toInt()}%'),
          Slider(
            value: _testSize,
            min: 0.1,
            max: 0.4,
            divisions: 6,
            label: _testSize.toString(),
            onChanged: (val) => setState(() => _testSize = val),
          ),
          const SizedBox(height: 20),

          // Start Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isMLTraining
                  ? null
                  : () {
                      if (_targetCol == null) return;
                      ref.read(datasetProvider.notifier).trainAutoML(
                            _targetCol!,
                            featureColumns: _selectedFeatures,
                            testSize: _testSize,
                          );
                      _activeTrainedModel = null;
                      _showSnackbar('AutoML Parallel Training Pipeline Launched!');
                    },
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: const Text('Launch AutoML'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Main Board Panel ---
  Widget _buildMainBody(DatasetState state, bool isDark) {
    if (state.isMLTraining) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              strokeWidth: 6,
            ),
            const SizedBox(height: 24),
            Text(
              'Preprocessing variables and training 5 AutoML models in parallel...',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Running: Logistic/Linear Regression, Decision Tree, Random Forest, and XGBoost',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final results = state.automlResults;
    if (results == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.model_training_rounded, size: 70, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'AutoML Engine Ready',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a target label, customize features, and click "Launch AutoML" to train pipeline.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final List<dynamic> models = results['models_evaluated'] ?? [];
    final taskType = results['task_type'] ?? 'classification';
    final bestModel = results['best_model'] ?? '';

    // Cache active trained model if null
    if (_activeTrainedModel == null && models.isNotEmpty) {
      // Set best model as default active view
      _activeTrainedModel = Map<String, dynamic>.from(
        models.firstWhere((m) => m['model_name'] == bestModel, orElse: () => models.first),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading Overview
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AutoML Evaluation Leaderboard (${taskType.toString().toUpperCase()})',
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Champion Model: $bestModel',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            // PDF Report download trigger
            ElevatedButton.icon(
              onPressed: _downloadPDFReport,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: const Text('Export PDF Summary Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          ],
        ),
        const SizedBox(height: 24),

        // Leaderboard Row Cards
        SizedBox(
          height: 120,
          child: Row(
            children: models.map((model) {
              final name = model['model_name'];
              final isBest = name == bestModel;
              final isActive = _activeTrainedModel?['model_name'] == name;
              
              // Scoring metric representation
              double score = 0.0;
              String metricLbl = 'Score';
              if (taskType == 'classification') {
                score = (model['f1_score'] as num?)?.toDouble() ?? 0.0;
                metricLbl = 'F1-Score';
              } else {
                score = (model['r2_score'] as num?)?.toDouble() ?? 0.0;
                metricLbl = 'R2 Score';
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeTrainedModel = Map<String, dynamic>.from(model)),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary.withOpacity(0.08)
                          : (isDark ? const Color(0xFF0F172A).withOpacity(0.4) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isActive
                            ? AppColors.primary
                            : isBest
                                ? AppColors.success.withOpacity(0.5)
                                : (isDark ? Colors.white10 : Colors.black12),
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (isBest)
                              const Icon(Icons.emoji_events_rounded, color: AppColors.success, size: 16),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$metricLbl: ${score.toStringAsFixed(4)}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isBest ? AppColors.success : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Time: ${model['training_time_seconds']}s',
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 28),

        // Selected Model Detailed Metrics Panel
        if (_activeTrainedModel != null)
          Expanded(
            child: Row(
              children: [
                // Left Panel: Details Table + Feature Importance
                Expanded(
                  flex: 3,
                  child: Card(
                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.3) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_activeTrainedModel!['model_name']} - Performance Details',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              // PKL Download trigger
                              ElevatedButton.icon(
                                onPressed: () => _downloadModel(_activeTrainedModel!['model_name']),
                                icon: const Icon(Icons.download_rounded, size: 14),
                                label: const Text('Export .pkl Pipeline'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 15),
                          
                          // Metric cards Grid
                          Row(
                            children: _buildDetailMetricCards(taskType, isDark),
                          ),
                          const SizedBox(height: 25),

                          // Feature Importance Chart
                          Expanded(
                            child: _buildFeatureImportanceChart(isDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Right Panel: Interactive Confusion Matrix (only for Classification)
                if (taskType == 'classification')
                  Expanded(
                    flex: 2,
                    child: Card(
                      color: isDark ? const Color(0xFF0F172A).withOpacity(0.3) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: _buildConfusionMatrixGrid(isDark),
                      ),
                    ),
                  )
              ],
            ),
          )
      ],
    );
  }

  // --- Secondary Component Builders ---

  List<Widget> _buildDetailMetricCards(String taskType, bool isDark) {
    final model = _activeTrainedModel!;
    final List<Widget> cards = [];

    Widget buildSmallCard(String title, String val, Color c) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(val, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: c)),
            ],
          ),
        ),
      );
    }

    if (taskType == 'classification') {
      cards.add(buildSmallCard('ACCURACY', model['accuracy'].toString(), AppColors.primary));
      cards.add(buildSmallCard('PRECISION', model['precision'].toString(), AppColors.secondary));
      cards.add(buildSmallCard('RECALL', model['recall'].toString(), AppColors.warning));
      cards.add(buildSmallCard('F1 SCORE', model['f1_score'].toString(), AppColors.success));
    } else {
      cards.add(buildSmallCard('R2 SCORE', model['r2_score'].toString(), AppColors.success));
      cards.add(buildSmallCard('MAE', model['mae'].toString(), AppColors.primary));
      cards.add(buildSmallCard('RMSE', model['rmse'].toString(), AppColors.secondary));
      cards.add(buildSmallCard('MSE', model['mse'].toString(), AppColors.danger));
    }

    return cards;
  }

  Widget _buildFeatureImportanceChart(bool isDark) {
    final List<dynamic> importances = _activeTrainedModel!['feature_importance'] ?? [];
    if (importances.isEmpty) {
      return const Center(child: Text('Feature Importance metrics not supported for this model.'));
    }

    // Top 8 features
    final displayList = importances.take(8).toList();
    final List<ImportanceItem> chartData = displayList.map((item) {
      return ImportanceItem(item['feature'].toString(), (item['importance'] as num).toDouble());
    }).toList();

    // Invert list for neat top-down rendering
    final chartDataReversed = chartData.reversed.toList();

    return SfCartesianChart(
      title: ChartTitle(text: 'Top Predictive Feature Importances', textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
      primaryXAxis: const CategoryAxis(title: AxisTitle(text: 'Features')),
      primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Importance Gini Weights')),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<ImportanceItem, String>>[
        BarSeries<ImportanceItem, String>(
          dataSource: chartDataReversed,
          xValueMapper: (ImportanceItem item, _) => item.feature,
          yValueMapper: (ImportanceItem item, _) => item.weight,
          color: AppColors.primary,
          borderRadius: const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
        )
      ],
    );
  }

  Widget _buildConfusionMatrixGrid(bool isDark) {
    final cmData = _activeTrainedModel!['confusion_matrix'];
    if (cmData == null) return const Center(child: Text('Confusion matrix unavailable.'));

    final matrixList = List<dynamic>.from(cmData['matrix'] ?? []);
    final labels = List<String>.from(cmData['labels'] ?? []);
    final int size = labels.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confusion Matrix Heatmap',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text('Y-Axis: Actual Labels | X-Axis: Predicted Labels', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 20),
        
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: size + 1,
                  childAspectRatio: 1.0,
                ),
                itemCount: (size + 1) * (size + 1),
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, idx) {
                  final int row = idx ~/ (size + 1);
                  final int col = idx % (size + 1);

                  // Top corner
                  if (row == 0 && col == 0) return Container();

                  // Column labels (predicted)
                  if (row == 0) {
                    return Center(
                      child: Text(
                        labels[col - 1].substring(0, labels[col - 1].length > 4 ? 4 : labels[col - 1].length),
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                    );
                  }

                  // Row labels (actual)
                  if (col == 0) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        labels[row - 1].substring(0, labels[row - 1].length > 5 ? 5 : labels[row - 1].length),
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    );
                  }

                  // Matrix numbers
                  final int val = matrixList[row - 1][col - 1];
                  
                  // Heat density mapping: True Positives (diagonal) are dense indigo, False positives are faint gray
                  final bool isDiagonal = (row - 1) == (col - 1);
                  final Color cellColor = isDiagonal
                      ? AppColors.primary.withOpacity(0.85)
                      : AppColors.danger.withOpacity(val > 0 ? 0.35 : 0.05);

                  return Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Center(
                      child: Text(
                        val.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDiagonal ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Utility Widgets ---
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
      padding: const EdgeInsets.only(bottom: 6.0, top: 12.0),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
      width: double.infinity,
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
}

// Chart models
class ImportanceItem {
  final String feature;
  final double weight;
  ImportanceItem(this.feature, this.weight);
}
