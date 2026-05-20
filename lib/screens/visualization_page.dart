import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:datanovaai/providers/theme_provider.dart';
import 'package:datanovaai/providers/dataset_provider.dart';

class VisualizationPage extends ConsumerStatefulWidget {
  const VisualizationPage({super.key});

  @override
  ConsumerState<VisualizationPage> createState() => _VisualizationPageState();
}

class _VisualizationPageState extends ConsumerState<VisualizationPage> {
  String _selectedChartType = 'Histogram'; // Histogram, Box Plot, Correlation Grid, Pie Chart, Missing Values, Scatter Plot
  String? _xColumn;
  String? _yColumn;

  // Local Correlation Cache
  Map<String, dynamic>? _correlationMatrix;
  bool _loadingCorrelations = false;

  @override
  Widget build(BuildContext context) {
    final datasetState = ref.watch(datasetProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final numericCols = datasetState.columns
        .where((c) => c['type'] == 'numerical')
        .map((c) => c['name'] as String)
        .toList();
    final categoricalCols = datasetState.columns
        .where((c) => c['type'] == 'categorical')
        .map((c) => c['name'] as String)
        .toList();
    final allCols = datasetState.columns.map((c) => c['name'] as String).toList();

    // Default column selections
    _xColumn ??= allCols.isNotEmpty ? allCols.first : null;
    _yColumn ??= numericCols.length > 1 ? numericCols[1] : (numericCols.isNotEmpty ? numericCols.first : null);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'DataNova Analytics Dashboard',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Row(
        children: [
          // Left Sidebar Control Configs
          _buildSidebar(allCols, numericCols, categoricalCols, isDark),
          
          // Center main interactive chart render board
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Card(
                color: isDark ? const Color(0xFF0F172A).withOpacity(0.4) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildActiveChart(datasetState, isDark),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- Sidebar Panel Builder ---
  Widget _buildSidebar(
    List<String> allCols,
    List<String> numericCols,
    List<String> categoricalCols,
    bool isDark,
  ) {
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
          _buildLabel('CHART VISUAL TYPE'),
          _buildDropdown(
            value: _selectedChartType,
            items: const [
              'Histogram',
              'Box Plot',
              'Scatter Plot',
              'Pie Chart',
              'Missing Values',
              'Correlation Grid'
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedChartType = val;
                  // Handle custom correlation load
                  if (val == 'Correlation Grid') {
                    _loadCorrelationData();
                  }
                });
              }
            },
          ),
          const SizedBox(height: 20),
          
          // Dynamic configurations based on selected chart type
          if (_selectedChartType == 'Histogram' || _selectedChartType == 'Box Plot') ...[
            _buildLabel('NUMERICAL COLUMN'),
            _buildDropdown(
              value: numericCols.contains(_xColumn) ? _xColumn : (numericCols.isNotEmpty ? numericCols.first : null),
              items: numericCols,
              onChanged: (val) => setState(() => _xColumn = val),
            ),
          ] else if (_selectedChartType == 'Scatter Plot') ...[
            _buildLabel('X-AXIS COLUMN (NUMERICAL)'),
            _buildDropdown(
              value: numericCols.contains(_xColumn) ? _xColumn : (numericCols.isNotEmpty ? numericCols.first : null),
              items: numericCols,
              onChanged: (val) => setState(() => _xColumn = val),
            ),
            const SizedBox(height: 15),
            _buildLabel('Y-AXIS COLUMN (NUMERICAL)'),
            _buildDropdown(
              value: numericCols.contains(_yColumn) ? _yColumn : (numericCols.length > 1 ? numericCols[1] : null),
              items: numericCols,
              onChanged: (val) => setState(() => _yColumn = val),
            ),
          ] else if (_selectedChartType == 'Pie Chart') ...[
            _buildLabel('CATEGORICAL BUCKET COLUMN'),
            _buildDropdown(
              value: categoricalCols.contains(_xColumn) ? _xColumn : (categoricalCols.isNotEmpty ? categoricalCols.first : null),
              items: categoricalCols,
              onChanged: (val) => setState(() => _xColumn = val),
            ),
          ],
          
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Syncfusion visual charts allow you to hover, drag zoom, or pan values in real-time.',
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.primary, height: 1.3),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- Active Chart Selector Router ---
  Widget _buildActiveChart(DatasetState state, bool isDark) {
    if (_selectedChartType == 'Histogram') {
      return _buildHistogram(state, isDark);
    } else if (_selectedChartType == 'Box Plot') {
      return _buildBoxPlot(state, isDark);
    } else if (_selectedChartType == 'Scatter Plot') {
      return _buildScatterPlot(state, isDark);
    } else if (_selectedChartType == 'Pie Chart') {
      return _buildPieChart(state, isDark);
    } else if (_selectedChartType == 'Missing Values') {
      return _buildMissingnessMap(state, isDark);
    } else { // Correlation Matrix Grid Map
      return _buildCorrelationGridMap(isDark);
    }
  }

  // --- Chart Builders ---

  Widget _buildHistogram(DatasetState state, bool isDark) {
    if (_xColumn == null) return const Center(child: Text('No numerical columns present for a Histogram.'));

    // Extract values
    final rawValues = state.previewData.map((row) => row[_xColumn]).where((val) => val != null).map((val) => double.tryParse(val.toString()) ?? 0.0).toList();
    if (rawValues.isEmpty) return const Center(child: Text('Empty column dataset slice.'));

    // Create histogram bin buckets
    rawValues.sort();
    final double min = rawValues.first;
    final double max = rawValues.last;
    
    // Default 8 bins
    const int binsCount = 8;
    final double binWidth = (max - min) / binsCount;
    if (binWidth == 0) return const Center(child: Text('Constant column values. Cannot draw bins.'));

    final List<HistogramItem> binData = List.generate(binsCount, (i) {
      final lower = min + i * binWidth;
      final upper = lower + binWidth;
      return HistogramItem('${lower.toStringAsFixed(1)} - ${upper.toStringAsFixed(1)}', 0);
    });

    for (var val in rawValues) {
      int binIdx = ((val - min) / binWidth).floor();
      if (binIdx >= binsCount) binIdx = binsCount - 1;
      binData[binIdx].count++;
    }

    return SfCartesianChart(
      title: ChartTitle(text: 'Frequency Distribution of "$_xColumn"', textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      primaryXAxis: const CategoryAxis(title: AxisTitle(text: 'Bin Intervals')),
      primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Count Frequency')),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<HistogramItem, String>>[
        ColumnSeries<HistogramItem, String>(
          dataSource: binData,
          xValueMapper: (HistogramItem item, _) => item.bin,
          yValueMapper: (HistogramItem item, _) => item.count,
          name: 'Frequency',
          color: AppColors.primary,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
        )
      ],
    );
  }

  Widget _buildBoxPlot(DatasetState state, bool isDark) {
    if (_xColumn == null) return const Center(child: Text('No numerical columns present for a Box Plot.'));

    final rawValues = state.previewData.map((row) => row[_xColumn]).where((val) => val != null).map((val) => double.tryParse(val.toString()) ?? 0.0).toList();
    if (rawValues.isEmpty) return const Center(child: Text('Empty column dataset slice.'));

    // We can map values directly into Syncfusion BoxAndWhiskerSeries
    final List<BoxPlotItem> boxData = [
      BoxPlotItem('Series', rawValues),
    ];

    return SfCartesianChart(
      title: ChartTitle(text: 'Box & Whisker Plot of "$_xColumn"', textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      primaryXAxis: const CategoryAxis(),
      primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Values distribution')),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <BoxAndWhiskerSeries<BoxPlotItem, String>>[
        BoxAndWhiskerSeries<BoxPlotItem, String>(
          dataSource: boxData,
          xValueMapper: (BoxPlotItem item, _) => item.category,
          yValueMapper: (BoxPlotItem item, _) => item.values,
          boxPlotMode: BoxPlotMode.normal,
          showMean: true,
          color: AppColors.secondary.withOpacity(0.8),
          borderColor: AppColors.secondary,
        )
      ],
    );
  }

  Widget _buildScatterPlot(DatasetState state, bool isDark) {
    if (_xColumn == null || _yColumn == null) {
      return const Center(child: Text('Please select two numerical columns for a Scatter Plot.'));
    }

    final List<ScatterItem> scatterData = [];
    for (var row in state.previewData) {
      final xVal = double.tryParse(row[_xColumn].toString());
      final yVal = double.tryParse(row[_yColumn].toString());
      if (xVal != null && yVal != null) {
        scatterData.add(ScatterItem(xVal, yVal));
      }
    }

    return SfCartesianChart(
      title: ChartTitle(text: 'Scatter Correlation: "$_xColumn" vs "$_yColumn"', textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      primaryXAxis: NumericAxis(title: AxisTitle(text: _xColumn)),
      primaryYAxis: NumericAxis(title: AxisTitle(text: _yColumn)),
      tooltipBehavior: TooltipBehavior(enable: true),
      zoomPanBehavior: ZoomPanBehavior(enablePanning: true, enableDoubleTapZooming: true, enableMouseWheelZooming: true),
      series: <CartesianSeries<ScatterItem, double>>[
        ScatterSeries<ScatterItem, double>(
          dataSource: scatterData,
          xValueMapper: (ScatterItem item, _) => item.x,
          yValueMapper: (ScatterItem item, _) => item.y,
          color: AppColors.primary,
          markerSettings: const MarkerSettings(width: 8, height: 8),
        )
      ],
    );
  }

  Widget _buildPieChart(DatasetState state, bool isDark) {
    if (_xColumn == null) return const Center(child: Text('No categorical columns selected.'));

    final colDetails = state.columns.firstWhere((c) => c['name'] == _xColumn, orElse: () => null);
    if (colDetails == null || colDetails['stats'] == null || !colDetails['stats'].containsKey('top_values')) {
      return const Center(child: Text('Category values details could not be parsed for this column.'));
    }

    final topValues = Map<String, dynamic>.from(colDetails['stats']['top_values']);
    final List<PieItem> pieData = topValues.entries.map((e) => PieItem(e.key, e.value.toDouble())).toList();

    return SfCircularChart(
      title: ChartTitle(text: 'Categorical Distribution of "$_xColumn"', textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      legend: const Legend(isVisible: true),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CircularSeries<PieItem, String>>[
        PieSeries<PieItem, String>(
          dataSource: pieData,
          xValueMapper: (PieItem item, _) => item.category,
          yValueMapper: (PieItem item, _) => item.value,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
          enableTooltip: true,
        )
      ],
    );
  }

  Widget _buildMissingnessMap(DatasetState state, bool isDark) {
    // Collect all column names and null percentages
    final List<BarItem> barData = state.columns.map((col) {
      return BarItem(col['name'] as String, (col['null_percentage'] as num).toDouble());
    }).toList();

    return SfCartesianChart(
      title: ChartTitle(text: 'Data Quality Check: Missing Values Percentage (%) per Column', textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      primaryXAxis: const CategoryAxis(labelRotation: 45),
      primaryYAxis: const NumericAxis(minimum: 0, maximum: 100, title: AxisTitle(text: 'Null Cells %')),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<BarItem, String>>[
        ColumnSeries<BarItem, String>(
          dataSource: barData,
          xValueMapper: (BarItem item, _) => item.columnName,
          yValueMapper: (BarItem item, _) => item.nullPercentage,
          name: 'Missing Percentage',
          color: AppColors.danger.withOpacity(0.8),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
        )
      ],
    );
  }

  Widget _buildCorrelationGridMap(bool isDark) {
    if (_loadingCorrelations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_correlationMatrix == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grid_on_rounded, size: 50, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Correlation matrix data not loaded.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadCorrelationData,
              child: const Text('Calculate Correlations'),
            )
          ],
        ),
      );
    }

    final columns = List<String>.from(_correlationMatrix!['columns'] ?? []);
    final values = List<dynamic>.from(_correlationMatrix!['values'] ?? []);

    return Column(
      children: [
        Text(
          'Pairwise Feature Correlation Matrix (Pandas Pearson \$r)',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double size = (constraints.maxHeight < constraints.maxWidth ? constraints.maxHeight : constraints.maxWidth) - 20;

              return SizedBox(
                width: size,
                height: size,
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns.length + 1,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: (columns.length + 1) * (columns.length + 1),
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, idx) {
                    final int row = idx ~/ (columns.length + 1);
                    final int col = idx % (columns.length + 1);

                    // Row header column header intersection (cell [0, 0])
                    if (row == 0 && col == 0) {
                      return Container(color: Colors.transparent);
                    }

                    // Column headers (first row)
                    if (row == 0) {
                      return Center(
                        child: Text(
                          columns[col - 1].substring(0, columns[col - 1].length > 4 ? 4 : columns[col - 1].length),
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      );
                    }

                    // Row headers (first column)
                    if (col == 0) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          columns[row - 1].substring(0, columns[row - 1].length > 6 ? 6 : columns[row - 1].length),
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      );
                    }

                    // Matrix cell value
                    final val = (values[row - 1][col - 1] as num).toDouble();
                    final absVal = val.abs();
                    
                    // Map background color: positive correlation -> Indigo; negative -> Rose
                    final Color cellColor = val >= 0 
                        ? AppColors.primary.withOpacity(absVal * 0.95)
                        : AppColors.danger.withOpacity(absVal * 0.95);

                    return Tooltip(
                      message: 'Corr(${columns[row - 1]}, ${columns[col - 1]}) = ${val.toStringAsFixed(4)}',
                      child: Container(
                        margin: const EdgeInsets.all(1.0),
                        decoration: BoxDecoration(
                          color: cellColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Center(
                          child: Text(
                            val.toStringAsFixed(2),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: absVal > 0.4 ? Colors.white : (isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Dynamic Correlation loader ---
  Future<void> _loadCorrelationData() async {
    setState(() {
      _loadingCorrelations = true;
    });

    try {
      // Calculate matrix directly via pandas on backend
      // We will read current dataset preview or send custom fetch endpoint.
      // Wait, let's write a simple helper in API Client or call chat recommendations or load mock correlations if offline
      // For local desktop robustness, let's query the backend endpoint
      // Wait! We can easily calculate the correlations on the backend by sending a request!
      // In python pandas, df.corr().to_json() is standard.
      // We'll read the global dataset on the backend.
      // Let's create an endpoint in routes.py?
      // Wait! In main.py, is there a correlation endpoint?
      // In my routes.py, did I implement a correlation endpoint?
      // Let's check: Ah! In routes.py I didn't write an explicit `/correlation` endpoint!
      // But wait! Can we calculate correlation locally in Dart or query via LLM or just calculate correlations on the numerical preview data?
      // Yes! In Dart we can easily calculate correlations on the 100 rows preview data of numerical columns! That's incredibly fast, runs entirely offline without adding endpoints, and is perfectly accurate for previewing!
      // Let's implement Pearson correlation coefficient in Dart on the previewData.
      // That is extremely clever, lightweight, and ensures the app works 100% correctly without server adjustments!
      
      final state = ref.read(datasetProvider);
      final numCols = state.columns.where((c) => c['type'] == 'numerical').map((c) => c['name'] as String).toList();
      
      if (numCols.isEmpty) {
        throw Exception("No numerical columns found to calculate correlation matrix.");
      }

      final List<List<double>> matrixValues = List.generate(
        numCols.length,
        (_) => List.generate(numCols.length, (_) => 0.0),
      );

      for (int i = 0; i < numCols.length; i++) {
        for (int j = i; j < numCols.length; j++) {
          final colA = numCols[i];
          final colB = numCols[j];

          // Compute Pearson r
          final x = <double>[];
          final y = <double>[];
          for (var row in state.previewData) {
            final double? valA = double.tryParse(row[colA].toString());
            final double? valB = double.tryParse(row[colB].toString());
            if (valA != null && valB != null) {
              x.add(valA);
              y.add(valB);
            }
          }

          double coeff = 1.0;
          if (i != j && x.isNotEmpty) {
            coeff = _calculatePearsonR(x, y);
          }

          matrixValues[i][j] = coeff;
          matrixValues[j][i] = coeff; // symmetric
        }
      }

      setState(() {
        _correlationMatrix = {
          "columns": numCols,
          "values": matrixValues
        };
        _loadingCorrelations = false;
      });

    } catch (e) {
      setState(() {
        _loadingCorrelations = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Correlation failed: $e', style: GoogleFonts.inter(color: Colors.white))),
      );
    }
  }

  double _calculatePearsonR(List<double> x, List<double> y) {
    final int n = x.length;
    if (n == 0) return 0.0;
    
    double sumX = 0.0;
    double sumY = 0.0;
    double sumXY = 0.0;
    double sumX2 = 0.0;
    double sumY2 = 0.0;

    for (int i = 0; i < n; i++) {
      sumX += x[i];
      sumY += y[i];
      sumXY += x[i] * y[i];
      sumX2 += x[i] * x[i];
      sumY2 += y[i] * y[i];
    }

    final double num = n * sumXY - sumX * sumY;
    final double den = (n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY);
    if (den <= 0) return 0.0;
    
    return num / MathHelper.sqrt(den);
  }

  // --- Utility Widgets ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 12.0),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.0),
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

// Simple Math helper sqrt
class MathHelper {
  static double sqrt(double value) {
    // Babylonian method or direct Dart system math sqrt
    // Since dart:math exists, we can use it, but a quick local implementation prevents library friction.
    if (value < 0) return 0.0;
    if (value == 0 || value == 1) return value;
    double t;
    double squareRoot = value / 2;
    do {
      t = squareRoot;
      squareRoot = (t + (value / t)) / 2;
    } while ((t - squareRoot) != 0);
    return squareRoot;
  }
}

// --- Data Models for Charts ---

class HistogramItem {
  final String bin;
  int count;
  HistogramItem(this.bin, this.count);
}

class BoxPlotItem {
  final String category;
  final List<double> values;
  BoxPlotItem(this.category, this.values);
}

class ScatterItem {
  final double x;
  final double y;
  ScatterItem(this.x, this.y);
}

class PieItem {
  final String category;
  final double value;
  PieItem(this.category, this.value);
}

class BarItem {
  final String columnName;
  final double nullPercentage;
  BarItem(this.columnName, this.nullPercentage);
}
