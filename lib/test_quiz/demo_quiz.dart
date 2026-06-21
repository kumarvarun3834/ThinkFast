const String demoQuizJson = r'''
{
  "title": "Interactive Demo Quiz",
  "description": "A sample quiz to demonstrate ThinkFast features.",
  "time": 5,
  "markingScheme": {
    "type": "default"
  },
  "questions": [
    {
      "question": "What is the capital of France?",
      "choices": [
        "Paris",
        "London",
        "Berlin",
        "Madrid"
      ],
      "answers": [
        "Paris"
      ],
      "type": "Single Choice",
      "subject": "General",
      "description": "Paris is the capital and most populous city of France."
    },
    {
      "question": "Which of these are Flutter widgets?",
      "choices": [
        "Container",
        "Row",
        "View",
        "Div"
      ],
      "answers": [
        "Container",
        "Row"
      ],
      "type": "Multiple Choice",
      "subject": "Tech",
      "description": "Container and Row are core layout widgets in Flutter."
    },
    {
      "question": "15 + 27 = ?",
      "answers": [
        "42"
      ],
      "type": "Integer",
      "subject": "Math",
      "description": "Simple addition: 15 + 27 = 42."
    }
  ]
}
''';
