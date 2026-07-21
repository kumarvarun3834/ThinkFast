# ThinkFast Robo-Testing Checklist

## 👑 Superadmin (Emu1 - 5554)
- [ ] Create a Public Quiz manually
- [ ] Toggle Feature Flags (e.g., disable quiz taking)
- [ ] Ban user from a specific quiz
- [ ] Ban user globally from the app
- [ ] Soft delete a quiz
- [ ] Restore a quiz from Recycle Bin
- [ ] Manage App Admins (Promote/Demote)

## 👤 Normal Users (Emu2 - 5556, Emu3 - 5558)
- [ ] Search and Join a Public Quiz
- [ ] Attempt a Quiz (Multiple types: Single, Multiple, Integer)
- [ ] View Attempt history
- [ ] Soft delete an attempt from history
- [ ] Verify Quiz-level ban prevents entry
- [ ] Verify Global App ban shows "ACCESS DENIED" screen

## 🤖 AI & Privacy (NEW)
- [ ] Generate quiz without personalization -> Verify `persona` stripped from payload
- [ ] Generate quiz with personalization -> Verify reasoning insight appears
- [ ] Attempt "starred ⭐" item without policy -> Verify dialog block
- [ ] Submit quiz with personalization -> Verify evaluation exists in `/explanation`
- [ ] Filter by "AI Only" -> Verify manual quizzes disappear
- [ ] Update AI quiz via API -> Verify tag added and flag removed

## 🛠️ System Stability
- [ ] Maintenance Mode prevents non-admin access
- [ ] Audit Logs track admin actions
- [ ] Real-time updates for feature flags
- [ ] Safe parsing of mixed timestamp types (String/DateTime)
