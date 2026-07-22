# AI Quiz Generation Workflow - ThinkFast

This document outlines the end-to-end process of generating a quiz using the **AI Quiz Wizard**.

## 1. User Interface Flow (Conversational Setup)

The generation process begins in the `AiQuizGenerator` screen, which utilizes a chat-like interface to gather requirements from the user.

1.  **Entry Point**: User navigates to **AI Quiz Wizard** from the Sidebar Menu.
2.  **Step-by-Step Configuration**: The UI guides the user through several stages by asking specific questions:
    *   **Exam Context**: "Are you preparing for a specific competitive exam?"
    *   **Topic Definition**: "What topic would you like to study today?"
    *   **Subtopic Precision**: "Which specific areas should I focus on?"
    *   **Volume**: "How many questions would you like? (Recommended: 1-50)"
    *   **Exclusions**: "Are there any topics I should avoid?"
    *   **Difficulty**: "How challenging should the quiz be?"
    *   **Distractor Styling**: "What style of distractors (wrong answers) do you prefer?"
    *   **Cognitive Level**: "What cognitive level should we target?" (Recall, Understanding, Application, etc.)
    *   **User Proficiency**: "What is your current skill level in this topic?"
    *   **Question Types**: "What type of questions do you prefer?" (Single/Multiple/Integer/Mixed)
    *   **Explanations**: "Would you like hints and explanations included?"
    *   **Tone**: "What should be the tone of the quiz?" (Professional, Casual, Encouraging, Strict)
    *   **Feedback Timing**: "When would you like to see the feedback?"
    *   **Timing**: "Should there be a time limit?"
    *   **Syllabus Coverage**: "What should this quiz focus on?" (Entire syllabus, Weak topics, Revision, etc.)
    *   **Sourcing**: "Where should I source the questions from?" (Textbook style, Competitive style, etc.)
    *   **Adaptivity**: The wizard clarifies that generation is **Profile-Based** rather than real-time adaptive. It uses the learner's performance history to target the right level:
        *   **New User / Weak Performance**: Mostly Easy questions.
        *   **Average Performer**: Mix of Easy + Medium.
        *   **Strong Performer**: Mix of Medium + Hard.
        *   **Top Performer**: Hard + Challenge-level questions.
        *   **Growth Check**: Every quiz includes random "wildcard" questions (Easy, Medium, or Hard) regardless of profile to track progress.
    *   **Personalization**: "Would you like to focus on topics you've struggled with before?"
3.  **Profile Review**: Before finalization, the wizard fetches the user's profile and analytics to add a deep layer of personalization:
    *   **Performance Metrics**: Average score %, Accuracy by topic, and Rank/Percentile.
    *   **Behavioral Data**: Time spent per question and previous attempt frequency.
    *   **Personalization Logic Example**:
        *   Topic (e.g. Arrays) Accuracy = 42% → Generate: 70% Easy, 25% Medium, 5% Hard.
        *   Topic (e.g. Arrays) Accuracy = 91% → Generate: 20% Medium, 60% Hard, 20% Challenge.
4.  **Final Submission**: The user reviews the combined settings and chooses whether to sync these preferences back to their profile before triggering generation.

---

## 2. Backend Orchestration (`AiService`)

Once the user hits "Generate Quiz", the `AiService` initiates a **Background Generation Task**.

### 2.1 Pre-flight Checks & Task Queuing
*   **Feature Flag Check**: Verifies if AI generation is globally enabled.
*   **Quota Management**: Checks the `user_usage` collection to see if the user has remaining daily generations.
*   **Asynchronous Response**: Instead of waiting for the LLM, the server immediately returns a `status: "queued"` response with a unique `quizId`.
*   **Immediate Redirection**: The app UI receives this `quizId` and immediately navigates the user to the **AI Generation Status** screen.

### 2.2 Background Processing
The actual LLM call and database persistence occur in the background:
*   **Worker Logic**: A specialized worker processes the `quiz_queue`.
*   **Validation Pipeline**: Strict verification against the ThinkFast Quiz Schema (Type checks, array bounds).
*   **Batch Write**: Questions, Metadata, and Answer Keys are written to Firestore as an atomic batch.

### 2.3 Status Tracking (UX)
The `AiGenerationStatusScreen` implements a **Hybrid Tracking** logic:
1.  **Firestore Stream**: Listens for real-time updates once the document is created.
2.  **API Polling**: Calls `GET /api/quiz-status/:id` to check the server's memory state if the document isn't in Firestore yet.
3.  **Real-time Traces**: Shows live backend logs (TraceID) for visibility into validation and security steps.

---

## 3. Data Processing & Ingestion

### 3.1 Metadata Tracking
Every generation stores technical metadata for analytics and debugging:
*   `model`: The AI model version used.
*   `generationTimeMs`: Time taken to generate and validate.
*   `tokenUsage`: Total tokens consumed.

### 3.2 Database Creation
`DatabaseService.createDatabase` is called to perform a batch write to Firestore (Metadata, Questions, and Answer Keys).

### 3.3 Status Tracking (UX)
For a smooth experience, the generation state is tracked and displayed via the **Generation Status Screen**:
`Queued` → `Generating` → `Validating` → `Saving` → `Completed`.

Users can also manually track a status using a **Quiz ID** if they disconnect during the process.

---

## 4. Completion
Upon successful creation, the app automatically navigates the user to the **Quiz Details Screen**.
