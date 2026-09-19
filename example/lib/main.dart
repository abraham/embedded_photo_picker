import 'package:embedded_photo_picker_example/example_home.dart';
import 'package:flutter/material.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    home: const ExampleHome(),
  ),
);
