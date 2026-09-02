import 'package:flutter/material.dart';

void enterFullScreen() {}

void exitFullScreen() {}

void listenToTabSwitch(VoidCallback onSwitch) {}

void listenToFullScreenChange({
  required VoidCallback onExit,
  VoidCallback? onIntentToExit,
}) {}

void listenToTextSelection(VoidCallback onSelection) {}

bool isFullScreen() => false;
