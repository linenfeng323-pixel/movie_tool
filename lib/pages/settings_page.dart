import 'package:flutter/material.dart';
import 'package:movie_tool/services/storage_service.dart';
import 'package:movie_tool/services/app_provider.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance
          Text('外观', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('深色模式'),
              subtitle: const Text('切换深色/浅色主题'),
              value: provider.isDark,
              onChanged: (_) => provider.toggleTheme(),
              secondary: Icon(provider.isDark ? Icons.dark_mode : Icons.light_mode),
            ),
          ),
          const SizedBox(height: 24),

          // Data
          Text('数据', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('清空历史记录'),
              subtitle: const Text('删除所有观看历史'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('清空历史'),
                    content: const Text('确定要清空所有观看历史吗？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                      TextButton(
                        onPressed: () {
                          _storage.clearHistory();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('历史已清空')),
                          );
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // About
          Text('关于', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('版本'),
                  trailing: const Text('1.0.0'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('技术栈'),
                  subtitle: const Text('Flutter + XPath + Hive'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}