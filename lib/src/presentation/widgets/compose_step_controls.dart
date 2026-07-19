import 'package:flutter/material.dart';

class ComposeStepHeader extends StatelessWidget {
  const ComposeStepHeader({
    super.key,
    required this.titles,
    required this.currentStep,
  });

  final List<String> titles;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    final progress = (currentStep + 1) / titles.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titles[currentStep], style: titleStyle),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            key: const Key('compose-step-progress'),
            value: progress,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < titles.length; index += 1)
              Expanded(
                child: Text(
                  '${index + 1}. ${titles[index]}',
                  textAlign: index == 0
                      ? TextAlign.left
                      : index == titles.length - 1
                      ? TextAlign.right
                      : TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: index <= currentStep
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: index == currentStep
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class ComposeStepNavigation extends StatelessWidget {
  const ComposeStepNavigation({
    super.key,
    required this.currentStep,
    required this.stepCount,
    required this.canSubmit,
    required this.saving,
    required this.submitLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
  });

  final int currentStep;
  final int stepCount;
  final bool canSubmit;
  final bool saving;
  final String submitLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  bool get _isLastStep => currentStep == stepCount - 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (currentStep > 0) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canSubmit ? onPrevious : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('이전'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: currentStep > 0 ? 1 : 2,
            child: FilledButton.icon(
              onPressed: canSubmit ? (_isLastStep ? onSubmit : onNext) : null,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isLastStep ? Icons.check : Icons.chevron_right),
              label: Text(
                saving ? '등록 중...' : (_isLastStep ? submitLabel : '다음'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
