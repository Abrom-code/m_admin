import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ToastHelper {
  ToastHelper._();

  static void success(String message) {
    Fluttertoast.cancel();

    _show(message, Colors.green.withValues(alpha: .8));
  }

  static void error(String message) {
    Fluttertoast.cancel();

    _show(message, Colors.red.withValues(alpha: .8));
  }

  static void warning(String message) {
    Fluttertoast.cancel();

    _show(message, Colors.orange.withValues(alpha: .8));
  }

  static void info(String message) {
    Fluttertoast.cancel();
    _show(message, Colors.blue.withValues(alpha: .8));
  }

  static void _show(String message, Color backgroundColor) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.TOP_RIGHT,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }
}
