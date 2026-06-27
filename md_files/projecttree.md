# Project Data Tree Structure

### 🛡️ Admin Permissions & Roles

Admin permissions are stored as a Map of booleans in the `admins` collection:
`permissions: { "permission_key": true/false }`

| Key                    | UI Label                  | Required For                                            |
|:-----------------------|:--------------------------|:--------------------------------------------------------|
| `manage_admins`        | Manage App Admins         | Managing admins, levels, and `settings/admin`           |
| `moderate_users`       | Global User Moderation    | Banning users, editing user docs, deleting any response |
| `manage_all_quizzes`   | Master Quiz Control       | Global CRUD for all quizzes, questions, and keys        |
| `view_audit_logs`      | View Audit Logs           | Reading the `audit_logs` collection                     |
| `manage_app_settings`  | Manage App Settings       | Editing `feature_flags/public` and `settings/app`       |
| `bypass_ai_quotas`     | Bypass AI Quotas          | Bypassing platform-wide AI generation limits            |
| `manage_collaborators` | Manage Quiz Collaborators | Managing quiz-level access (`quiz_access`)              |

### ⚙️ Settings & Feature Flags (Granular Isolation)

/feature_flags/
├── public (Doc) - [Read: All, Write: `manage_app_settings`]
│ ├── enable_ai: true
│ ├── enable_import: true
│ ├── enable_login: true
│ ├── enable_register: true
│ ├── enable_create_quiz: true
│ ├── enable_edit_quiz: true
│ ├── enable_delete_quiz: true
│ ├── enable_take_quiz: true
│ ├── enable_profile_edit: true
│ ├── enable_analytics: true
│ ├── enable_export: true
│ ├── maintenance_mode: false
│ └── random_quiz_generator: true
├── admin (Doc) - [Read: Admin, Write: `manage_admins`]
│ └── admin_refresh_rate_limit_seconds: 30
├── moderation (Doc) - [Read: Admin, Write: `moderate_users`]
│ └── enable_user_banning: true
├── ai (Doc) - [Read: Admin, Write: `bypass_ai_quotas`]
│ ├── enable_ai_quota_bypass: false
│ └── ai_daily_generation_limit: 10
├── quizzes (Doc) - [Read: Admin, Write: `manage_all_quizzes`]
│ ├── enable_quiz_creation_rate_limit: true
│ ├── enable_form_save_rate_limit: true
│ ├── form_save_rate_limit_seconds: 30
│ └── quiz_creation_rate_limit_minutes: 5
├── logs (Doc) - [Read: Admin, Write: `view_audit_logs`]
│ ├── log: true
│ └── log_updates: true
└── collaboration (Doc) - [Read: Admin, Write: `manage_collaborators`]
└── enable_realtime_colab: true

/settings/
├── app (Doc) - [Read: All, Write: `manage_app_settings`]
├── exam_configs (Doc) - [Read: All, Write: `manage_app_settings`]
├── admin (Doc) - [Read: Admin, Write: `manage_admins`]
│ ├── super_admin_level: 10
│ └── min_level_to_manage_admins: 5
└── ai (Doc) - [Read: Admin, Write: `bypass_ai_quotas`]
└── ai_daily_generation_limit: 10

### 📝 Quizzes & Content

/quizzes/
└── {quizId} (Document)
├── creatorId: "{userId}"
├── clientToken: "{uuid}"
├── user: "Creator Name"
├── title: "Physics Mock"
├── titleLower: "physics mock"
├── description: "Complete physics mock for JEE"
├── tags: ["Physics", "JEE Main"]
├── visibility: "public" | "private"
├── time: 3600 (seconds)
├── perQuestionTime: 60 (seconds)
├── allowMultipleAttempts: true
├── completeRandomShuffle: false
├── markingScheme: { "type": "default" | "per_question", "perQuestion": { "qUid": { "correct": 4, "
wrong": -1 } } }
├── attemptLimits: { "type": "none" | "daily" | "total", "count": 3 }
├── createdAt: ServerTimestamp
├── updatedAt: ServerTimestamp
├── activeAt: Timestamp | null
├── isRestricted: false
├── allowedParticipants: ["{userId_A}", "{userId_B}"]
├── isPersonal: false
├── isAiGenerated: false
├── totalQuestions: 30
├── moduleCount: 3
├── markingType: "default"
├── attemptLimitType: "none"
├── isDeleted: false
├── moduleTags: { "General": ["physics"], "Mechanics": ["rotation"] }
├── examTag: "JEE Main"
├── deletedBy: "{userId}"
├── deletedByType: "owner" | "manager" | "admin"
└── deletedAt: Timestamp

/quiz_questions/
└── {quizId} (Document)
└── modules: [
{
"subject": "Physics",
"data": [
{
"uid": "q_123",
"type": "Single Choice",
"timer": 0,
"Q": { "id": "q_123", "text": "Question text?" },
"As": [ { "id": "opt_1", "text": "Choice A" } ]
}
]
}
]

/answer_keys/
└── {quizId} (Document)
└── answerkeys: [ { "q": "q_123", "a": "opt_1", "s": "Explanation text" } ]

/reports/
└── {reportId} (Document)
├── quizId: "{quizId}"
├── reportedBy: "{userId}"
├── reason: "Offensive" | "Incorrect" | "Spam"
├── description: "Detailed reason"
├── status: "pending" | "reviewed" | "resolved"
└── createdAt: ServerTimestamp

### 🏷️ Discovery & Access

/tags/
└── {tagId} (e.g., "physics")
├── name: "physics"
├── lastUsed: ServerTimestamp
├── quizIds: ["quiz_A", "quiz_B"]
└── moduleNames: ["General", "Mechanics"]

/module_tags/
└── {docId} ({quizId}_{module}_{tagId})
├── tag: "physics"
├── moduleName: "General"
├── quizId: "{quizId}"
└── syncedAt: ServerTimestamp

/quiz_access/
└── {quizId}_{userId} (Document)
├── quizId: "{quizId}"
├── userId: "{userId}"
├── addedBy: "{adminId}"
├── role: "manager" | "participant"
├── permissions: { "can_update": true, "can_moderate": true, ... }
└── updatedAt: ServerTimestamp

/banned_users/
└── {banId} (global_{userId} or {quizId}_{userId})
├── userId: "{userId}"
├── quizId: "{quizId}" | null
├── reason: "Cheating"
├── bannedBy: "{adminId}"
└── createdAt: ServerTimestamp

### 👤 Users & Activity

/users/
└── {userId} (Document)
├── name: "User Name"
├── photoUrl: "url"
├── lastQuizCreatedAt: Timestamp
├── lastQuizUpdatedAt: Timestamp
├── quizCount: 5
├── attemptCount: 12
└── createdAt: ServerTimestamp

/responses/
└── {responseId} (Document)
├── quizId: "{quizId}"
├── userId: "{userId}"
├── score: 85
├── answers: { "q_123": "opt_1" }
├── startTime: Timestamp
├── endTime: Timestamp
├── timeTaken: 300 (seconds)
├── isDeleted: false
├── deleteReason: "Invalid entry"
├── deletedBy: "{adminId}"
└── deletedByType: "owner" | "admin"

/quiz_attempts/
└── {quizId} (Document)
└── attempts (Collection)
└── {responseId} (Document) [Mirror of /responses/]

/audit_logs/
└── {logId} (Document)
├── actorId: "{userId}"
├── action: "update_quiz"
├── targetId: "{quizId}"
├── details: "Updated title and tags"
├── category: "quiz" | "admin" | "moderation"
└── timestamp: ServerTimestamp
