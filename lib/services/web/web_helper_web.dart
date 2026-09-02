import 'dart:js_interop';
import 'package:web/web.dart';
import 'package:flutter/material.dart';

void enterFullScreen() {
  try {
    document.documentElement?.requestFullscreen();
  } catch (e) {
    debugPrint("Fullscreen error: $e");
  }
}

void exitFullScreen() {
  try {
    if (document.fullscreenElement != null) {
      document.exitFullscreen();
    }
  } catch (_) {}
}

bool isFullScreen() {
  return document.fullscreenElement != null;
}

void listenToTabSwitch(VoidCallback onSwitch) {
  window.onblur = (Event event) {
    onSwitch();
  }.toJS;
}

void listenToFullScreenChange({
  required VoidCallback onExit,
  VoidCallback? onIntentToExit,
}) {
  document.onfullscreenchange = (Event event) {
    if (document.fullscreenElement == null) {
      onExit();
    }
  }.toJS;

  // Listen for the Escape key specifically as an intent to exit
  window.onkeydown = (KeyboardEvent event) {
    if (event.key == 'Escape' && document.fullscreenElement != null) {
      if (onIntentToExit != null) onIntentToExit();
    }
  }.toJS;
}

void listenToTextSelection(VoidCallback onSelection) {
  document.onselectionchange = (Event event) {
    final selection = window.getSelection();
    if (selection != null && selection.toString().trim().isNotEmpty) {
      onSelection();
      selection.removeAllRanges();
    }
  }.toJS;
}
