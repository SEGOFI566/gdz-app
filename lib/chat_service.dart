import 'dart:convert';

import 'package:http/http.dart' as http;

/// Клиент для чата с ассистентом через внешний прокси.
///
/// URL задаётся при сборке:
/// `--dart-define=CHAT_API_URL=https://your-proxy.example.com/chat`
///
/// Контракт прокси:
///   POST JSON: {"messages":[{"role":"user","content":"..."}, ...]}
///   Ответ JSON: {"reply":"..."}
/// Также поддерживается OpenAI-совместимый ответ choices[0].message.content.
class ChatService {
  ChatService({http.Client? client, String? apiUrl})
      : _client = client ?? http.Client(),
        _apiUrl = apiUrl ??
            const String.fromEnvironment('CHAT_API_URL', defaultValue: '');

  final http.Client _client;
  final String _apiUrl;

  bool get isConfigured => _apiUrl.trim().isNotEmpty;

  String get apiUrl => _apiUrl;

  Future<String> send(List<ChatMessage> messages) async {
    if (!isConfigured) {
      throw const ChatException(
        'Чат не настроен: при сборке не указан CHAT_API_URL.',
      );
    }

    final uri = Uri.parse(_apiUrl);
    final body = jsonEncode({
      'messages': [
        for (final m in messages) {'role': m.role, 'content': m.content},
      ],
    });

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      throw ChatException('Не удалось связаться с помощником: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatException(
        'Помощник вернул ошибку (${response.statusCode}). Попробуй позже.',
      );
    }

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const ChatException('Помощник вернул некорректный ответ.');
    }

    final reply = _extractReply(data);
    if (reply == null || reply.trim().isEmpty) {
      throw const ChatException('Помощник вернул пустой ответ.');
    }
    return reply.trim();
  }

  String? _extractReply(dynamic data) {
    if (data is! Map) return null;
    final direct = data['reply'];
    if (direct is String && direct.trim().isNotEmpty) return direct;

    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final message = first['message'];
        if (message is Map) {
          final content = message['content'];
          if (content is String) return content;
        }
        final text = first['text'];
        if (text is String) return text;
      }
    }
    return null;
  }

  void dispose() {
    _client.close();
  }
}

class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final String role; // 'system' | 'user' | 'assistant'
  final String content;
}

class ChatException implements Exception {
  const ChatException(this.message);
  final String message;

  @override
  String toString() => message;
}
