import 'package:flutter/material.dart';

class ModuleScreen extends StatelessWidget {
  final String title;
  final Color themeColor;

  const ModuleScreen({
    super.key,
    required this.title,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: themeColor.withOpacity(0.2),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        onPressed: () {
          // TODO: Implementar adição de novo item
        },
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: themeColor.withOpacity(0.2),
                child: Icon(Icons.book, color: themeColor),
              ),
              title: Text(
                'Item de $title ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Toque para ver detalhes ou editar.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implementar navegação para detalhes
              },
            ),
          );
        },
      ),
    );
  }
}
