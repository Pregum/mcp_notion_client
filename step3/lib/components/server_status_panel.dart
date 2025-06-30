import 'package:flutter/material.dart';
import 'package:mcp_notion_client/models/mcp_server_status.dart';

class ServerStatusPanel extends StatefulWidget {
  final List<McpServerStatus> serverStatuses;
  final VoidCallback onRefresh;
  final Function(String) onDelete;

  const ServerStatusPanel({
    super.key,
    required this.serverStatuses,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  State<ServerStatusPanel> createState() => _ServerStatusPanelState();
}

class _ServerStatusPanelState extends State<ServerStatusPanel> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'MCPサーバー状態',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                '(${widget.serverStatuses.where((s) => s.isConnected).length}/${widget.serverStatuses.length} 接続中)',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                tooltip: _isExpanded ? 'パネルを収納' : 'パネルを展開',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: widget.onRefresh,
                tooltip: 'サーバー状態を更新',
              ),
            ],
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 8),
            ...widget.serverStatuses.map(
              (status) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    Icon(
                      status.isConnected ? Icons.check_circle : Icons.error,
                      color: status.isConnected ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (status.error != null)
                            Text(
                              status.error!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[700],
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed:
                          () => _showDeleteConfirmation(context, status.name),
                      tooltip: 'サーバーを削除',
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    String serverName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('サーバーの削除'),
            content: Text('$serverName を削除してもよろしいですか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('削除'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      widget.onDelete(serverName);
    }
  }
}
