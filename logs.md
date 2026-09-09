## Planned Changes

- **Web Lockdown (Advanced Anti-Cheat)**:
    - Implemented a low-level keyboard interceptor to disable **Escape**, **Function keys (F1-F12)**, and navigation keys (**PrintScreen, Insert, PageUp/Down, Home, End**).
    - Blocked system-level modifier combinations (**Alt, Ctrl, Meta**) to prevent screen switching and browser inspection.
    - Added global CSS and event listeners to **disable text selection, copying, and right-click context menus** across the entire application.
    - Integrated a **Fullscreen Auto-Recovery** system that attempts to re-enter fullscreen immediately if the user exits or the browser minimizes.
    - Updated security policy to allow **3 attempts** for fullscreen exit/violation, with automatic quiz submission on the **4th strike**.
    - Enhanced the violation dialog to display dynamic strike counts and progressive warnings.
