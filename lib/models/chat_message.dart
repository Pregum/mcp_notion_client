import 'package:flutter/material.dart';

enum ThinkingStep {
  understanding,
  planning,
  executing,
  completed
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isThinking;
  final ThinkingStep? currentStep;
  final List<String>? thinkingSteps;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.isThinking = false,
    this.currentStep,
    this.thinkingSteps,
  });

  const ChatMessage.thinking({
    super.key,
    required this.currentStep,
    required this.thinkingSteps,
  }) : text = '',
       isUser = false,
       isThinking = true;

  @override
  Widget build(BuildContext context) {
    if (isThinking) {
      return _buildThinkingMessage(context);
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isUser
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingMessage(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '思考中...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (thinkingSteps != null && thinkingSteps!.isNotEmpty) ...
                  [
                    const SizedBox(height: 12),
                    for (final entry in thinkingSteps!.asMap().entries)
                      () {
                        final index = entry.key;
                        final step = entry.value;
                        final isCurrentStep = currentStep != null && 
                            index == currentStep!.index;
                        final isCompleted = currentStep != null && 
                            index < currentStep!.index;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                isCompleted 
                                    ? Icons.check_circle
                                    : isCurrentStep
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                size: 16,
                                color: isCompleted
                                    ? Colors.green
                                    : isCurrentStep
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  step,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                    fontStyle: isCurrentStep ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }(),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}