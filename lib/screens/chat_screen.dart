import 'package:flutter/material.dart';

import '../chat_service.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.service});

  final ChatService? service;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatService _service;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  final List<ChatMessage> _messages = [
    const ChatMessage(
      role: 'assistant',
      content:
          'Привет! Я Big Pickle — помощник по ГДЗ. Спрашивай про учебники, '
          'задания или предметы, и я постараюсь помочь.',
    ),
  ];

  bool _sending = false;

  static const ChatMessage _systemPrompt = ChatMessage(
    role: 'system',
    content:
        'Ты Big Pickle — дружелюбный помощник на сайте ГДЗ. Отвечай по-русски, '
        'кратко и по делу. Помогай пользователям находить учебники, понимать '
        'задания и разбираться в школьных темах. Если не уверен в ответе, '
        'честно скажи об этом и не выдумывай факты.',
  );

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ChatService();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _sending = true;
    });
    _scrollToEnd();

    try {
      final reply = await _service.send([
        _systemPrompt,
        ..._messages.where((m) => m.role == 'user' || m.role == 'assistant'),
      ]);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: reply));
      });
    } on ChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: e.message));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(role: 'assistant', content: 'Ошибка: $e'),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSend = !_sending;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: kAccent),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Big Pickle',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: kInk,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Помощник, который отвечает на вопросы',
                        style: TextStyle(fontSize: 13, color: kMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!_service.isConfigured)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Text(
                  'Чат ещё не подключён. Соберите web с параметром '
                  '--dart-define=CHAT_API_URL=https://ваш-прокси/chat '
                  'и разверните прокси с API-ключом.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A3412),
                    height: 1.35,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (_sending && index == _messages.length) {
                  return const _TypingBubble();
                }
                final msg = _messages[index];
                return _ChatBubble(message: msg);
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              12 + MediaQuery.of(context).viewInsets.bottom * 0.0 +
                  MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEAE7F2))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Задай вопрос...',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  width: 48,
                  child: FilledButton(
                    onPressed: canSend ? _send : null,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: kAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final bg = isUser ? kAccent : Colors.white;
    final fg = isUser ? Colors.white : kInk;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 6),
      bottomRight: Radius.circular(isUser ? 6 : 18),
    );

    return Align(
      alignment: align,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: isUser ? null : Border.all(color: const Color(0xFFEAE7F2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SelectableText(
          message.content,
          style: TextStyle(fontSize: 14, height: 1.45, color: fg),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4, right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAE7F2)),
        ),
        child: const Text(
          'Big Pickle печатает...',
          style: TextStyle(fontSize: 13, color: kMuted),
        ),
      ),
    );
  }
}
