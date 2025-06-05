import 'package:flutter/material.dart';
import 'package:mcp_client/mcp_client.dart' as mcp_client;
import '../services/mcp_client_manager.dart';

class ToolExecutionPanel extends StatefulWidget {
  final McpClientManager mcpManager;
  final Function(String)? onResultUpdate;

  const ToolExecutionPanel({
    super.key,
    required this.mcpManager,
    this.onResultUpdate,
  });

  @override
  State<ToolExecutionPanel> createState() => _ToolExecutionPanelState();
}

class _ToolExecutionPanelState extends State<ToolExecutionPanel> {
  List<ToolInfo> _availableTools = [];
  ToolInfo? _selectedTool;
  final Map<String, dynamic> _parameters = {};
  bool _isLoading = false;
  bool _isExecuting = false;
  String? _lastResult;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAvailableTools();
  }

  Future<void> _loadAvailableTools() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allTools = <ToolInfo>[];
      
      for (final clientInfo in widget.mcpManager.connectedClients) {
        try {
          final tools = await clientInfo.client.listTools();
          for (final tool in tools) {
            allTools.add(ToolInfo(
              name: tool.name,
              description: tool.description,
              inputSchema: tool.inputSchema,
              serverName: clientInfo.name,
              client: clientInfo.client,
            ));
          }
        } catch (e) {
          debugPrint('Failed to get tools from ${clientInfo.name}: $e');
        }
      }

      setState(() {
        _availableTools = allTools;
        _isLoading = false;
        if (_selectedTool != null) {
          // 選択されたツールが更新されているかチェック
          final updatedTool = allTools.firstWhere(
            (tool) => tool.name == _selectedTool!.name && tool.serverName == _selectedTool!.serverName,
            orElse: () => allTools.isNotEmpty ? allTools.first : _selectedTool!,
          );
          _selectedTool = updatedTool;
          _generateParameterFields();
        }
      });
    } catch (e) {
      setState(() {
        _error = 'ツールリストの取得中にエラーが発生しました: $e';
        _isLoading = false;
      });
    }
  }

  void _generateParameterFields() {
    if (_selectedTool == null) return;
    
    final schema = _selectedTool!.inputSchema;
    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    
    // 既存のパラメータをクリアして新しいスキーマに合わせて初期化
    _parameters.clear();
    properties.forEach((key, value) {
      final type = value['type'] as String? ?? 'string';
      switch (type) {
        case 'string':
          _parameters[key] = '';
          break;
        case 'number':
        case 'integer':
          _parameters[key] = '';
          break;
        case 'boolean':
          _parameters[key] = false;
          break;
        case 'array':
          _parameters[key] = [];
          break;
        case 'object':
          _parameters[key] = {};
          break;
        default:
          _parameters[key] = '';
      }
    });
  }

  Future<void> _executeTool() async {
    if (_selectedTool == null) return;

    setState(() {
      _isExecuting = true;
      _error = null;
      _lastResult = null;
    });

    try {
      // パラメータの値を適切な型に変換
      final processedParams = <String, dynamic>{};
      _parameters.forEach((key, value) {
        if (value is String && value.isEmpty) {
          // 空文字の場合はnullまたはデフォルト値を設定
          final schema = _selectedTool!.inputSchema;
          final properties = schema['properties'] as Map<String, dynamic>? ?? {};
          final fieldSchema = properties[key] as Map<String, dynamic>? ?? {};
          final type = fieldSchema['type'] as String? ?? 'string';
          
          switch (type) {
            case 'number':
            case 'integer':
              processedParams[key] = null;
              break;
            case 'boolean':
              processedParams[key] = false;
              break;
            case 'array':
              processedParams[key] = [];
              break;
            case 'object':
              processedParams[key] = {};
              break;
            default:
              processedParams[key] = value;
          }
        } else if (value is String) {
          // 数値型の場合は変換を試行
          final schema = _selectedTool!.inputSchema;
          final properties = schema['properties'] as Map<String, dynamic>? ?? {};
          final fieldSchema = properties[key] as Map<String, dynamic>? ?? {};
          final type = fieldSchema['type'] as String? ?? 'string';
          
          if (type == 'number') {
            final numValue = double.tryParse(value);
            processedParams[key] = numValue ?? 0.0;
          } else if (type == 'integer') {
            final intValue = int.tryParse(value);
            processedParams[key] = intValue ?? 0;
          } else {
            processedParams[key] = value;
          }
        } else {
          processedParams[key] = value;
        }
      });

      debugPrint('Executing tool: ${_selectedTool!.name}');
      debugPrint('Parameters: $processedParams');

      final result = await _selectedTool!.client.callTool(
        _selectedTool!.name,
        processedParams,
      );

      final resultText = result.content
          .map((content) => content.toJson())
          .map((json) => json['text'] ?? json.toString())
          .join('\n');

      setState(() {
        _lastResult = resultText;
        _isExecuting = false;
      });

      widget.onResultUpdate?.call(resultText);
    } catch (e) {
      setState(() {
        _error = 'ツールの実行中にエラーが発生しました: $e';
        _isExecuting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_applications_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'ツール直接実行',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadAvailableTools,
                  tooltip: 'ツールリストを更新',
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              // ツール選択
              _buildToolSelector(),
              
              if (_selectedTool != null) ...[
                const SizedBox(height: 20),
                _buildParameterInputs(),
                const SizedBox(height: 20),
                _buildExecuteButton(),
              ],
              
              if (_lastResult != null || _error != null) ...[
                const SizedBox(height: 20),
                _buildResultDisplay(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToolSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ツール選択',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<ToolInfo>(
          value: _selectedTool,
          decoration: InputDecoration(
            hintText: 'ツールを選択してください',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.build_rounded),
          ),
          items: _availableTools.map((tool) {
            return DropdownMenuItem<ToolInfo>(
              value: tool,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tool.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${tool.serverName} • ${tool.description}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (ToolInfo? newTool) {
            setState(() {
              _selectedTool = newTool;
              _generateParameterFields();
              _lastResult = null;
              _error = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildParameterInputs() {
    if (_selectedTool == null) return const SizedBox.shrink();
    
    final schema = _selectedTool!.inputSchema;
    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    
    if (properties.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text('このツールにはパラメータは必要ありません'),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'パラメータ設定',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...properties.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildParameterField(entry.key, entry.value),
          );
        }),
      ],
    );
  }

  Widget _buildParameterField(String paramName, Map<String, dynamic> fieldSchema) {
    final type = fieldSchema['type'] as String? ?? 'string';
    final description = fieldSchema['description'] as String? ?? '';
    final isRequired = fieldSchema['required'] as bool? ?? false;
    
    switch (type) {
      case 'boolean':
        return SwitchListTile(
          title: Text(paramName),
          subtitle: description.isNotEmpty ? Text(description) : null,
          value: _parameters[paramName] as bool? ?? false,
          onChanged: (bool value) {
            setState(() {
              _parameters[paramName] = value;
            });
          },
        );
        
      case 'number':
      case 'integer':
        return TextFormField(
          decoration: InputDecoration(
            labelText: paramName,
            hintText: description.isNotEmpty ? description : 'Enter $type',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: isRequired ? const Icon(Icons.star, size: 16, color: Colors.red) : null,
          ),
          keyboardType: TextInputType.number,
          onChanged: (String value) {
            setState(() {
              _parameters[paramName] = value;
            });
          },
        );
        
      default: // string
        return TextFormField(
          decoration: InputDecoration(
            labelText: paramName,
            hintText: description.isNotEmpty ? description : 'Enter text',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: isRequired ? const Icon(Icons.star, size: 16, color: Colors.red) : null,
          ),
          maxLines: type == 'string' && description.contains('large') ? 3 : 1,
          onChanged: (String value) {
            setState(() {
              _parameters[paramName] = value;
            });
          },
        );
    }
  }

  Widget _buildExecuteButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isExecuting ? null : _executeTool,
        icon: _isExecuting 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.play_arrow_rounded),
        label: Text(_isExecuting ? '実行中...' : 'ツール実行'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildResultDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _error != null ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: _error != null 
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _error != null ? 'エラー' : '実行結果',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: _error != null 
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _error != null 
                ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _error != null 
                  ? Theme.of(context).colorScheme.error.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: SelectableText(
            _error ?? _lastResult ?? '',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: _error != null 
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class ToolInfo {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final String serverName;
  final mcp_client.Client client;

  ToolInfo({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.serverName,
    required this.client,
  });
}