import 'package:flutter/material.dart';

class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  const SearchField({super.key, required this.hint, required this.onChanged, this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: hint),
      onChanged: onChanged,
    );
  }
}
