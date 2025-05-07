import 'package:flutter/material.dart';

class AddServerDialog extends StatefulWidget {
  const AddServerDialog({super.key});

  @override
  State<AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<AddServerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _authTokenController = TextEditingController();
  String _selectedServerType = 'Custom';

  final Map<String, Map<String, String>> _serverTemplates = {
    'Notion': {
      'name': 'Notion MCP',
      'url': 'http://192.168.11.35:8000/sse',
      'authHeader': 'Authorization',
      'authPrefix': 'Bearer ',
    },
    'Spotify': {
      'name': 'Spotify MCP',
      'url': 'http://192.168.11.35:8001/sse',
      'authHeader': 'Authorization',
      'authPrefix': 'Bearer ',
    },
    'Custom': {
      'name': '',
      'url': '',
      'authHeader': 'Authorization',
      'authPrefix': 'Bearer ',
    },
  };

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _authTokenController.dispose();
    super.dispose();
  }

  void _updateFieldsFromTemplate() {
    final template = _serverTemplates[_selectedServerType]!;
    _nameController.text = template['name']!;
    _urlController.text = template['url']!;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('MCPサーバーを追加'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedServerType,
                decoration: const InputDecoration(
                  labelText: 'サーバータイプ',
                ),
                items: _serverTemplates.keys.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedServerType = newValue;
                      _updateFieldsFromTemplate();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'サーバー名',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'サーバー名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'サーバーURL',
                  hintText: '例: http://192.168.11.35:8000/sse',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'サーバーURLを入力してください';
                  }
                  final uri = Uri.tryParse(value);
                  if (uri == null || !uri.hasAbsolutePath) {
                    return '有効なURLを入力してください';
                  }
                  if (!uri.scheme.startsWith('http')) {
                    return 'httpまたはhttpsで始まるURLを入力してください';
                  }
                  if (uri.host.isEmpty) {
                    return 'ホスト名（IPアドレス）を入力してください';
                  }
                  if (uri.port == 0) {
                    return 'ポート番号を指定してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _authTokenController,
                decoration: const InputDecoration(
                  labelText: '認証トークン',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '認証トークンを入力してください';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final template = _serverTemplates[_selectedServerType]!;
              Navigator.of(context).pop({
                'name': _nameController.text,
                'url': _urlController.text,
                'headers': {
                  template['authHeader']!:
                      '${template['authPrefix']!}${_authTokenController.text}',
                },
              });
            }
          },
          child: const Text('追加'),
        ),
      ],
    );
  }
} 