import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiClient {
  static const String defaultBaseUrl = 'http://127.0.0.1:8000/api';
  String baseUrl = defaultBaseUrl;

  Future<String> _getGeminiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gemini_key') ?? '';
  }

  Future<String> _getOpenAIKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('openai_key') ?? '';
  }

  Future<Map<String, String>> _getHeaders() async {
    final geminiKey = await _getGeminiKey();
    final openaiKey = await _getOpenAIKey();
    return {
      'Content-Type': 'application/json',
      'X-Gemini-Key': geminiKey,
      'X-OpenAI-Key': openaiKey,
    };
  }

  /// Checks if the local backend server is up and responsive
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(Uri.parse(baseUrl.replaceFirst('/api', ''))).timeout(
        const Duration(seconds: 3),
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

  /// Imports a dataset file (CSV, Excel, JSON) using multipart upload
  Future<Map<String, dynamic>> importDataset(String filepath) async {
    final uri = Uri.parse('$baseUrl/import');
    final request = http.MultipartRequest('POST', uri);
    
    request.files.add(
      await http.MultipartFile.fromPath('file', filepath),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    return _handleResponse(response);
  }

  /// Fetch active dataset preview and statistics
  Future<Map<String, dynamic>> getPreview() async {
    final uri = Uri.parse('$baseUrl/preview');
    final headers = await _getHeaders();
    final response = await http.get(uri, headers: headers);
    return _handleResponse(response);
  }

  /// Impute missing values in a column
  Future<Map<String, dynamic>> imputeMissing(String column, String method) async {
    final uri = Uri.parse('$baseUrl/clean/missing');
    final headers = await _getHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'column': column, 'method': method}),
    );
    return _handleResponse(response);
  }

  /// Remove all duplicate rows
  Future<Map<String, dynamic>> removeDuplicates() async {
    final uri = Uri.parse('$baseUrl/clean/duplicates');
    final headers = await _getHeaders();
    final response = await http.post(uri, headers: headers);
    return _handleResponse(response);
  }

  /// Detect or remove outliers
  Future<Map<String, dynamic>> handleOutliers(String column, String method, String action, {double threshold = 3.0}) async {
    final uri = Uri.parse('$baseUrl/clean/outliers');
    final headers = await _getHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'column': column,
        'method': method,
        'action': action,
        'threshold': threshold
      }),
    );
    return _handleResponse(response);
  }

  /// Encode categorical variables
  Future<Map<String, dynamic>> encodeColumns(List<String> columns, String method) async {
    final uri = Uri.parse('$baseUrl/preprocess/encode');
    final headers = await _getHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'columns': columns, 'method': method}),
    );
    return _handleResponse(response);
  }

  /// Scale numerical features (normalize or standardize)
  Future<Map<String, dynamic>> scaleColumns(List<String> columns, String method) async {
    final uri = Uri.parse('$baseUrl/preprocess/scale');
    final headers = await _getHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'columns': columns, 'method': method}),
    );
    return _handleResponse(response);
  }

  /// Extract components from datetime columns
  Future<Map<String, dynamic>> extractDatetime(String column) async {
    final uri = Uri.parse('$baseUrl/preprocess/datetime');
    final headers = await _getHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'column': column}),
    );
    return _handleResponse(response);
  }

  /// TF-IDF text vectorization
  Future<Map<String, dynamic>> vectorizeText(String column, int maxFeatures) async {
    final uri = Uri.parse('$baseUrl/preprocess/vectorize');
    final headers = await _getHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'column': column, 'max_features': maxFeatures}),
    );
    return _handleResponse(response);
  }

  /// History stack traversals
  Future<Map<String, dynamic>> undo() async {
    final uri = Uri.parse('$baseUrl/undo');
    final headers = await _getHeaders();
    final response = await http.post(uri, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> redo() async {
    final uri = Uri.parse('$baseUrl/redo');
    final headers = await _getHeaders();
    final response = await http.post(uri, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> reset() async {
    final uri = Uri.parse('$baseUrl/reset');
    final headers = await _getHeaders();
    final response = await http.post(uri, headers: headers);
    return _handleResponse(response);
  }

  // --- AutoML API ---

  Future<Map<String, dynamic>> trainAutoML(String targetColumn, {List<String>? featureColumns, double testSize = 0.2}) async {
    final uri = Uri.parse('$baseUrl/automl/train');
    final headers = await _getHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'target_column': targetColumn,
        'feature_columns': featureColumns,
        'test_size': testSize
      }),
    );
    return _handleResponse(response);
  }

  // --- AI API ---

  Future<Map<String, dynamic>> getAIRecommendations() async {
    final uri = Uri.parse('$baseUrl/ai/recommend');
    final headers = await _getHeaders();
    final response = await http.get(uri, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> askAIChat(String query, List<Map<String, String>> history) async {
    final uri = Uri.parse('$baseUrl/ai/chat');
    final headers = await _getHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'query': query,
        'history': history,
      }),
    );
    return _handleResponse(response);
  }

  // --- File downloads helpers ---

  String getModelExportUrl(String modelName) {
    return '$baseUrl/automl/export?model_name=${Uri.encodeComponent(modelName)}';
  }

  String getDatasetExportUrl(String format) {
    return '$baseUrl/export/dataset?format=$format';
  }

  String getPDFReportUrl() {
    return '$baseUrl/export/report';
  }

  // --- Utility Response Handler ---
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = response.body;
      return jsonDecode(body);
    } else {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['detail'] ?? 'An API error occurred.');
    }
  }
}

// Global static instance provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
