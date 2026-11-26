import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/utils/date_formatter.dart';

class AiSummaryCard extends ConsumerStatefulWidget {
  final String branchCode;
  final String range;

  const AiSummaryCard({
    super.key,
    this.branchCode = 'all',
    this.range = 'today',
  });

  @override
  ConsumerState<AiSummaryCard> createState() => _AiSummaryCardState();
}

class _AiSummaryCardState extends ConsumerState<AiSummaryCard> {
  String? _summaryText;
  DateTime? _generatedAt;
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _fetchSummary(forceRefresh: false);
  }

  @override
  void didUpdateWidget(covariant AiSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchCode != widget.branchCode || oldWidget.range != widget.range) {
      _fetchSummary(forceRefresh: false);
    }
  }

  Future<void> _fetchSummary({bool forceRefresh = false}) async {
    setState(() {
      if (forceRefresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/ai-insights/summary', queryParameters: {
        'branch': widget.branchCode,
        'range': widget.range,
        'forceRefresh': forceRefresh ? 'true' : 'false',
      });

      final data = response.data;
      setState(() {
        _summaryText = data['summaryText'];
        _generatedAt = DateTime.tryParse(data['generatedAt'] ?? '');
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 80,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
              SizedBox(width: 12),
              Text(
                'Generating AI executive briefing...',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_summaryText == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.aiSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.aiBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.aiAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.auto_awesome_outlined, size: 16, color: AppColors.aiAccent),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'AI-Assisted Executive Briefing',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.aiAccent,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_generatedAt != null)
                    Text(
                      'Updated ${DateFormatter.timeAgo(_generatedAt)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _isRefreshing ? null : () => _fetchSummary(forceRefresh: true),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: _isRefreshing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEA580C)),
                            )
                          : const Icon(Icons.refresh, size: 16, color: Color(0xFFEA580C)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _summaryText!,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF431407),
            ),
          ),
        ],
      ),
    );
  }
}
