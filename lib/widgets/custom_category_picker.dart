import 'package:flutter/material.dart';
import 'package:tv/data/models/custom_category.dart';

/// The custom category the user picked, or the name of a new one.
class CategoryChoice {
  final int? id;
  final String? newName;

  const CategoryChoice.existing(int this.id) : newName = null;

  const CategoryChoice.create(String this.newName) : id = null;
}

/// Lets the user pick one of [categories] or type a new name.
Future<CategoryChoice?> showCustomCategoryPicker(
  BuildContext context,
  List<CustomCategory> categories, {
  String title = 'Add to category',
}) {
  return showDialog<CategoryChoice>(
    context: context,
    builder: (context) => _PickerDialog(categories: categories, title: title),
  );
}

class _PickerDialog extends StatefulWidget {
  final List<CustomCategory> categories;
  final String title;

  const _PickerDialog({required this.categories, required this.title});

  @override
  State<_PickerDialog> createState() => _PickerDialogState();
}

class _PickerDialogState extends State<_PickerDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final name = _name.text.trim();
    if (name.isNotEmpty) {
      Navigator.of(context).pop(CategoryChoice.create(name));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final category in widget.categories)
                    ListTile(
                      leading: const Icon(Icons.bookmark_outline),
                      title: Text(category.name),
                      trailing: Text('${category.channelKeys.length}'),
                      onTap: () =>
                          Navigator.of(context)
                              .pop(CategoryChoice.existing(category.id)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: TextField(
                controller: _name,
                autofocus: widget.categories.isEmpty,
                onSubmitted: (_) => _create(),
                decoration: InputDecoration(
                  labelText: 'New category',
                  prefixIcon: const Icon(Icons.add),
                  suffixIcon: IconButton(
                    tooltip: 'Create',
                    icon: const Icon(Icons.check),
                    onPressed: _create,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
