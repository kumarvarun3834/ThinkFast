# ThinkFast API Technical Reference (v1)

This document provides a comprehensive technical specification for the ThinkFast backend API.

## 1. Global Configuration

*   **Base URL**: `https://thinkfast.ai.studio/api/v1`
*   **Content-Type**: `application/json`

### Security Headers (Required for all restricted endpoints)
| Header | Value | Description |
| :--- | :--- | :--- |
| `Authorization` | `Bearer <Firebase_ID_Token>` | Standard Firebase Authentication JWT. |
| `X-Firebase-AppCheck` | `<App_Check_Token>` | Device attestation token for anti-abuse. |

---

## 2. System & Configuration

### `GET /config/version`
Checks for mandatory app updates.
*   **Response (200)**:
    ```json
    {
      "min_supported_version": "1.0.0",
      "latest_version": "1.1.2",
      "update_url": "https://play.google.com/..."
    }
    ```

### `GET /health`
*   **Response (200)**:
    ```json
    {
      "status": "healthy",
      "uptime": 86400,
      "worker_status": "idle",
      "memory_usage": "256MB"
    }
    ```

---

## 3. 🤖 Type 1: AI Generated Quizzes & Analysis

### `POST /quiz/generate`
Consolidated endpoint for all generation workflows.
*   **Payload Envelope**:
    ```json
    {
      "source": "prompt" | "file" | "wizard",
      "isPersonal": boolean,
      "tags": ["physics", "math"],
      "examTag": "JEE Main",
      "input": { 
        "system": { "role": "...", "instructions": [...] },
        "user": { "uid": "...", "persona": { ... } },
        "request": { "user_input": "...", "config": { ... } }
      },
      "fileUrl": "https://supabase.co/...", // Optional: Context file from Supabase
      "fileName": "document.pdf",           // Optional
      "fileType": "pdf" | "doc" | "docx"    // Optional
    }
    ```
*   **Response (202 Accepted)**:
    ```json
    {
      "quizId": "generated_uuid",
      "status": "queued",
      "estimated_wait_seconds": 30
    }
    ```

### `GET /quiz/status/:id`
Polls the background worker state.
*   **Response (200)**:
    ```json
    {
      "id": "generated_uuid",
      "status": "queued" | "generating" | "validating" | "saving" | "completed" | "failed",
      "progress": 75,
      "message": "Generating professional distractors...",
      "error": null
    }
    ```

### `POST /quiz/analyze`
Triggers LLM-driven performance evaluation and profile updates.
*   **Payload**:
    ```json
    {
      "quizId": "quiz_uuid",
      "responseId": "attempt_uuid"
    }
    ```
*   **Response (200)**:
    ```json
    {
      "analysisId": "explanation_uuid",
      "insights": "Great job on Newton's laws, but review friction.",
      "profileUpdated": true
    }
    ```

---

## 4. 📥 Type 2: User Generated Direct (Bulk)

### `POST /admin/database/import-workspace`
Administrative bulk import of template quizzes.
*   **Payload**:
    ```json
    {
      "workspaceId": "default_templates",
      "overwriteExisting": false
    }
    ```
*   **Response (200)**:
    ```json
    {
      "importedCount": 15,
      "status": "success"
    }
    ```

---

## 5. ⚙️ Administrative Actions

### `POST /admin/database/:action`
*   **Actions**:
    *   `reset`: `{ "confirm": "YES_DELETE_ALL" }` - Reverts to seed data.
    *   `simulate-client-write`: `{ "collection": "...", "data": { ... } }` - Tests security rules.

### `POST /admin/system/:action`
*   **Actions**:
    *   `process-queue`: Manually flushes the AI generation queue.
    *   `reset-metrics`: Clears server latency and LLM usage benchmarks.

---

## 6. Security Hardening Envelope
Note: The Flutter `ApiClient` wraps the `quizRequest` in a security envelope before sending to the backend:
```json
{
  "firebaseIdToken": "...",
  "appCheckToken": "...",
  "deviceId": "...",
  "appVersion": "...",
  "uuid": "...",
  "email": "...",
  "name": "...",
  "quizRequest": { /* Actual endpoint payload here */ }
}
```

---

> [!NOTE]
> **Audit Logs** and **Global Settings** (Feature Flags) are managed **internally** by the app via direct Firestore integration and are **not exposed** as API endpoints. 
> The app views these resources directly from the `/audit_logs`, `/settings`, and `/feature_flags` collections.
