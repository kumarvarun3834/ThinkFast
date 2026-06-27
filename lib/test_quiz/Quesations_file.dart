/// 📝 Standard Test Question Data
/// This file provides a structured list of questions for testing and seeding.
library;

const List<Map<String, Object>> testQuestions = [
  {
    "question": "What are the main building blocks of Flutter UIs?",
    "type": "Single Choice",
    "subject": "Flutter Basics",
    "choices": ["Widgets", "Components", "Blocks", "Functions"],
    "answers": ["Widgets"],
    "description": "Everything in Flutter is a widget.",
  },
  {
    "question": "How are Flutter UIs built?",
    "type": "Single Choice",
    "subject": "Flutter Basics",
    "choices": [
      "By combining widgets in code",
      "By combining widgets in a visual editor",
      "By defining widgets in config files",
      "By using XCode for iOS and Android Studio for Android",
    ],
    "answers": ["By combining widgets in code"],
    "description": "Flutter uses a declarative UI approach defined in code.",
  },
  {
    "question": "What's the purpose of a StatefulWidget?",
    "type": "Single Choice",
    "subject": "Flutter Widgets",
    "choices": [
      "Update UI as data changes",
      "Update data as UI changes",
      "Ignore data changes",
      "Render UI that does not depend on data",
    ],
    "answers": ["Update UI as data changes"],
    "description": "StatefulWidgets maintain state that can change over time.",
  },
  {
    "question": "Which of these are layout widgets?",
    "type": "Multiple Choice",
    "subject": "Flutter Widgets",
    "choices": ["Row", "Column", "Text", "ElevatedButton"],
    "answers": ["Row", "Column"],
    "description": "Row and Column are used for positioning other widgets.",
  },
  {
    "question": "What happens if you change data in a StatelessWidget?",
    "type": "Single Choice",
    "subject": "Flutter Widgets",
    "choices": [
      "The UI is not updated",
      "The UI is updated",
      "The closest StatefulWidget is updated",
      "Any nested StatefulWidgets are updated",
    ],
    "answers": ["The UI is not updated"],
    "description":
        "StatelessWidgets do not track state changes; you must rebuild them with new data.",
  },
];
