# Firebase Firestore Data Structure - ThinkFast (Production)

This document outlines the schema for the Firestore database used in the ThinkFast application,
aligned with the production security rules and architecture.

## 1. Collection: `databases`

Stores the main quiz metadata and question content.

### Document Fields

| Field         | Type         | Description                                                                     |
|:--------------|:-------------|:--------------------------------------------------------------------------------|
| `creatorId`   | `String`     | The unique UID of the user who created the quiz.                                |
| `user`        | `String`     | Display identifier (email/phone) of the creator.                                |
| `title`       | `String`     | The title of the quiz set.                                                      |
| `description` | `String`     | A short description of the quiz content.                                        |
| `visibility`  | `String`     | Access level: `public` or `private`.                                            |
| `time`        | `number`     | Total allowed time in **seconds**.                                              |
| `createdAt`   | `timestamp`  | Server timestamp when the quiz was created.                                     |
| `updatedAt`   | `timestamp`  | Server timestamp when the quiz was last modified.                               |
| `data`        | `array<map>` | A list of transformed question objects (see [Data Structure](#data-structure)). |

### Data Structure (`data` field)

Format:
`[{ "Q": { "id": "qUid", "text": "..." }, "Opt": [{ "id": "optUid", "text": "..." }, ...], "type": "..." }]`

---

## 2. Collection: `answer_keys`

Stores correct answers in an isolated directory. Document ID matches the `{quizId}` from
`databases`.

### Document Fields

| Field        | Type         | Description                                                      |
|:-------------|:-------------|:-----------------------------------------------------------------|
| `quizId`     | `String`     | Foreign key to the parent quiz.                                  |
| `answerkeys` | `array<map>` | List of answer mappings: `[{ "q": "qUid", "a": "optUid" }, ...]` |
| `createdAt`  | `timestamp`  | Timestamp for tracking.                                          |

---

## 3. Collection: `responses`

Track user attempt history. Organized hierarchically for fast personal retrieval.

### Document Path: `responses/{userId}/attempts/{attemptId}`

| Field            | Type        | Description                                      |
|:-----------------|:------------|:-------------------------------------------------|
| `quizId`         | `String`    | Reference to the quiz document.                  |
| `userId`         | `String`    | UID of the user who took the quiz.               |
| `score`          | `number`    | Final calculated score (Correct: +4, Wrong: -1). |
| `totalQuestions` | `number`    | Number of questions in the quiz.                 |
| `answers`        | `map`       | User selections: `{ "qUid": ["optUid", ...] }`.  |
| `timestamp`      | `timestamp` | Server timestamp of the attempt.                 |

---

## 4. Collection: `all_attempts`

**The Flat Global Log.** Stores a replica of every attempt to facilitate cross-user reporting for
owners.

### Document Path: `all_attempts/{attemptId}`

Fields are identical to the hierarchical `responses` document.

---

## 5. Collection: `users`

Stores profile information and activity tracking.

### Document Fields (`users/{userId}`)

| Field        | Type        | Description                                |
|:-------------|:------------|:-------------------------------------------|
| `email`      | `String`    | Registered email address.                  |
| `name`       | `String`    | Display name.                              |
| `createdAt`  | `timestamp` | Account creation date.                     |
| `lastActive` | `timestamp` | Updated automatically on every submission. |

---

## Security Rules (Production)

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() { return request.auth != null; }
    function isCreator(quizId) {
      return request.auth.uid == get(/databases/$(database)/documents/databases/$(quizId)).data.creatorId;
    }

    match /users/{userId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() && request.auth.uid == userId;
    }

    match /databases/{quizId} {
      allow read: if resource.data.visibility == 'public' || 
                   (isAuthenticated() && request.auth.uid == resource.data.creatorId);
      allow create: if isAuthenticated();
      allow update, delete: if isAuthenticated() && request.auth.uid == resource.data.creatorId;
    }

    match /responses/{userId} {
      allow read, write: if isAuthenticated() && request.auth.uid == userId;
      match /attempts/{attemptId} {
        allow read, write: if isAuthenticated() && request.auth.uid == userId;
      }
    }

    match /answer_keys/{quizId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() && isCreator(quizId);
    }

    match /all_attempts/{attemptId} {
      allow read: if isAuthenticated() && (
        request.auth.uid == resource.data.userId || isCreator(resource.data.quizId)
      );
      allow create: if isAuthenticated() && request.auth.uid == request.resource.data.userId;
      allow update: if isAuthenticated() && request.auth.uid == resource.data.userId;
    }

    match /{path=**}/attempts/{attemptId} {
      allow read: if isAuthenticated() && isCreator(resource.data.quizId);
    }
  }
}
```
