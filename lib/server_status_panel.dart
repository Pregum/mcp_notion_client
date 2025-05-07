import 'package:flutter/material.dart';

/// MCPサーバーの接続状態を管理するクラス
class McpServerStatus {
  final String name;
  final String url;
  final Map<String, String> headers;
  bool isConnected;
  String? error;

  McpServerStatus({
    required this.name,
    required this.url,
    required this.headers,
    this.isConnected = false,
    this.error,
  });
}

class ServerStatusPanel extends StatefulWidget {
  final List<McpServerStatus> serverStatuses;
  final VoidCallback onRefresh;

  const ServerStatusPanel({
    super.key,
    required this.serverStatuses,
    required this.onRefresh,
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
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'MCPサーバー状態',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
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
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 