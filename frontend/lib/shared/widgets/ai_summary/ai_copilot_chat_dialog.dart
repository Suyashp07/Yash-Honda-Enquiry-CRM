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
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: AiCopilotChatDialog(initialBranchId: initialBranchId),
      ),
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
    '📊 Summarize today\'s performance',
    '🏆 Which branch is leading sales?',
    '🛵 Top-selling Honda models today',
    '👥 Sales reps floor status & attendance',
    '💰 Cash vs Finance breakdown',
    '⚠️ Any pending follow-ups or alerts?',
    '🎯 How can we improve conversion today?',
  ];

  @override
  void initState() {
    super.initState();
    _activeBranchId = widget.initialBranchId;
    _initializeGreeting();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initializeGreeting() {
    _messages.add(
      AiCopilotMessage(
        id: 'msg-0',
        role: 'assistant',
        content: '### Welcome to Yash Honda AI Assistant\n\n'
            'Ask a question about your selected branch scope—such as today\'s lead volume, '
            'sales executive availability, finance vs. cash split, or follow-up status.\n\n'
            '*Responses are AI-assisted and grounded in live database metrics.*',
        timestamp: DateTime.now(),
      ),
    );
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
      _initializeGreeting();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 720,
      height: 760,
      constraints: const BoxConstraints(maxHeight: 820),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // 1. Top Header Bar with Executive Branding
            _buildHeader(),

            // 2. Chat Messages Stream Area
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                itemCount: _messages.length + (_isAwaitingResponse ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isAwaitingResponse) {
                    return _buildThinkingBubble();
                  }
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),

            // 3. Quick Suggestions Chips Row
            _buildSuggestionsRow(),

            // 4. Bottom Input Composer
            _buildInputComposer(),
          ],
        ),
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          // AI Robot Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Color(0x44DC2626), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),

          // Title & Live Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Yash Honda Executive Copilot',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.aiSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.aiBorder, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(radius: 3, backgroundColor: AppColors.aiAccent),
                          SizedBox(width: 4),
                          Text(
                            'AI-ASSISTED',
                            style: TextStyle(color: AppColors.aiAccent, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Grounded in live dealership data • Scope: ${_activeBranchId == 'all' ? 'All branches' : _activeBranchId}',
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5),
                ),
              ],
            ),
          ),

          // Clear Chat Button
          IconButton(
            onPressed: _clearChat,
            icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFF94A3B8), size: 20),
            tooltip: 'Clear Conversation',
          ),

          // Close Dialog Button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
            tooltip: 'Close Assistant',
          ),
        ],
      ),
    );
  }

  // --- Message Bubble ---
  Widget _buildMessageBubble(AiCopilotMessage msg) {
    final isUser = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Color(0xFFDC2626), size: 18),
            ),
            const SizedBox(width: 10),
          ],

          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 580),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser ? Colors.transparent : const Color(0xFFE2E8F0),
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
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
    final parts = text.split('**');
    if (parts.length <= 1) {
      return Text(
        text,
        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Color(0xFFDC2626), size: 18),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                ),
                SizedBox(width: 10),
                Text(
                  'Synthesizing Yash Honda live floor intelligence...',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Suggestions Carousel ---
  Widget _buildSuggestionsRow() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _promptSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = _promptSuggestions[index];
          return ActionChip(
            label: Text(
              prompt,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            backgroundColor: const Color(0xFFF8FAFC),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: () => _sendMessage(prompt),
          );
        },
      ),
    );
  }

  // --- Input Composer ---
  Widget _buildInputComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
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
                  hintText: 'Ask about revenue, leads, models, sales reps, or branch performance...',
                  hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 13),
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
