import 'package:flutter/material.dart';

extension ColorExtension on String {
  Color toColor() {
    var hex = replaceAll("#", "").toUpperCase();
    if (hex.length == 6) hex = "FF$hex"; // default opacity = 100%
    return Color(int.parse(hex, radix: 16));
  }
}
