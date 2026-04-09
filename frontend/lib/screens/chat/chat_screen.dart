import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';
import '../../core/api/endpoints.dart';
import '../../core/models/chat_message.dart';
import '../../providers/api_client_provider.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? sessionId;

  const ChatScreen({super.key, this.sessionId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  String? _currentSessionId;
  List<ChatMessage> _messages = [];
  String _streamingText = '';
  bool _streaming = false;

  @override
  void initState() {
    super.initState();
    _currentSessionId = widget.sessionId;
    if (_currentSessionId != null) _loadMessages();
  }

  Future<void> _loadMessages() async {
    if (_currentSessionId == null) return;
    final msgs = await ref.read(chatMessagesProvider(_currentSessionId!).future);
    setState(() => _messages = msgs);
  }

  Future<String> _createSession() async {
    final client = await ref.read(apiClientProvider.future);
    final response = await client.post(Endpoints.chatSessions);
    return response.data['id'] as String;
  }

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    _inputController.clear();

    if (_currentSessionId == null) {
      final id = await _createSession();
      setState(() => _currentSessionId = id);
      ref.invalidate(chatSessionsProvider);
    }

    final userMsg = ChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: _currentSessionId!,
      role: 'user',
      content: content,
      createdAt: DateTime.now().toIso8601String(),
    );

    setState(() {
      _messages = [..._messages, userMsg];
      _streaming = true;
      _streamingText = '';
    });

    _scrollToBottom();

    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString(AppConstants.prefKeyApiBaseUrl) ?? AppConstants.defaultApiBaseUrl;
      final apiKey = prefs.getString(AppConstants.prefKeyApiKey) ?? '';

      final url = Uri.parse('$baseUrl${Endpoints.sendChatMessage(_currentSessionId!)}');
      final httpClient = HttpClient();
      final request = await httpClient.postUrl(url);
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'text/event-stream');
      request.add(utf8.encode(jsonEncode({'content': content})));

      final response = await request.close();
      final stream = response.transform(utf8.decoder);

      await for (final chunk in stream) {
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') {
              final assistantMsg = ChatMessage(
                id: 'temp_ai_${DateTime.now().millisecondsSinceEpoch}',
                sessionId: _currentSessionId!,
                role: 'assistant',
                content: _streamingText,
                createdAt: DateTime.now().toIso8601String(),
              );
              setState(() {
                _messages = [..._messages, assistantMsg];
                _streamingText = '';
                _streaming = false;
              });
              await _loadMessages();
              ref.invalidate(chatSessionsProvider);
              httpClient.close();
              return;
            }
            try {
              final decoded = jsonDecode(data);
              if (decoded['text'] != null) {
                setState(() => _streamingText += decoded['text'] as String);
                _scrollToBottom();
              } else if (decoded['error'] != null) {
                throw Exception(decoded['error']);
              }
            } catch (_) {}
          }
        }
      }
      httpClient.close();
    } catch (e) {
      setState(() {
        _streaming = false;
        _streamingText = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(chatSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New chat',
            onPressed: () => setState(() {
              _currentSessionId = null;
              _messages = [];
              _streamingText = '';
            }),
          ),
        ],
      ),
      body: Row(
        children: [
          // Sessions sidebar (desktop)
          if (MediaQuery.of(context).size.width >= 800) ...[
            SizedBox(
              width: 240,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: FilledButton.icon(
                      onPressed: () => setState(() {
                        _currentSessionId = null;
                        _messages = [];
                      }),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Chat'),
                    ),
                  ),
                  Expanded(
                    child: sessionsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox(),
                      data: (sessions) => ListView.builder(
                        itemCount: sessions.length,
                        itemBuilder: (context, i) => ListTile(
                          dense: true,
                          selected: sessions[i].id == _currentSessionId,
                          title: Text(
                            sessions[i].title ?? 'Chat ${i + 1}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () {
                            setState(() => _currentSessionId = sessions[i].id);
                            _loadMessages();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
          ],

          // Chat area
          Expanded(
            child: Column(
              children: [
                // Suggested prompts
                if (_messages.isEmpty && !_streaming)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'This month summary',
                        'Largest expenses',
                        'Compare to last month',
                        'How much did I spend on food?',
                      ].map((prompt) => ActionChip(
                        label: Text(prompt, style: const TextStyle(fontSize: 12)),
                        onPressed: () => _sendMessage(prompt),
                      )).toList(),
                    ),
                  ),

                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_streaming ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _messages.length && _streaming) {
                        return _MessageBubble(
                          role: 'assistant',
                          content: _streamingText.isEmpty ? '...' : _streamingText,
                          isStreaming: true,
                        );
                      }
                      final msg = _messages[i];
                      return _MessageBubble(role: msg.role, content: msg.content);
                    },
                  ),
                ),

                // Input
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          decoration: const InputDecoration(
                            hintText: 'Ask about your finances...',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          minLines: 1,
                          onSubmitted: _streaming ? null : _sendMessage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: _streaming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send),
                        onPressed: _streaming
                            ? null
                            : () => _sendMessage(_inputController.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String role;
  final String content;
  final bool isStreaming;

  const _MessageBubble({required this.role, required this.content, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.auto_awesome, size: 14),
              ),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      content,
                      style: TextStyle(
                        color: isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isStreaming)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
