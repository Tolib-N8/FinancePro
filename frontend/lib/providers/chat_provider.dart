import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/endpoints.dart';
import '../core/models/chat_message.dart';
import 'api_client_provider.dart';

final chatSessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  final client = await ref.watch(apiClientProvider.future);
  final response = await client.get(Endpoints.chatSessions);
  return (response.data as List).map((e) => ChatSession.fromJson(e)).toList();
});

final chatMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, sessionId) async {
  final client = await ref.watch(apiClientProvider.future);
  final response = await client.get(Endpoints.chatMessages(sessionId));
  return (response.data as List).map((e) => ChatMessage.fromJson(e)).toList();
});
