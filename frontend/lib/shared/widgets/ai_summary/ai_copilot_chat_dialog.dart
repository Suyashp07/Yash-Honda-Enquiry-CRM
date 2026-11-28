import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/networking/api_client.dart';

class AiCopilotMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metrics;

  AiCopilotMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.metrics,
  });
}

class AiCopilotChatDialog extends ConsumerStatefulWidget {
  final String initialBranchId;

  const AiCopilotChatDialog({
    super.key,
    this.initialBranchId = 'all',
  });

  static void show(BuildContext context, {String initialBranchId = 'all'}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Copilot',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        final screenW = MediaQuery.of(ctx).size.width;
        final drawerW = screenW < 560 ? screenW : 460.0;
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: drawerW,
              height: double.infinity,
              child: AiCopilotChatDialog(initialBranchId: initialBranchId),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  ConsumerState<AiCopilotChatDialog> createState() => _AiCopilotChatDialogState();
}

class _AiCopilotChatDialogState extends ConsumerState<AiCopilotChatDialog> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  final List<AiCopilotMessage> _messages = [];
  bool _isAwaitingResponse = false;
  CancelToken? _activeCancelToken;
  late String _activeBranchId;

  final List<String> _promptSuggestions = [
    'Today\'s summary',
    'Branch comparison',
    'Top models',
    'Pending follow-ups',
  ];

  @override
  void initState() {
    super.initState();
    _activeBranchId = widget.initialBranchId;
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _cancelInFlightRequest() {
    _activeCancelToken?.cancel('Cancelled by user');
    _activeCancelToken = null;
    if (mounted) {
      setState(() => _isAwaitingResponse = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isAwaitingResponse) return;

    _textController.clear();

    final userMsg = AiCopilotMessage(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: query,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isAwaitingResponse = true;
    });

    _scrollToBottom();

    _activeCancelToken = CancelToken();
    try {
      final dio = ref.read(dioProvider);

      // Prepare bounded conversation history (last 10 messages)
      final nonGreeting = _messages
          .where((m) => m.id != userMsg.id && m.id != 'msg-0')
          .toList();
      final bounded = nonGreeting.length > 10
          ? nonGreeting.sublist(nonGreeting.length - 10)
          : nonGreeting;
      final history = bounded
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final res = await dio.post(
        '/ai-insights/chat',
        data: {
          'query': query,
          'branch': _activeBranchId,
          'range': 'today',
          'history': history,
        },
        cancelToken: _activeCancelToken,
      );

      final reply = res.data?['reply']?.toString() ??
          'Analysis complete for the selected branch scope.';
      final metrics = res.data?['metrics'] is Map<String, dynamic>
          ? res.data['metrics'] as Map<String, dynamic>
          : null;

      if (!mounted) return;
      setState(() {
        _messages.add(AiCopilotMessage(
          id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          content: reply,
          timestamp: DateTime.now(),
          metrics: metrics,
        ));
        _isAwaitingResponse = false;
        _activeCancelToken = null;
      });
    } catch (e) {
      if (!mounted) return;
      final cancelled = e is DioException && CancelToken.isCancel(e);
      setState(() {
        _messages.add(AiCopilotMessage(
          id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          content: cancelled
              ? 'Request cancelled.'
              : 'Could not reach the AI Assistant right now. Check your connection and try again.',
          timestamp: DateTime.now(),
        ));
        _isAwaitingResponse = false;
        _activeCancelToken = null;
      });
    }

    _scrollToBottom();
    _focusNode.requestFocus();
  }

  String _generateLocalFallback(String query) {
    final q = query.toLowerCase();
    if (q.contains('summary') || q.contains('performance') || q.contains('overview') || q.contains('today')) {
      return '### 📊 Yash Honda Executive Summary (Live Floor)\n'
          'Across all 6 Pune showrooms (**Phursungi BigWing, Wadki, Saswad, Uruli Kanchan, BT Kawade, Sasane Nagar**):\n\n'
          '* **Total Leads Logged**: **30 Customer Interactions** (22 physical walk-ins, 8 telephonic calls)\n'
          '* **Bookings Achieved**: **7 units booked** with a **23.33% lead conversion rate**\n'
          '* **Active Floor Engagement**: **9 sales executives** are actively consulting live walk-in guests right now\n'
          '* **Commercial Split**: **36.67% Finance purchases** (11 deals) vs Cash deals (19 deals)\n\n'
          '💡 **Owner Recommendation**: Showroom walk-in volume is strong. Encourage managers to follow up on the 14 open quotations before evening showroom closing.';
    }
    if (q.contains('branch') || q.contains('phursungi') || q.contains('kawade') || q.contains('saswad')) {
      return '### 🏢 Branch-wise Operational Breakdown\n\n'
          '* **Phursungi BigWing**: Highest average deal value (~₹2.30L), driven by **CB350 and CB300F** interest.\n'
          '* **BT Kawade (RedWing)**: Top volume location for **Activa 110 & 125**, conversion holding steady at 25%.\n'
          '* **Saswad (RedWing)**: Top efficiency branch with rural commuter motorcycle bookings (**Shine 100**, **SP 125**).\n'
          '* **Wadki, Uruli Kanchan, Sasane Nagar**: Stable footfalls with inquiries scheduled for weekend deliveries.';
    }
    if (q.contains('model') || q.contains('bike') || q.contains('activa') || q.contains('shine') || q.contains('sp 125')) {
      return '### 🛵 Top-Selling Honda Two-Wheelers Today\n\n'
          '1. **Honda Activa 110 (DLX & Premium)**: Leads volume with **42% of customer enquiries**.\n'
          '2. **Honda SP 125 (Disc/Drum)**: **28% of customer interest**, top choice among commuters.\n'
          '3. **Honda Shine 100**: Consistent demand in rural sub-dealerships for entry affordability.\n'
          '4. **Honda BigWing CB350**: Leading in premium booking advances at Phursungi.';
    }
    if (q.contains('rep') || q.contains('staff') || q.contains('attendance') || q.contains('busy') || q.contains('idle')) {
      return '### 👥 Sales Floor Attendance & Activity\n\n'
          '* **Total Sales Executives On Floor**: **20 Representatives**\n'
          '* **Currently Busy with Customers**: **9 Reps** (*Aditya Deshmukh, Ajay Shinde, Deepak Mane, etc.*)\n'
          '* **Currently Available / Idle**: **11 Reps** (*Akshay Phadtare, Amol Wagh, Ganesh Sawant, etc.*)\n\n'
          '⚡ **Action Item**: Assign the 11 available reps to perform telephone callbacks on warm inquiries from yesterday.';
    }
    return '### 🤖 Yash Honda Intelligence Assistant\n\n'
        'Regarding your question on **"$query"**:\n\n'
        'Today across our 6 Pune dealerships, we have recorded **30 total customer leads**, **7 confirmed bookings**, '
        'and **₹8.49L in estimated vehicle value**. **9 sales executives** are actively consulting customers on the showroom floor.\n\n'
        'You can ask me to compare branches, review top-selling models, or examine sales rep performance!';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.of(context).size.width < 560;
    final radius = isPhone
        ? BorderRadius.zero
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: radius,
        border: isPhone
            ? null
            : const Border(left: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 28,
            offset: Offset(-6, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SafeArea(
          left: false,
          child: Column(
            children: [
              // 1. Clean CRM Header Bar
              _buildHeader(),

              // 2. Empty State or Chat Messages Stream
              Expanded(
                child: _messages.isEmpty && !_isAwaitingResponse
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        itemCount: _messages.length + (_isAwaitingResponse ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isAwaitingResponse) {
                            return _buildThinkingBubble();
                          }
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
              ),

              // 3. Bottom Input Composer
              _buildInputComposer(),
            ],
          ),
        ),
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Title & Live Scope
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Yash Honda Assistant',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const CircleAvatar(
                        radius: 3.5, backgroundColor: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Text(
                      _activeBranchId == 'all'
                          ? 'All branches'
                          : 'Branch scoped',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Clear Chat Button
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _clearChat,
              icon: const Icon(Icons.refresh_rounded,
                  color: Color(0xFF64748B), size: 20),
              tooltip: 'New Conversation',
            ),

          // Close Drawer Button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFF64748B), size: 22),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text(
            'How can I help?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _promptSuggestions.map((prompt) {
              return InkWell(
                onTap: () => _sendMessage(prompt),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    prompt,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- Message Bubble ---
  Widget _buildMessageBubble(AiCopilotMessage msg) {
    final isUser = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: isUser ? 340 : double.infinity),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
                border: Border.all(
                  color: isUser ? Colors.transparent : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Structured Key Metrics Chips (if attached)
                  if (!isUser && msg.metrics != null && msg.metrics!.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: msg.metrics!.entries.map((entry) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${entry.key}: ',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                              Text(
                                entry.value.toString(),
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),
                  ],

                  // Formatted Message Text
                  _renderFormattedText(msg.content, isUser),

                  const SizedBox(height: 8),

                  // Bottom Timestamp & Copy Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('hh:mm a').format(msg.timestamp),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isUser ? const Color(0xFF94A3B8) : const Color(0xFFA1A1AA),
                        ),
                      ),
                      if (!isUser)
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: msg.content));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied insight to clipboard!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                                SizedBox(width: 4),
                                Text('Copy', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Rich Text Renderer for Markdown Headings and Bullets ---
  Widget _renderFormattedText(String content, bool isUser) {
    if (isUser) {
      return Text(
        content,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      );
    }

    final lines = content.split('\n');
    final List<Widget> widgets = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      if (trimmed.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            trimmed.substring(4),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ));
      } else if (trimmed.startsWith('* ') || trimmed.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
              Expanded(
                child: _buildInlineRichText(trimmed.substring(2)),
              ),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildInlineRichText(trimmed),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildInlineRichText(String text) {
    final cleaned = text.replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');
    final parts = cleaned.split('**');
    if (parts.length <= 1) {
      return Text(
        cleaned,
        style: const TextStyle(
            fontSize: 13, color: Color(0xFF334155), height: 1.45),
      );
    }

    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      final isBold = i % 2 == 1;
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          color: isBold ? const Color(0xFF0F172A) : const Color(0xFF334155),
        ),
      ));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.45),
        children: spans,
      ),
    );
  }

  // --- Thinking indicator bubble ---
  Widget _buildThinkingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFFDC2626)),
            ),
            SizedBox(width: 10),
            Text(
              'Checking live data...',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  // --- Input Composer ---
  Widget _buildInputComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Ask about branches, leads, models, reps...',
                  hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send Action Button
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0x33DC2626), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              onPressed: () => _sendMessage(_textController.text),
              tooltip: 'Send query to AI Copilot',
            ),
          ),
        ],
      ),
    );
  }
}
