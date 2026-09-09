import 'package:flutter/material.dart';

void enterFullScreen() {}

void exitFullScreen() {}

void listenToTabSwitch(VoidCallback onSwitch) {}

void listenToFullScreenChange({
  required VoidCallback onExit,
  VoidCallback? onIntentToExit,
  void Function(String)? onViolation,
}) {}

void listenToTextSelection(VoidCallback onSelection) {}

void disableTextSelection() {}

bool isFullScreen() => false;
