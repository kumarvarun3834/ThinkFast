# Firebase Firestore Data Structure - ThinkFast

This document outlines the schema for the Firestore database used in the ThinkFast application.

## Collection: `databases`
This collection stores the quiz sets created by users.

### Document Fields

| Field         | Type        | Description                                                                               |
|:--------------|:------------|:------------------------------------------------------------------------------------------|
| `creatorId`   | `String`    | The unique UID of the user who created the quiz.                                          |
| `user`        | `String`    | Display name or identifier (email/phone) of the creator.                                  |
| `title`       | `String`    | The title of the quiz set.                                                                |
| `description` | `String`    | A short description of what the quiz covers.                                              |
| `visibility`  | `String`    | Access level: `public` or `private`.                                                      |
| `time`        | `number`    | Total time allowed for the quiz in **seconds** (stored as minutes × 60).                  |
| `createdAt`   | `timestamp` | Server timestamp when the quiz was created.                                               |
| `updatedAt`   | `timestamp` | Server timestamp when the quiz was last modified.                                         |
| `data`        | `array`     | A list of question objects (see [Question Object Structure](#question-object-structure)). |

---

### Question Object Structure
Each item in the `data` array follows this schema:

| Field      | Type            | Description                                          |
|:-----------|:----------------|:-----------------------------------------------------|
| `id`       | `String`        | Unique identifier for the question (UUID).           |
| `question` | `String`        | The actual question text.                            |
| `type`     | `String`        | The type of question (e.g., `"Multiple Choice"`).    |
| `choices`  | `array<map>`    | A list of choice objects (see below).                |
| `answers`  | `array<String>` | A list of correct **choice IDs** from the `choices`. |

#### Choice Object Structure
| Field  | Type     | Description                                |
|:-------|:---------|:-------------------------------------------|
| `id`   | `String` | Unique identifier for the choice.          |
| `text` | `String` | The option text shown to the user.         |

---

## Collection: `responses`
This collection tracks user attempts and their answers for specific quizzes.

### Document Fields (`responses/{userUid}`)
The root document is named after the User's UID.

| Field       | Type     | Description                                |
|:------------|:---------|:-------------------------------------------|
| `lastActive`| `timestamp`| Last time the user attempted any quiz.   |

### Sub-collection: `attempts` (`responses/{userUid}/attempts/{attemptId}`)
Each document represents a single quiz session.

| Field         | Type        | Description                                     |
|:--------------|:------------|:------------------------------------------------|
| `quizId`      | `String`    | Reference to the `databaseId` in `databases`.   |
| `timestamp`   | `timestamp` | When the attempt was submitted.                 |
| `score`       | `number`    | Number of correct answers.                      |
| `totalQuestions`| `number`  | Total questions in the quiz.                    |
| `answers`     | `map`       | Map of `questionId` to the chosen **choiceId**. |

---

## Access & Queries
*   **User Lookups:** Use the `users/{uid}` document to retrieve the user's name, email, or profile picture based on the `creatorId` (in `databases`) or `respondentId` (in `attempts`).
*   **Collection Group Query:** To retrieve all responses for a specific quiz (used by the owner), a **Collection Group Index** must be created for the `attempts` sub-collection on the `quizId` field.

---

## Collection: `users`
This collection stores basic profile information for each registered user.

### Document Fields (`users/{uid}`)
The document ID is the User's UID from Firebase Auth.

| Field       | Type        | Description                                |
|:------------|:------------|:-------------------------------------------|
| `email`     | `String`    | Registered email address.                  |
| `name`      | `String`    | Display name (optional).                   |
| `createdAt` | `timestamp` | When the account/profile was created.      |
| `lastActive`| `timestamp` | Last time the user interacted with the app.|

---

## Database Tree Structure

### Firestore Hierarchy
```text
(root)
├── databases (collection)
│    └── {databaseId} (document)
│         ├── creatorId: "user_abc123"
│         ├── user: "name@example.com"
│         ├── title: "History Quiz"
│         ├── description: "World War II facts"
          ├── visibility: "public"
          ├── time: 300
          ├── createdAt: [Timestamp]
          ├── updatedAt: [Timestamp]
│         └── data (array)
│              └── [0..N] (map)
│                   ├── id: "q_unique_123"
│                   ├── question: "Who was...?"
│                   ├── type: "Multiple Choice"
│                   ├── choices (array)
│                   │    └── [0..M] (map)
│                   │         ├── id: "c_1"
│                   │         └── text: "Option A"
│                   └── answers: ["c_1"]
│
└── responses (collection)
     └── {userUid} (document)
          └── attempts (sub-collection)
               └── {attemptId} (document)
                    ├── quizId: "databaseId_xyz"
                    ├── timestamp: [Timestamp]
                    ├── score: 8
                    ├── totalQuestions: 10
                    └── answers (map)
                         ├── "q_unique_123": "c_1"
                         └── "q_unique_456": "c_2"
```

### Firebase Storage (Cloud Storage)
```text
gs://thinkfast3834.firebasestorage.app/
└── quiz_images/
     └── {databaseId}/
          └── cover_image.png
```

---

## Example Document JSON
```json
{
  "creatorId": "user_12345",
  "user": "test@example.com",
  "title": "Basic Math Quiz",
  "description": "A quiz covering addition, subtraction, and multiplication.",
  "visibility": "public",
  "time": 600,
  "createdAt": "2023-10-27T10:00:00Z",
  "data": [
    {
      "id": "q1_math_add",
      "question": "15 + 7",
      "type": "Multiple Choice",
      "choices": [
        {"id": "q1_c1", "text": "22"},
        {"id": "q1_c2", "text": "21"},
        {"id": "q1_c3", "text": "23"},
        {"id": "q1_c4", "text": "20"}
      ],
      "answers": ["q1_c1"]
    },
    {
      "id": "q2_math_mul",
      "question": "12 * 3",
      "type": "Multiple Choice",
      "choices": [
        {"id": "q2_c1", "text": "36"},
        {"id": "q2_c2", "text": "32"},
        {"id": "q2_c3", "text": "38"},
        {"id": "q2_c4", "text": "34"}
      ],
      "answers": ["q2_c1"]
    }
  ]
}
```
