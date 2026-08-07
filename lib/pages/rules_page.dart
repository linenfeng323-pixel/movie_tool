import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movie_tool/models/rule.dart';
import 'package:movie_tool/services/storage_service.dart';

class RulesPage extends StatefulWidget {
  const RulesPage({super.key});

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  final _storage = StorageService();
  List<MovieRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  void _loadRules() {
    setState(() => _rules = _storage.getRules());
  }

  void _addFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剪贴板为空')),
        );
      }
      return;
    }

    final text = data.text!.trim();

    try {
      // Try to parse as JSON directly
      if (text.startsWith('{')) {
        final json = jsonDecode(text) as Map<String, dynamic>;
        final rule = MovieRule.fromJson(json);
        _storage.addRule(rule);
        _loadRules();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('规则 "${rule.name}" 已添加')),
          );
        }
        return;
      }

      // Try to parse as kazumi:// base64
      if (text.startsWith('kazumi://')) {
        final base64Str = text.substring('kazumi://'.length);
        final bytes = base64Decode(base64Str);
        final jsonStr = utf8.decode(bytes);
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final rule = MovieRule.fromJson(json);
        _storage.addRule(rule);
        _loadRules();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('规则 "${rule.name}" 已添加')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法识别的规则格式')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final baseUrlController = TextEditingController(text: 'https://');
    final searchUrlController = TextEditingController();
    final searchListXPathController = TextEditingController();
    final titleXPathController = TextEditingController();
    final coverXPathController = TextEditingController();
    final detailLinkXPathController = TextEditingController();
    final yearXPathController = TextEditingController();
    final descriptionXPathController = TextEditingController();
    final actorXPathController = TextEditingController();
    final playSourceListXPathController = TextEditingController();
    final playUrlXPathController = TextEditingController();
    final refererController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('手动添加规则'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: '规则名称', hintText: '例如: 我的电影源')),
              TextField(controller: baseUrlController, decoration: const InputDecoration(labelText: '网站BaseURL')),
              TextField(controller: searchUrlController, decoration: const InputDecoration(labelText: '搜索URL', hintText: '使用{kw}代替关键词')),
              TextField(controller: searchListXPathController, decoration: const InputDecoration(labelText: '搜索结果列表XPath')),
              TextField(controller: titleXPathController, decoration: const InputDecoration(labelText: '标题XPath')),
              TextField(controller: coverXPathController, decoration: const InputDecoration(labelText: '封面XPath(可选)')),
              TextField(controller: detailLinkXPathController, decoration: const InputDecoration(labelText: '详情链接XPath(可选)')),
              TextField(controller: yearXPathController, decoration: const InputDecoration(labelText: '年份XPath(可选)')),
              TextField(controller: descriptionXPathController, decoration: const InputDecoration(labelText: '简介XPath(可选)')),
              TextField(controller: actorXPathController, decoration: const InputDecoration(labelText: '演员XPath(可选)')),
              TextField(controller: playSourceListXPathController, decoration: const InputDecoration(labelText: '播放线路列表XPath')),
              TextField(controller: playUrlXPathController, decoration: const InputDecoration(labelText: '播放地址XPath')),
              TextField(controller: refererController, decoration: const InputDecoration(labelText: 'Referer(可选)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入规则名称')),
                );
                return;
              }
              final rule = MovieRule(
                name: nameController.text,
                baseUrl: baseUrlController.text,
                searchUrl: searchUrlController.text,
                searchListXPath: searchListXPathController.text,
                titleXPath: titleXPathController.text,
                coverXPath: coverXPathController.text,
                detailLinkXPath: detailLinkXPathController.text,
                yearXPath: yearXPathController.text,
                descriptionXPath: descriptionXPathController.text,
                actorXPath: actorXPathController.text,
                playSourceListXPath: playSourceListXPathController.text,
                playUrlXPath: playUrlXPathController.text,
                referer: refererController.text,
              );
              _storage.addRule(rule);
              _loadRules();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('规则 "${rule.name}" 已添加')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _exportRule(MovieRule rule) {
    final json = jsonEncode(rule.toJson());
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('规则JSON已复制到剪贴板')),
    );
  }

  void _deleteRule(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除规则'),
        content: Text('确定删除规则 "${_rules[index].name}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              _storage.deleteRule(index);
              Navigator.pop(ctx);
              _loadRules();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('规则管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '手动添加',
            onPressed: _showAddDialog,
          ),
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: '从剪贴板导入',
            onPressed: _addFromClipboard,
          ),
        ],
      ),
      body: _rules.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rule, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无规则', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('点击右上角 + 添加', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('或点击粘贴图标从剪贴板导入', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rules.length,
              itemBuilder: (context, index) {
                final rule = _rules[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        rule.name.isNotEmpty ? rule.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(rule.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      rule.baseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.file_download, size: 20),
                          tooltip: '导出JSON',
                          onPressed: () => _exportRule(rule),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          tooltip: '删除',
                          onPressed: () => _deleteRule(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}