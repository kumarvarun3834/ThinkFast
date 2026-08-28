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

void listenToFullScreenChange(VoidCallback onExit) {
  document.onfullscreenchange = (Event event) {
    if (document.fullscreenElement == null) {
      onExit();
    }
  }.toJS;
}

void listenToTextSelection(VoidCallback onSelection) {
  document.onselectionchange = (Event event) {
    final selection = window.getSelection();
    if (selection != null && selection.toString().trim().isNotEmpty) {
      onSelection();
      // Clear selection after detection to prevent infinite loops or multiple warnings
      selection.removeAllRanges();
    }
  }.toJS;
}
