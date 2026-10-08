import 'package:flutter/material.dart';

/// Free-text category input with suggestions from existing categories.
class CategoryField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final String helperText;

  const CategoryField({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.helperText,
  });

  @override
  State<CategoryField> createState() => _CategoryFieldState();
}

class _CategoryFieldState extends State<CategoryField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        return widget.suggestions.where(
          (c) => c.toLowerCase().contains(query) && c.toLowerCase() != query,
        );
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Category (optional)',
            helperText: widget.helperText,
            prefixIcon: const Icon(Icons.folder_outlined),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      title: Text(option),
                      onTap: () => onSelected(option),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
