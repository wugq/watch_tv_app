import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SaveButton extends StatelessWidget {
  final RxBool isSaving;
  final VoidCallback onPressed;
  final String label;

  const SaveButton({
    super.key,
    required this.isSaving,
    required this.onPressed,
    this.label = 'Save',
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: isSaving.value ? null : onPressed,
        icon: isSaving.value
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check),
        label: Text(label),
      ),
    );
  }
}
