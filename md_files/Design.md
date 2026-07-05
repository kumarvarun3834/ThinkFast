# Design Documentation - ThinkFast

## 1. Design Philosophy
ThinkFast utilizes a **Modern Dark Minimalist** design language. The goal is to reduce cognitive load during high-pressure quiz sessions while maintaining a high-tech, professional aesthetic suitable for both educational and casual environments.

## 2. Standardized Color Palette (The "Slate & Sapphire" Theme)

All colors are centralized in `lib/utils/global.dart` for cross-platform consistency.

| Role | Hex Code | Global Variable | Description |
| :--- | :--- | :--- | :--- |
| **Background** | `#0F172A` | `bgColor` | Deep navy/black used for the primary scaffolding. |
| **Surface/Card** | `#1E293B` | `cardColor` | Slate blue used for cards, list items, and containers. |
| **Primary Accent**| `#3B82F6` | `primaryAccent` | Bright electric blue for highlights, icons, and focus states. |
| **Button** | `#2563EB` | `btnColor` | Solid blue used for primary call-to-action buttons. |
| **Label/Hint** | `#94A3B8` | `labelColor` | Muted gray-blue for secondary text and placeholders. |
| **Primary Text** | `#E2E8F0` | `valueColor` | Light off-white/gray for high readability. |
| **Disabled/Hint** | `#475569` | `hintColor` | Darker gray for inactive or disabled states. |
| **Border** | `#334155` | `borderColor` | Subtle border color for separating UI elements. |
| **Correct** | `greenAccent` | `successColor` | Semantic color for correct answers and success states. |
| **Incorrect**| `redAccent` | `errorColor` | Semantic color for wrong answers and errors. |
| **Review** | `purple` | `reviewColor` | Semantic color for questions marked for review. |
| **Seen** | `blueAccent` | `infoColor` | Indicators for visited but unattempted questions. |
| **Partial** | `orangeAccent`| `warningColor` | Indicators for limited attempts or pending states. |
| **AI Accent** | `#A855F7` | - | Purple used for AI-specific containers and compliance highlights. |
| **Global Alert**| `#FB923C` | - | Orange used for system-wide broadcasts and minor safety notices. |


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
    *   **Quiz Mode:** Active selection highlighted with a `primaryAccent` border. **Note:** Correct answers are NOT distinguished (no bolding or color change) to maintain exam integrity.
    *   **Review Mode:** Correct options highlighted with a green background and bold text; incorrect selections with red borders. Includes status tags (e.g., "Correct choice").

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
