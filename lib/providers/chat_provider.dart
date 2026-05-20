import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:datanovaai/services/api_client.dart';

class ChatBubble {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  ChatBubble({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, String> toApiFormat() {
    return {
      'role': role,
      'content': content,
    };
  }
}

class ChatState {
  final List<ChatBubble> messages;
  final bool isLoading;
  final String? errorMessage;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ChatState copyWith({
    List<ChatBubble>? messages,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiClient _apiClient;

  ChatNotifier(this._apiClient) : super(ChatState()) {
    _initializeChat();
  }

  void _initializeChat() {
    state = ChatState(
      messages: [
        ChatBubble(
          role: 'assistant',
          content: 'Hello! I am **DataNova AI Assistant**. 🚀\n\nI can help you inspect column distributions, explain anomalous outliers, suggest the best missing-value handling strategy, or analyze trained AutoML models. \n\nHow can I help you prepare your dataset today?',
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  Future<void> sendMessage(String query) async {
    if (query.trim().isEmpty) return;

    final userBubble = ChatBubble(
      role: 'user',
      content: query,
      timestamp: DateTime.now(),
    );

    // Update list with user query immediately
    final updatedMessages = List<ChatBubble>.from(state.messages)..add(userBubble);
    state = state.copyWith(messages: updatedMessages, isLoading: true);

    try {
      // Build API history
      final apiHistory = state.messages
          .where((msg) => msg.role != 'system') // skip greeting if not needed or include
          .map((msg) => msg.toApiFormat())
          .toList();

      final res = await _apiClient.askAIChat(query, apiHistory);
      
      if (res['success'] == true) {
        final assistantBubble = ChatBubble(
          role: 'assistant',
          content: res['data']['response'] ?? 'I could not generate an answer. Please try again.',
          timestamp: DateTime.now(),
        );

        state = state.copyWith(
          messages: List<ChatBubble>.from(state.messages)..add(assistantBubble),
          isLoading: false,
        );
      } else {
        _setError(res['message'] ?? 'Failed to communicate with AI server.');
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void clearHistory() {
    _initializeChat();
  }

  void _setError(String msg) {
    final errBubble = ChatBubble(
      role: 'assistant',
      content: '⚠️ **Error:** $msg\n\nPlease ensure your local FastAPI backend is active and that your API keys are valid in the **Settings** page.',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: List<ChatBubble>.from(state.messages)..add(errBubble),
      isLoading: false,
    );
  }
}

// Global Provider of AI Chatbot
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final client = ref.read(apiClientProvider);
  return ChatNotifier(client);
});
