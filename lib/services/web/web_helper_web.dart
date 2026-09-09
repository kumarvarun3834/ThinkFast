import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart';

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
  void Function(String)? onViolation,
}) {
  document.onfullscreenchange = (Event event) {
    if (document.fullscreenElement == null) {
      onExit();
    }
  }.toJS;

  // 🛡️ Web Lockdown: Advanced Anti-Cheat Keyboard Interceptor
  window.onkeydown = (KeyboardEvent event) {
    final String key = event.key;
    final bool isLocked = document.fullscreenElement != null;

    if (isLocked) {
      // 1. Identify restricted keys/combinations
      final bool isFunctionKey =
          key.length >= 2 &&
          key.startsWith('F') &&
          int.tryParse(key.substring(1)) != null;

      final bool isNavigationKey = [
        'PrintScreen',
        'Insert',
        'PageUp',
        'PageDown',
        'Home',
        'End',
        'ContextMenu',
      ].contains(key);

      // 2. Identify forbidden combinations (Alt, Ctrl, Meta)
      final bool isModifierActive =
          event.altKey || event.ctrlKey || event.metaKey;

      if (key == 'Escape' ||
          isFunctionKey ||
          isNavigationKey ||
          isModifierActive) {
        // Prevent default browser action (where possible)
        event.preventDefault();

        String reason = "Restricted key '$key' detected";
        if (isModifierActive) {
          reason = "System shortcut combination detected (Alt/Ctrl/Meta)";
        }

        debugPrint(
          "ThinkFast Security: Blocked restricted input '$key' in lockdown mode.",
        );

        // Trigger violation callback if provided
        if (onViolation != null) {
          onViolation(reason);
        }

        if (key == 'Escape' && onIntentToExit != null) {
          onIntentToExit();
        }

        return;
      }
    }
  }.toJS;
}

/// 🚫 Disable all text selection, copying, and context menus on the page
void disableTextSelection() {
  final style = document.createElement('style') as HTMLStyleElement;
  style.innerText = '''
    * {
      -webkit-user-select: none !important;
      -moz-user-select: none !important;
      -ms-user-select: none !important;
      user-select: none !important;
    }
  ''';
  document.head?.append(style);

  // Intercept Copy event
  document.oncopy = (Event event) {
    event.preventDefault();
  }.toJS;

  // Intercept Context Menu (Right Click)
  document.oncontextmenu = (Event event) {
    event.preventDefault();
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
