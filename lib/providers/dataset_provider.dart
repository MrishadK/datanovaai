import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:datanovaai/services/api_client.dart';

class DatasetState {
  final bool isBackendConnected;
  final bool isLoading;
  final String? errorMessage;
  
  // Active Dataset Info
  final bool hasDataset;
  final String filename;
  final int rowsCount;
  final int columnsCount;
  final int missingValuesCount;
  final int duplicateRowsCount;
  final double duplicatePercentage;
  final Map<String, String> columnTypes; // col -> 'numerical' | 'categorical' | 'datetime' | 'text'
  final List<dynamic> columns; // detailed column stats
  final List<Map<String, dynamic>> previewData;
  final List<dynamic> history; // operation history steps

  // AutoML State
  final bool isMLTraining;
  final Map<String, dynamic>? automlResults;

  // AI recommendations
  final bool isLoadingRecommendations;
  final Map<String, dynamic>? aiRecommendations;

  DatasetState({
    this.isBackendConnected = false,
    this.isLoading = false,
    this.errorMessage,
    this.hasDataset = false,
    this.filename = '',
    this.rowsCount = 0,
    this.columnsCount = 0,
    this.missingValuesCount = 0,
    this.duplicateRowsCount = 0,
    this.duplicatePercentage = 0.0,
    this.columnTypes = const {},
    this.columns = const [],
    this.previewData = const [],
    this.history = const [],
    this.isMLTraining = false,
    this.automlResults,
    this.isLoadingRecommendations = false,
    this.aiRecommendations,
  });

  DatasetState copyWith({
    bool? isBackendConnected,
    bool? isLoading,
    String? errorMessage,
    bool? hasDataset,
    String? filename,
    int? rowsCount,
    int? columnsCount,
    int? missingValuesCount,
    int? duplicateRowsCount,
    double? duplicatePercentage,
    Map<String, String>? columnTypes,
    List<dynamic>? columns,
    List<Map<String, dynamic>>? previewData,
    List<dynamic>? history,
    bool? isMLTraining,
    Map<String, dynamic>? automlResults,
    bool? isLoadingRecommendations,
    Map<String, dynamic>? aiRecommendations,
  }) {
    return DatasetState(
      isBackendConnected: isBackendConnected ?? this.isBackendConnected,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // null by default, clear old errors
      hasDataset: hasDataset ?? this.hasDataset,
      filename: filename ?? this.filename,
      rowsCount: rowsCount ?? this.rowsCount,
      columnsCount: columnsCount ?? this.columnsCount,
      missingValuesCount: missingValuesCount ?? this.missingValuesCount,
      duplicateRowsCount: duplicateRowsCount ?? this.duplicateRowsCount,
      duplicatePercentage: duplicatePercentage ?? this.duplicatePercentage,
      columnTypes: columnTypes ?? this.columnTypes,
      columns: columns ?? this.columns,
      previewData: previewData ?? this.previewData,
      history: history ?? this.history,
      isMLTraining: isMLTraining ?? this.isMLTraining,
      automlResults: automlResults ?? this.automlResults,
      isLoadingRecommendations: isLoadingRecommendations ?? this.isLoadingRecommendations,
      aiRecommendations: aiRecommendations ?? this.aiRecommendations,
    );
  }
}

class DatasetNotifier extends StateNotifier<DatasetState> {
  final ApiClient _apiClient;

  DatasetNotifier(this._apiClient) : super(DatasetState()) {
    checkConnection();
  }

  Future<void> checkConnection() async {
    final connected = await _apiClient.checkConnection();
    state = state.copyWith(isBackendConnected: connected);
  }

  void _setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void _setError(String msg) {
    state = state.copyWith(errorMessage: msg, isLoading: false, isMLTraining: false, isLoadingRecommendations: false);
  }

  void _updateFromSummary(Map<String, dynamic> summary) {
    final previewList = List<dynamic>.from(summary['preview_data'] ?? []);
    final List<Map<String, dynamic>> previewRows = previewList.map((row) {
      return Map<String, dynamic>.from(row as Map);
    }).toList();

    state = state.copyWith(
      hasDataset: true,
      filename: summary['filename'] ?? '',
      rowsCount: summary['rows_count'] ?? 0,
      columnsCount: summary['columns_count'] ?? 0,
      missingValuesCount: summary['missing_values_count'] ?? 0,
      duplicateRowsCount: summary['duplicate_rows_count'] ?? 0,
      duplicatePercentage: (summary['duplicate_percentage'] ?? 0.0).toDouble(),
      columnTypes: Map<String, String>.from(summary['column_types'] ?? {}),
      columns: List<dynamic>.from(summary['columns'] ?? []),
      previewData: previewRows,
      history: List<dynamic>.from(summary['history'] ?? []),
      isLoading: false,
    );
  }

  /// Import dataset file (CSV, Excel, JSON)
  Future<bool> importFile(String filepath) async {
    _setLoading(true);
    try {
      final res = await _apiClient.importDataset(filepath);
      if (res['success'] == true) {
        _updateFromSummary(res['data']);
        // Load recommendations automatically
        loadRecommendations();
        return true;
      } else {
        _setError(res['message'] ?? 'Import failed.');
        return false;
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  /// Impute column null values
  Future<void> cleanMissingValues(String column, String method) async {
    _setLoading(true);
    try {
      final res = await _apiClient.imputeMissing(column, method);
      if (res['success'] == true) {
        _updateFromSummary(res['data']);
        loadRecommendations(); // refresh AI recommendations
      } else {
        _setError(res['message'] ?? 'Imputation failed.');
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Remove duplicates
  Future<void> removeDuplicates() async {
    _setLoading(true);
    try {
      final res = await _apiClient.removeDuplicates();
      if (res['success'] == true) {
        _updateFromSummary(res['data']);
        loadRecommendations();
      } else {
        _setError(res['message'] ?? 'Removing duplicates failed.');
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Handle Outliers (drop or cap)
  Future<void> handleOutliers(String column, String method, String action, {double threshold = 3.0}) async {
    _setLoading(true);
    try {
      final res = await _apiClient.handleOutliers(column, method, action, threshold: threshold);
      if (res['success'] == true) {
        _updateFromSummary(res['data']);
        loadRecommendations();
      } else {
        _setError(res['message'] ?? 'Outlier handling failed.');
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Preprocess: Encode categorical columns
  Future<void> encodeColumns(List<String> columns, String method) async {
    _setLoading(true);
    try {
      final res = await _apiClient.encodeColumns(columns, method);
      if (res['success'] == true) {
        _updateFromSummary(res['data']);
        loadRecommendations();
      } else {
        _setError(res['message'] ?? 'Encoding columns failed.');
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Preprocess: Scale numerical columns
  Future<void> scaleColumns(List<String> columns, String method) async {
    _setLoading(true);
    try {
      final res = await _apiClient.scaleColumns(columns, method);
      if (res['success'] == true) {
        _updateFromSummary(res['data']);
        loadRecommendations();
      } else {
        _setError(res['message'] ?? 'Scaling columns failed.');
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Preprocess: Extract datetime parts
  Future<void> extractDatetime(String column) async {
    _setLoading(true);
    try {
      final res = await _apiClient.extractDatetime(column);
      if (res['success'] == true) {
        _updateFromSummary(res['data']);
        loadRecommendations();
      } else {
        _setError(res['message'] ?? 'Extracting datetime failed.');
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Preprocess: TF-IDF Text Vectorization
  Future<void> vectorizeText(String column, int maxFeatures) async {
    _setLoading(true);
    try {
      final res = await _apiClient.vectorizeText(column, maxFeatures);
      if (res['success'] == true) {
        _updateFromSummary(res['data']);
        loadRecommendations();
      } else {
        _setError(res['message'] ?? 'Text vectorization failed.');
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Undo last step
  Future<void> undo() async {
    _setLoading(true);
    try {
      final res = await _apiClient.undo();
      if (res['success'] == true) {
        _updateFromSummary(res['data']);
        loadRecommendations();
      } else {
        _setError(res['message']);
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Redo next step
  Future<void> redo() async {
    _setLoading(true);
    try {
      final res = await _apiClient.redo();
      if (res['success'] == true) {
        _updateFromSummary(res['data']);
        loadRecommendations();
      } else {
        _setError(res['message']);
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Reset to original
  Future<void> reset() async {
    _setLoading(true);
    try {
      final res = await _apiClient.reset();
      if (res['success'] == true) {
        _updateFromSummary(res['data']);
        loadRecommendations();
      } else {
        _setError(res['message']);
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // --- AutoML Training ---

  Future<void> trainAutoML(String targetColumn, {List<String>? featureColumns, double testSize = 0.2}) async {
    state = state.copyWith(isMLTraining: true);
    try {
      final res = await _apiClient.trainAutoML(targetColumn, featureColumns: featureColumns, testSize: testSize);
      if (res['success'] == true) {
        state = state.copyWith(
          automlResults: res['data'],
          isMLTraining: false,
        );
      } else {
        _setError(res['message'] ?? 'AutoML Training failed.');
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // --- AI Recommendations ---

  Future<void> loadRecommendations() async {
    state = state.copyWith(isLoadingRecommendations: true);
    try {
      final res = await _apiClient.getAIRecommendations();
      if (res['success'] == true) {
        state = state.copyWith(
          aiRecommendations: res['data'],
          isLoadingRecommendations: false,
        );
      } else {
        state = state.copyWith(isLoadingRecommendations: false);
      }
    } catch (_) {
      state = state.copyWith(isLoadingRecommendations: false);
    }
  }
}

// Global Provider of Dataset notifier state
final datasetProvider = StateNotifierProvider<DatasetNotifier, DatasetState>((ref) {
  final client = ref.read(apiClientProvider);
  return DatasetNotifier(client);
});
