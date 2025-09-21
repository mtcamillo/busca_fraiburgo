import 'package:flutter/material.dart';

class CategoryTile extends StatelessWidget {
  final String name;
  final String? icon;
  final VoidCallback? onTap;
  const CategoryTile({super.key, required this.name, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.category),
        title: Text(name),
        subtitle: icon != null ? Text('ícone: $icon') : null,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
