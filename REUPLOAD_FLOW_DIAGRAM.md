# Reupload Feature - Complete Flow Diagram

## User Flow

```
Admin (Web Dashboard)                    Applicant (Flutter App)
================================        ================================

1. Reviews application
2. Finds issues in documents
3. Adds comment:
   "Please fix the ECC"                 → Comment shows instantly
4. Sets reuploadAllowed: true           → Submit button turns GREEN & ENABLED
5. User sees notification               ← Green notification shows
   "You can re-upload now"              ← Button text changes
                                        ↓
                                        Applicant reads comment
                                        Fixes documents
                                        Clicks Submit (enabled)
                                        → Uploads corrected files
                                        ↓
                                        Admin reviews again
                                        ...
```

## Firestore Collection Structure

```
applications/
├── pltp/
│   ├── (summary doc fields)
│   │   └── uploadedCount: 5
│   │       lastUpdated: timestamp
│   │
│   └── applicants/
│       └── applicantId_123
│           ├── applicantName: "John Doe"
│           ├── uploadedAt: timestamp
│           ├── reuploadAllowed: false          ← ✅ Admin controls this
│           ├── lastCommentAt: timestamp
│           │
│           └── comments/ (subcollection)
│               ├── comment1_doc
│               │   ├── message: "Please fix the ECC"
│               │   ├── from: "Admin"
│               │   └── createdAt: timestamp
│               │
│               └── comment2_doc
│                   ├── message: "Document incomplete"
│                   ├── from: "Admin"
│                   └── createdAt: timestamp
│
├── splt/
│   └── applicants/
│       └── (same structure)
│
├── spltp/
│   └── applicants/
│       └── (same structure)
│
└── ctpo/
    └── applicants/
        └── (same structure)
```

## UI States

### State 1: Initial Submission (No Comments Yet)
```
┌─────────────────────────────────────────┐
│  PLTP Application Form                  │
├─────────────────────────────────────────┤
│                                         │
│  [Form fields...]                       │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │      [GREEN] SUBMIT               │  │
│  │    (Upload All Files)             │  │
│  └─────────────────────────────────────┘│
│                                         │
└─────────────────────────────────────────┘
```

### State 2: Admin Added Comments, Waiting for Reupload
```
┌─────────────────────────────────────────┐
│  PLTP Application Form                  │
├─────────────────────────────────────────┤
│ 💬 Admin Comments                       │
│ ┌───────────────────────────────────────┤
│ │ "Please fix the ECC document"         │
│ │ From: Admin • 11/5/2025 2:30 PM      │
│ └───────────────────────────────────────┤
│                                         │
│ ❌ You cannot re-upload files yet.     │
│    Please wait for admin approval.     │
│                                         │
│  [Form fields...]                       │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │      [GREY] SUBMIT                │  │
│  │  (Disabled - Waiting for Approval) │  │
│  └─────────────────────────────────────┘│
│                                         │
└─────────────────────────────────────────┘
```

### State 3: Admin Approved Reupload, Button Enabled
```
┌─────────────────────────────────────────┐
│  PLTP Application Form                  │
├─────────────────────────────────────────┤
│ 💬 Admin Comments                       │
│ ┌───────────────────────────────────────┤
│ │ "Please fix the ECC document"         │
│ │ From: Admin • 11/5/2025 2:30 PM      │
│ └───────────────────────────────────────┤
│                                         │
│ ✅ You can re-upload files now.        │
│    Please correct the issues above.    │
│                                         │
│  [Form fields...]                       │
│  [Now applicant can select new files]   │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │      [GREEN] SUBMIT               │  │
│  │    (Upload All Files)             │  │
│  └─────────────────────────────────────┘│
│                                         │
└─────────────────────────────────────────┘
```

## Admin Side - Setting reuploadAllowed

In admin web dashboard:

```javascript
// When adding comment
await addDoc(applicantRef.collection('comments'), {
  message: "Please update your ECC",
  from: "Admin",
  createdAt: serverTimestamp(),
  reuploadAllowed: true  // ✅ Enable reupload
});

// Update applicant document too
await setDoc(applicantRef, {
  reuploadAllowed: true,    // ✅ Flag is here
  lastCommentAt: serverTimestamp()
}, { merge: true });
```

## Flutter Side - Reading reuploadAllowed

```dart
// Load from Firestore
final snapshot = await FirebaseFirestore.instance
    .collection('applications')
    .doc('pltp')
    .collection('applicants')
    .doc(applicantId)
    .get();

final reuploadAllowed = snapshot.data()?['reuploadAllowed'] as bool? ?? false;

// Use to control button
ElevatedButton(
  onPressed: reuploadAllowed ? handleSubmit : null,  // ← Disabled if false
  style: ElevatedButton.styleFrom(
    backgroundColor: reuploadAllowed ? Colors.green : Colors.grey,
  ),
)
```

## Key Logic Conditions

| Scenario | `_adminComments.isEmpty` | `_reuploadAllowed` | Button State | Color |
|----------|------------------------|------------------|--------------|-------|
| Initial (no comments) | ✅ true | - | ENABLED | GREEN |
| Admin commented, waiting | ❌ false | false | DISABLED | GREY |
| Admin approved reupload | ❌ false | true | ENABLED | GREEN |
| After upload, no new comment | ✅ true | - | ENABLED | GREEN |

## Code Logic

```dart
// Determine if button should be disabled
bool isButtonDisabled = _isUploading || 
                        (!_reuploadAllowed && _adminComments.isNotEmpty);

// Determine button color
Color buttonColor = (_reuploadAllowed || _adminComments.isEmpty) 
                    ? Colors.green[700] 
                    : Colors.grey[400];

// Determine button text
String buttonText = (_reuploadAllowed || _adminComments.isEmpty)
                    ? 'Submit (Upload All Files)'
                    : 'Submit Disabled - Waiting for Approval';
```

## Implementation Checklist for Each Application Type

### ✅ PLTP (Completed)
- [x] Add state variables
- [x] Add load methods
- [x] Update initState
- [x] Update build UI
- [x] Update submit button

### 🔄 SPLT (In Progress)
- [x] Add state variables
- [x] Add load methods
- [x] Update initState
- [ ] Update build UI (still needed)
- [ ] Update submit button (still needed)

### ⏳ CTPO (Not Started)
- [ ] Add state variables
- [ ] Add load methods
- [ ] Update initState
- [ ] Update build UI
- [ ] Update submit button

## Testing Scenarios

### Scenario 1: First-time upload
1. Applicant opens form
2. `_adminComments` is empty → Button GREEN ✅
3. Applicant uploads files
4. Button shows success ✅

### Scenario 2: Admin rejects, requests changes
1. Admin adds comment "Fix ECC"
2. Admin sets `reuploadAllowed: false`
3. Applicant sees comment → Button GREY ❌
4. Applicant waits...

### Scenario 3: Admin approves reupload
1. Admin changes `reuploadAllowed: true`
2. Applicant sees → Button GREEN ✅
3. Applicant uploads new files
4. Cycle repeats if needed...

### Scenario 4: Multiple comments
1. Admin adds comment 1: "Fix ECC"
2. Admin adds comment 2: "Update location"
3. Both comments show in chronological order
4. `reuploadAllowed` controls button state
5. Applicant fixes and reuploads

## Real-Time vs Polling

### Current Implementation (Polling)
- Load on page init
- User sees updates when opening page
- Simple implementation ✅

### Optional Enhancement (Streaming)
```dart
// Real-time listener
FirebaseFirestore.instance
    .collection('applications')
    .doc('pltp')
    .collection('applicants')
    .doc(applicantId)
    .snapshots()
    .listen((doc) {
        final reuploadAllowed = doc['reuploadAllowed'];
        setState(() { _reuploadAllowed = reuploadAllowed; });
    });
```
- Updates instantly as admin changes
- User sees changes without refreshing
- More complex but better UX ✨

## Error Handling

```dart
try {
  // Load from Firestore
  final snapshot = await ref.get();
  if (snapshot.exists) {
    // Process data
  }
} catch (e) {
  print("Error loading reupload status: $e");
  // Default: button disabled, safe fallback
  _reuploadAllowed = false;
}
```

- If load fails, button stays disabled (safe)
- Errors logged to console
- App doesn't crash ✅
