import 'package:flutter/material.dart';
import '../models/gemini_model_config.dart';

class ModelSelectorDialog extends StatefulWidget {
  final GeminiModelConfig currentModel;

  const ModelSelectorDialog({
    super.key,
    required this.currentModel,
  });

  @override
  State<ModelSelectorDialog> createState() => _ModelSelectorDialogState();
}

class _ModelSelectorDialogState extends State<ModelSelectorDialog> {
  late GeminiModelConfig _selectedModel;

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.currentModel;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings_applications),
          SizedBox(width: 8),
          Text('AIモデルを選択'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: GeminiModelConfig.availableModels.length,
          itemBuilder: (context, index) {
            final model = GeminiModelConfig.availableModels[index];
            final isSelected = model == _selectedModel;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: isSelected ? 4 : 1,
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                leading: Radio<GeminiModelConfig>(
                  value: model,
                  groupValue: _selectedModel,
                  onChanged: (GeminiModelConfig? value) {
                    setState(() {
                      _selectedModel = value!;
                    });
                  },
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        model.displayName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (model.isExperimental) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Text(
                          'BETA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(model.description),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (model.supportsFunctionCalling)
                          Chip(
                            label: const Text('Function Calling'),
                            labelStyle: const TextStyle(fontSize: 10),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    _selectedModel = model;
                  });
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedModel),
          child: const Text('選択'),
        ),
      ],
    );
  }
}