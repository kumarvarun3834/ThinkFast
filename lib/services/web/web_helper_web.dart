import 'dart:html' as html;
import 'package:flutter/material.dart';

void enterFullScreen() {
  try {
    html.document.documentElement?.requestFullscreen();
  } catch (e) {
    debugPrint("Fullscreen error: $e");
  }
}

void exitFullScreen() {
  try {
    if (html.document.fullscreenElement != null) {
      html.document.exitFullscreen();
    }
  } catch (_) {}
}

void listenToTabSwitch(VoidCallback onSwitch) {
  html.window.onBlur.listen((event) {
    onSwitch();
  });
}
