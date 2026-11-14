import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../booking/providers/booking_provider.dart';

class DriverChatSheet extends ConsumerStatefulWidget {
  final String driverName;

  const DriverChatSheet({super.key, required this.driverName});

  @override
  ConsumerState<DriverChatSheet> createState() => _DriverChatSheetState();
}

class _DriverChatSheetState extends ConsumerState<DriverChatSheet> {
  final _textController = TextEditingController();

  final List<String> _quickResponses = [
    'I am waiting by the main entrance',
    'Patient is conscious and breathing',
    'Apartment gate is open',
    'Please bring a wheelchair / stretcher',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.driverName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.primaryRed,
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.fiber_manual_record, color: AppColors.success, size: 10),
                        SizedBox(width: 4),
                        Text('Driver Online • In Transit', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 24),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              itemCount: bookingState.chatMessages.length,
              itemBuilder: (context, index) {
                final rawMsg = bookingState.chatMessages[index];
                final isDriver = index < 2 || rawMsg.startsWith('__driver__:');
                final msg = rawMsg.startsWith('__driver__:')
                    ? rawMsg.substring('__driver__:'.length)
                    : rawMsg;

                return Align(
                  alignment: isDriver ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isDriver ? AppColors.surfaceVariant : AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg,
                      style: TextStyle(
                        color: isDriver ? AppColors.textPrimary : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Quick Replies
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickResponses.map((qr) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                  child: ActionChip(
                    label: Text(qr, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.surfaceVariant,
                    onPressed: () {
                      ref.read(bookingProvider.notifier).addChatMessage(qr);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Input Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'Type emergency message...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (val) {
                    final t = val.trim();
                    if (t.isNotEmpty) {
                      ref.read(bookingProvider.notifier).addChatMessage(t);
                      _textController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: () {
                    final text = _textController.text.trim();
                    if (text.isNotEmpty) {
                      ref.read(bookingProvider.notifier).addChatMessage(text);
                      _textController.clear();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
