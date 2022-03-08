import 'package:flutter/material.dart';

class InputTextWidget extends StatelessWidget {
  final TextEditingController inputController;
  final String hintText;
  final String validatorText;

  const InputTextWidget({
    Key? key,
    required this.inputController,
    required this.hintText,
    required this.validatorText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: inputController,
      style: const TextStyle(
        color: Colors.white,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        border: const OutlineInputBorder(
          borderSide: BorderSide(
            color: Color(0xFF5d5d60),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(
            color: Color(0xFF5d5d60),
          ),
        ),
        fillColor: const Color(0xFF5d5d60),
        filled: true,
      ),
      validator: (value) {
        if (value!.isEmpty) {
          return validatorText;
        }
        return null;
      },
    );
  }
}
