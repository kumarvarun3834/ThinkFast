# ThinkFast AI Generation Reference Guide 🧠

This guide contains every possible JSON configuration supported by the ThinkFast platform. Use this
to instruct an AI to generate specific quiz types.

---

## 🧩 1. Core Quiz Structure

| Field                   | Type    | Required | Description                                                         |
|:------------------------|:--------|:---------|:--------------------------------------------------------------------|
| `title`                 | String  | Yes      | Name of the quiz.                                                   |
| `description`           | String  | Yes      | Summary of the quiz.                                                |
| `visibility`            | String  | No       | `public`, `private`, or `scheduled`.                                |
| `activeAt`              | String  | No       | ISO Timestamp for scheduled activation (e.g. `2024-12-31T09:00Z`).  |
| `time`                  | Number  | Yes      | Total quiz time in **minutes**. Set to `0` for **Unlimited**.       |
| `perQuestionTime`       | Number  | No       | Default time for every question in **seconds**. `0` to disable.     |
| `allowMultipleAttempts` | Boolean | No       | `true` to allow; `false` for one-time attempt.                      |
| `maxAttempts`           | Number  | No       | Total attempts allowed if `allowMultipleAttempts` is `true`.        |
| `isRestricted`          | Boolean | No       | `true` to only allow specific users (see `allowedParticipants`).    |
| `allowedParticipants`   | Array   | No       | List of Emails or UIDs: `["user@mail.com", "uid123"]`.              |
| `completeRandomShuffle` | Boolean | No       | `true` to mix all modules; `false` to keep module grouping.         |
| `markingScheme`         | Map     | No       | Scoring configuration (see Section 2).                              |
| `attemptLimits`         | Map     | No       | Selection constraints (see Section 3).                          |
| `timingScheme`          | Map     | No       | Advanced Pacing (see Section 4).                                    |
| `questions`             | Array   | Yes      | List of question objects (see Section 5).                       |

---

## 🎯 2. Marking Scheme Options (`markingScheme`)

| Type                   | JSON Structure                                                                                                                                                                             |
|:-----------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Default (+4, -1)**   | `{"type": "default"}`                                                                                                                                                                      |
| **Custom Global**      | `{"type": "entire_quiz", "global": {"correct": 5, "wrong": -2}}`                                                                                                                           |
| **Per Question Type**  | `{"type": "per_question_type", "perQuestionType": {"Single Choice": {"correct": 4, "wrong": -1}, "Multiple Choice": {"correct": 6, "wrong": -2}, "Integer": {"correct": 10, "wrong": 0}}}` |
| **Individual (Per Q)** | `{"type": "per_question"}` *(Note: Must define `correct` and `wrong` inside each question object)*                                                                                         |

---

## 📊 3. Attempt Limit Options (`attemptLimits`)

*Limits how many questions a user can answer in a section (Select N out of M). Use `0` or omit for no limit.*

| Type             | JSON Structure                                                                                       |
|:-----------------|:-----------------------------------------------------------------------------------------------------|
| **None**         | `{"type": "none"}`                                                                                   |
| **Global Quota** | `{"type": "global", "global": {"Single Choice": 5, "Multiple Choice": 2}}`                           |
| **Module Quota** | `{"type": "per_module", "perModule": {"Science": {"Integer": 5}, "History": {"Single Choice": 10}}}` |

---

## ⏱️ 4. Advanced Timing Options (`timingScheme`)

| Type                       | JSON Structure                                                                                                                                                                                                     |
|:---------------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Global Only**            | `{"type": "global"}` (Uses the top-level `time` field)                                                                                                                                                             |
| **Per Question (Fixed)**   | `{"type": "per_question"}` (Uses the top-level `perQuestionTime` field)                                                                                                                                            |
| **Per Module (Fixed)**     | `{"type": "per_module", "settings": {"perModule": {"Math": {"total": 600, "perQuestion": 0}, "Physics": {"total": 900}}}}`                                                                                         |
| **Per Question Type**      | `{"type": "per_question_type", "settings": {"perType": {"Single Choice": 30, "Multiple Choice": 60, "Integer": 120}}}`                                                                                             |
| **Per Type Per Module**    | `{"type": "per_type_per_module", "settings": {"perModuleType": {"Physics": {"Single Choice": 60, "Integer": 120}}}}`                                                                                               |

---

## ❓ 5. Question Object Structure

| Field         | Type   | Required   | Description                                                    |
|:--------------|:-------|:-----------|:---------------------------------------------------------------|
| `question`    | String | Yes        | The question text.                                             |
| `type`        | String | Yes        | `Single Choice`, `Multiple Choice`, or `Integer`.              |
| `subject`     | String | Yes        | Module Name (e.g., "Math", "Biology").                         |
| `choices`     | Array  | For Choice | List of options: `["Opt A", "Opt B"]`.                         |
| `answers`     | Array  | Yes        | List of correct options or the single integer value.           |
| `description` | String | No         | Detailed solution shown in Review Mode.                        |
| `timer`       | Number | No         | Override timer in **seconds** for this specific question.      |
| `correct`     | Number | No         | Points earned (only if markingScheme type is `per_question`).  |
| `wrong`       | Number | No         | Penalty points (only if markingScheme type is `per_question`). |

---

## 🧪 6. All Sample Combinations

### Sample 1: The "Simple Trivia" (Basic)

*Single module, default scoring, no limits.*

```json
{
  "title": "Simple Trivia",
  "description": "Just a basic test.",
  "time": 10,
  "questions": [
    {
      "question": "Is the sky blue?",
      "choices": [
        "Yes",
        "No"
      ],
      "answers": [
        "Yes"
      ],
      "type": "Single Choice",
      "subject": "General"
    }
  ]
}
```

### Sample 2: The "Competitive Exam" (Complex)

*Multiple modules, per-type marking, per-module limits.*

```json
{
  "title": "Scholarship Exam",
  "time": 120,
  "markingScheme": {
    "type": "per_question_type",
    "perQuestionType": {
      "Single Choice": {
        "correct": 4,
        "wrong": -1
      },
      "Integer": {
        "correct": 8,
        "wrong": 0
      }
    }
  },
  "attemptLimits": {
    "type": "per_module",
    "perModule": {
      "Physics": {
        "Single Choice": 10,
        "Integer": 5
      },
      "Chemistry": {
        "Single Choice": 15
      }
    }
  },
  "questions": [
    {
      "question": "Speed of light in m/s?",
      "choices": [],
      "answers": [
        "300000000"
      ],
      "type": "Integer",
      "subject": "Physics",
      "description": "Roughly 3e8 m/s."
    }
  ]
}
```

### Sample 3: The "Rapid Fire" (Timed)

*Generalized 15s timer, global limits, random shuffle.*

```json
{
  "title": "Quick Fire Blitz",
  "perQuestionTime": 15,
  "completeRandomShuffle": true,
  "attemptLimits": {
    "type": "global",
    "global": {
      "Single Choice": 20
    }
  },
  "questions": [
    {
      "question": "Capital of Japan?",
      "choices": [
        "Tokyo",
        "Osaka"
      ],
      "answers": [
        "Tokyo"
      ],
      "type": "Single Choice",
      "subject": "Geography"
    }
  ]
}
```

### Sample 4: The "Mixed Complexity" (Overrides)

*Per-question scoring and individual timers.*

```json
{
  "title": "Special Override Test",
  "markingScheme": {
    "type": "per_question"
  },
  "questions": [
    {
      "question": "Critical Logical Puzzle (Hard)",
      "choices": [
        "X",
        "Y"
      ],
      "answers": [
        "X"
      ],
      "type": "Single Choice",
      "subject": "Logic",
      "correct": 50,
      "wrong": -50,
      "timer": 180,
      "description": "High stakes, high time limit."
    },
    {
      "question": "Simple Warmup",
      "choices": [
        "A",
        "B"
      ],
      "answers": [
        "A"
      ],
      "type": "Single Choice",
      "subject": "Logic",
      "correct": 2,
      "wrong": 0,
      "timer": 15
    }
  ]
}
```

### Sample 5: The "Integer Challenge" (Unlimited)

*No timer, focus on numerical accuracy.*

```json
{
  "title": "Math Drills",
  "description": "Enter the exact values.",
  "time": 0,
  "questions": [
    {
      "question": "15 * 15?",
      "answers": [
        "225"
      ],
      "type": "Integer",
      "subject": "Math"
    }
  ]
}
```

### Sample 6: The "Interactive Demo" (Reference)

*A comprehensive demo used in the help system, located at `test/demo_quiz.json`.*

```json
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
      "choices": ["Paris", "London", "Berlin", "Madrid"],
      "answers": ["Paris"],
      "type": "Single Choice",
      "subject": "General",
      "description": "Paris is the capital and most populous city of France."
    }
  ]
}
```
