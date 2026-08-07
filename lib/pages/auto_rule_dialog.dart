import 'package:flutter/material.dart';
import 'package:movie_tool/services/auto_rule_generator.dart';
import 'package:movie_tool/models/rule.dart';
import 'package:movie_tool/services/storage_service.dart';

class AutoRuleDialog extends StatefulWidget {
  const AutoRuleDialog({super.key});

  @override
  State<AutoRuleDialog> createState() => _AutoRuleDialogState();
}

class _AutoRuleDialogState extends State<AutoRuleDialog> {
  final _urlController = TextEditingController();
  final _generator = AutoRuleGenerator();
  final _storage = StorageService();
  bool _isAnalyzing = false;
  MovieRule? _generatedRule;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _generatedRule = null;
      _error = null;
    });

    try {
      final rule = await _generator.generateFromUrl(url);
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          if (rule != null) {
            _generatedRule = rule;
          } else {
            _error = '无法分析该网站，请手动添加规则';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _error = '分析失败: $e';
        });
      }
    }
  }

  void _saveRule() {
    if (_generatedRule == null) return;
    _storage.addRule(_generatedRule!);
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('规则 "${_generatedRule!.name}" 已添加并保存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.dialogTheme.backgroundColor ?? theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '智能规则生成',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '输入电影网站首页地址，自动分析并生成可用规则',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: '电影网站URL',
                  hintText: '例如: https://example.com',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _analyze(),
              ),
              const SizedBox(height: 16),

              if (_isAnalyzing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('正在分析网站结构...'),
                      ],
                    ),
                  ),
                ),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                    ],
                  ),
                ),

              if (_generatedRule != null && !_isAnalyzing) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          const Text('分析成功!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _infoRow('名称', _generatedRule!.name),
                      _infoRow('网站', _generatedRule!.baseUrl),
                      _infoRow('搜索', _generatedRule!.searchUrl),
                      _infoRow('列表', _generatedRule!.searchListXPath),
                      _infoRow('标题', _generatedRule!.titleXPath),
                      if (_generatedRule!.coverXPath.isNotEmpty)
                        _infoRow('封面', _generatedRule!.coverXPath),
                      _infoRow('线路', _generatedRule!.playSourceListXPath),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  if (_generatedRule != null && !_isAnalyzing)
                    FilledButton.icon(
                      onPressed: _saveRule,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('保存规则'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _urlController.text.trim().isNotEmpty ? _analyze : null,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('开始分析'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text('$label:', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}