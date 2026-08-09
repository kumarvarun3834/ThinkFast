# Proposed Backend API Consolidation Plan (Refined)

Reduce the backend surface area by removing all endpoints for actions that can be performed directly by the Flutter frontend using the Firebase SDK (Auth & Firestore). The backend will focus exclusively on AI processing, quota enforcement, and restricted administrative tasks.

## 🚫 1. Endpoints to REMOVE (Frontend can handle)
The following functionality will be handled directly via the Firebase SDK on the client:
- **Auth**: Login/Logout (already implemented via `FirebaseAuth`).
- **Profiles**: Fetching/Updating user profile data (`FirebaseFirestore`).
- **Manual CRUD**: Create, read, and update manual (non-AI) quizzes.
- **Notifications**: Reading and marking alerts as "read".
- **Discovery**: Querying active/scheduled quizzes from Firestore.

## 🤖 2. Consolidated AI Orchestrator
Focus the backend only on AI-heavy or security-locked tasks.

#### [NEW] `POST /api/quizzes`
Handles all generation workflows. Requires secret API keys.
- **Payload**:
  ```json
  {
    "type": "ai_text" | "ai_pdf" | "wizard",
    "config": { ... }, // Subject, topic, difficulty, isPersonal
    "input": "..." // Text prompt or PDF base64
  }
  ```

#### [MODIFY] `GET /api/quizzes/:id`
Only for checking **real-time generation status** before the document exists in Firestore. Once the quiz is in Firestore, the frontend reads it directly.

#### [MODIFY] `PATCH /api/quizzes/:id`
Securely update AI-generated quizzes. Since these are write-locked for users in Firestore, the backend uses the Admin SDK to modify them or "unlock" them (by stripping the `isAiGenerated` flag).

### 🎯 3. Interaction & Analysis
#### [NEW] `POST /api/quizzes/:id/actions`
Handles actions that require AI or write-locked collections.
- **Payload**:
  ```json
  {
    "action": "analyze", // Triggers AI Attempt Analysis and writes to /explanation
    "data": { "responseId": "..." }
  }
  ```

### ⚙️ 4. Administrative Gateway
Bulk tasks requiring Admin SDK or SMTP keys.

#### [NEW] `POST /api/admin/tasks`
- **Payload**:
  ```json
  {
    "task": "flush_queue" | "reset_db" | "send_email",
    "params": { ... }
  }
  ```

## Summary of Reduction

| Component | Status | New Path | Reason for Keeping |
| :--- | :--- | :--- | :--- |
| **AI Generation** | Consolidated | `POST /api/quizzes` | Secret Keys / Compute |
| **PDF Extraction** | Consolidated | `POST /api/quizzes` | Specialized Libs / Heavy |
| **AI Analysis** | Consolidated | `POST /api/quizzes/:id/actions` | Secret Keys / Write Lock |
| **Admin Resets** | Consolidated | `POST /api/admin/tasks` | Admin SDK Required |
| **Email Dispatch**| Consolidated | `POST /api/admin/tasks` | SMTP Credentials |
| **CRUD / Auth** | **REMOVED** | - | Handled by Firebase SDK |

## Verification Plan

### Manual Verification
- Verify `AiService.dart` refactoring: Ensure it uses `FirebaseFirestore` for simple reads/updates and calls the new API only for generation and analysis.
- Check security rules: Ensure the backend still enforces quota updates in `user_usage` during generation calls.
