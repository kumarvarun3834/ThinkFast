# Design Documentation - ThinkFast

## 1. Design Philosophy
ThinkFast utilizes a **Modern Dark Minimalist** design language. The goal is to reduce cognitive load during high-pressure quiz sessions while maintaining a high-tech, professional aesthetic suitable for both educational and casual environments.

## 2. Color Palette (The "Slate & Sapphire" Theme)

| Role | Hex Code | Visual Sample | Description |
| :--- | :--- | :--- | :--- |
| **Background** | `#0F172A` | ![#0F172A](https://via.placeholder.com/15/0F172A?text=+) | Deep navy/black used for the primary scaffolding. |
| **Surface/Card** | `#1E293B` | ![#1E293B](https://via.placeholder.com/15/1E293B?text=+) | Slate blue used for cards, list items, and containers. |
| **Primary Accent**| `#3B82F6` | ![#3B82F6](https://via.placeholder.com/15/3B82F6?text=+) | Bright electric blue for highlights, icons, and focus states. |
| **Button** | `#2563EB` | ![#2563EB](https://via.placeholder.com/15/2563EB?text=+) | Solid blue used for primary call-to-action buttons. |
| **Label/Hint** | `#94A3B8` | ![#94A3B8](https://via.placeholder.com/15/94A3B8?text=+) | Muted gray-blue for secondary text and placeholders. |
| **Primary Text** | `#E2E8F0` | ![#E2E8F0](https://via.placeholder.com/15/E2E8F0?text=+) | Light off-white/gray for high readability. |
| **Border** | `#334155` | ![#334155](https://via.placeholder.com/15/334155?text=+) | Subtle border color for separating UI elements. |
| **Correct** | `greenAccent` | | Semantic color for correct answers and success states. |
| **Incorrect**| `redAccent` | | Semantic color for wrong answers and errors. |
| **Review** | `purple` | | Semantic color for questions marked for review. |
| **Partial** | `orangeAccent`| | Semantic color for unanswered or partially correct states. |

## 3. Typography
*   **Primary Font:** `Poppins` (Google Fonts)
    *   **Headings:** Bold/Semi-Bold (700/600), used for titles and headers.
    *   **Body:** Regular (400), used for descriptions and questions.
    *   **Buttons:** Medium (500) with Uppercase transformation for hierarchy.

## 4. UI Components & Patterns

### 4.1 Cards
*   **Border Radius:** 12px - 16px.
*   **Border:** 1px solid `borderColor` (`#334155`).
*   **Elevation:** Minimal or none; depth is created using color contrast (`cardColor` vs `bgColor`).

### 4.2 Inputs
*   **Style:** Filled inputs using `cardColor`.
*   **Focus:** Border color transitions to `primaryAccent`.
*   **Icons:** Always use `labelColor` for inactive icons and `primaryAccent` for active/meaningful ones.

### 4.3 Buttons
*   **Primary:** Large, rounded (12px), background `btnColor`, text `valueColor` (white).
*   **Outline/Secondary:** Transparent background with `primaryAccent` border and text.

### 4.4 Quiz Interface
*   **Countdown Timer:** Bold digital clock in the sub-header.
*   **Progress Navigator:** Horizontal scrollable row of circles.
    *   **Blue:** Seen but not answered.
    *   **Green:** Answered (Quiz Mode) or Correct (Review Mode).
    *   **Red:** Wrong (Review Mode).
    *   **Purple:** Marked for Review.
    *   **Purple/Green Gradient:** Marked for Review + Correct/Answered.
*   **Option Selection:** 
    *   **Quiz Mode:** Active border highlights with `primaryAccent`.
    *   **Review Mode:** Correct options highlighted with green background; incorrect selections with red borders. Includes status tags (e.g., "Correct choice").

### 4.5 Post-Quiz Experience
*   **Summary View:** Minimalist card with total score and categorized counts (Correct/Wrong/Skipped).
*   **Attempt Details:** Transitions back to the Quiz module in a non-editable `ReviewMode`.

## 5. Assets
*   **Logo:** `assets/images/quiz-logo.png` - A high-contrast version of the brand logo optimized for dark backgrounds.
*   **Icons:** Standard `Material Icons` pack, following the blue-accented theme.

## 6. Layout Principles
*   **Spacing:** Follows an 8dp grid system (8, 16, 24, 32).
*   **Safe Areas:** Strict adherence to `SafeArea` to support various mobile aspect ratios and notches.
*   **Gradients:** Occasional use of subtle linear gradients (from `bgColor` to a slightly lighter blue) for depth on splash screens or main dashboards.
