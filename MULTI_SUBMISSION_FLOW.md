# Multi-Submission Application Flow Documentation

## Overview

The TreeSure application now supports **multiple submissions per applicant** for all application types. This allows applicants to submit multiple applications of the same type (e.g., multiple CTPO applications, multiple PTC applications) while keeping each submission independent and trackable.

---

## Supported Application Types

All five application types now support multiple submissions:

1. **CTPO** - Certificate Tree Plantation Owner
2. **PTC** - Permit to Cut / Issuance of Tree Cutting Permit
3. **PLTP** - Private Land Timber Permit
4. **SPLT** - Special Private Land Timber Permit
5. **Chainsaw Registration**
6. **COV** - Certificate of Verification

---

## Firebase Structure

### Old Structure (Single Submission)
```
applications
  └── {type}
      └── applicants
          └── {applicantId}
              ├── applicantName: "John Doe"
              ├── uploadedAt: timestamp
              ├── uploadedCount: 1
              └── uploads (subcollection)
                  └── {documentTitle}
                      ├── url: "..."
                      ├── fileName: "..."
                      ├── uploadedAt: timestamp
                      └── comments (subcollection)
```

### New Structure (Multiple Submissions)
```
applications
  └── {type}
      └── applicants
          └── {applicantId}
              ├── applicantName: "John Doe"
              ├── submissionsCount: 3
              ├── lastUpdated: timestamp
              └── submissions (subcollection)
                  ├── {TYPE}-{applicantId}-001
                  │   ├── applicantName: "John Doe"
                  │   ├── status: "submitted" | "draft"
                  │   ├── createdAt: timestamp
                  │   ├── submittedAt: timestamp
                  │   ├── lastUpdated: timestamp
                  │   └── uploads (subcollection)
                  │       └── {documentTitle}
                  │           ├── url: "..."
                  │           ├── fileName: "..."
                  │           ├── uploadedAt: timestamp
                  │           ├── reuploadAllowed: false
                  │           └── comments (subcollection)
                  │               └── {commentId}
                  │                   ├── message: "..."
                  │                   ├── from: "Admin Name"
                  │                   ├── createdAt: timestamp
                  │
                  ├── {TYPE}-{applicantId}-002
                  │   └── (same structure)
                  │
                  └── {TYPE}-{applicantId}-003
                      └── (same structure)
```

---

## Submission ID Format

Each submission is assigned a unique ID in the format:

```
{TYPE}-{applicantId}-{count}
```

### Examples:
- **CTPO**: `CTPO-004-001`, `CTPO-004-002`, `CTPO-004-003`
- **PTC**: `PTC-004-001`, `PTC-004-002`
- **PLTP**: `PLTP-004-001`, `PLTP-004-002`
- **SPLT**: `SPLT-004-001`, `SPLT-004-002`
- **CHAINSAW**: `CHAINSAW-004-001`, `CHAINSAW-004-002`
- **COV**: `COV-004-001`, `COV-004-002`

Where:
- `{TYPE}` = Application type (CTPO, PTC, PLTP, SPLT, CHAINSAW, COV)
- `{applicantId}` = Unique applicant identifier (e.g., "004")
- `{count}` = Sequential number padded to 3 digits (001, 002, 003, etc.)

---

## Applicant User Flow

### 1. Opening Application Page

When an applicant opens any application upload page:

1. **System checks for existing submissions**
   - Queries: `applications/{type}/applicants/{applicantId}/submissions`
   - Orders by `createdAt` (most recent first)

2. **If no submissions exist:**
   - Automatically creates first submission: `{TYPE}-{applicantId}-001`
   - Sets status to `draft`

3. **If submissions exist:**
   - Loads all submissions with their metadata
   - Automatically selects the most recent submission
   - Displays submission selector UI

### 2. Submission Selector UI

The submission selector appears at the top of every application page:

```
┌─────────────────────────────────────────────────────┐
│  📁 Your Submissions                    [+ New]     │
├─────────────────────────────────────────────────────┤
│  Select Submission: [CTPO-004-002 (5 files) ▼]    │
│                                                     │
│  Status indicators:                                 │
│  ✓ Green checkmark = Submitted                    │
│  📝 Orange pencil = Draft                          │
└─────────────────────────────────────────────────────┘
```

**Features:**
- **Dropdown**: Shows all submissions for the applicant
  - Format: `{submissionId} ({uploadCount} files)`
  - Visual status indicator (✓ submitted / 📝 draft)
- **New Button**: Creates a new submission
- **Auto-select**: Most recent submission selected by default

### 3. Creating a New Submission

When applicant clicks **"New"** button:

1. System queries existing submissions to get count
2. Generates new submission ID: `{TYPE}-{applicantId}-{nextNumber}`
3. Creates document in Firebase:
   ```javascript
   {
     applicantName: "John Doe",
     status: "draft",
     createdAt: serverTimestamp()
   }
   ```
4. Reloads submission list
5. Switches to the new submission
6. Shows success message: "New submission created: {submissionId}"

### 4. Switching Between Submissions

When applicant selects a different submission from dropdown:

1. System updates current submission ID
2. Clears local file selection state
3. Loads existing uploads for selected submission
4. Loads document comments for selected submission
5. Updates UI to show selected submission's data

### 5. Uploading Files

When applicant uploads files:

1. **Validation**: Checks if submission is selected
2. **Upload to Storage**: `{type}_uploads/{timestamp}_{filename}`
3. **Save metadata to**:
   - User's personal collection: `users/{applicantId}/{type}_uploads/{documentTitle}`
   - Submission uploads: `applications/{type}/applicants/{applicantId}/submissions/{submissionId}/uploads/{documentTitle}`
4. **Update submission document**:
   ```javascript
   {
     uploads.{documentTitle}.reuploadAllowed: false,
     lastUpdated: serverTimestamp()
   }
   ```

### 6. Submitting Application

When applicant clicks **"Submit All Files"**:

1. **Validation**: Ensures submission is selected
2. **Uploads all pending files** (files selected but not yet uploaded)
3. **Updates submission status**:
   ```javascript
   {
     status: "submitted",
     submittedAt: serverTimestamp(),
     uploads.{documentTitle}.reuploadAllowed: false (for each uploaded file)
   }
   ```
4. **Updates applicant document**:
   ```javascript
   {
     submissionsCount: {total number of submissions},
     lastUpdated: serverTimestamp()
   }
   ```
5. Shows success message

---

## Admin Side Implications

### 1. Viewing Applications

**Old Way:**
- Navigate to: `applications/{type}/applicants/{applicantId}/uploads`
- View single set of uploads

**New Way:**
- Navigate to: `applications/{type}/applicants/{applicantId}`
- Check `submissionsCount` to see total submissions
- Navigate to: `applications/{type}/applicants/{applicantId}/submissions`
- List all submissions with their IDs and statuses
- Select specific submission to view its uploads

### 2. Admin Dashboard Queries

To get all submissions across all applicants:

```javascript
// Get all submissions for a specific application type
const submissionsSnapshot = await firestore
  .collectionGroup('submissions')
  .where('status', '==', 'submitted')
  .get();

// Filter by application type in code (since collectionGroup doesn't support parent filtering)
const ctpoSubmissions = submissionsSnapshot.docs.filter(doc => 
  doc.ref.path.includes('applications/ctpo/')
);
```

### 3. Reviewing Individual Submissions

For each submission, admin can access:

```
applications/{type}/applicants/{applicantId}/submissions/{submissionId}/
  ├── applicantName
  ├── status (draft/submitted)
  ├── createdAt
  ├── submittedAt
  └── uploads/{documentTitle}
      ├── url
      ├── fileName
      ├── uploadedAt
      ├── reuploadAllowed (set by admin)
      └── comments/{commentId}
          ├── message
          ├── from
          └── createdAt
```

### 4. Adding Comments

Admin adds comments to specific documents within a submission:

**Path**: `applications/{type}/applicants/{applicantId}/submissions/{submissionId}/uploads/{documentTitle}/comments/{commentId}`

**Document structure**:
```javascript
{
  message: "Please reupload with clearer image",
  from: "Admin Name",
  createdAt: serverTimestamp()
}
```

**Set reupload permission**:
```javascript
// Update the upload document
applications/{type}/applicants/{applicantId}/submissions/{submissionId}/uploads/{documentTitle}
{
  reuploadAllowed: true
}
```

### 5. Tracking Submission History

Each submission maintains its own timeline:

- **createdAt**: When applicant created the submission
- **submittedAt**: When applicant submitted all files
- **lastUpdated**: Last modification timestamp
- **status**: Current state (draft/submitted)

This allows admins to:
- See when each submission was created
- Track multiple applications from same applicant over time
- Identify draft vs. submitted applications
- Monitor resubmissions after document rejection

### 6. Summary Counts

**Applicant level** (`applications/{type}/applicants/{applicantId}`):
```javascript
{
  submissionsCount: 3  // Total submissions for this applicant
}
```

**Application type level** (to be implemented if needed):
```javascript
// Can aggregate across all applicants
applications/{type}/
{
  totalSubmissions: 45,
  totalApplicants: 15
}
```

---

## Key Differences from Old System

| Aspect | Old System | New System |
|--------|-----------|------------|
| **Submissions per applicant** | 1 | Unlimited |
| **Submission tracking** | None | Unique ID per submission |
| **Firebase path** | `uploads` subcollection | `submissions/{id}/uploads` |
| **Status tracking** | Document-level only | Submission-level + document-level |
| **Count field** | `uploadedCount` | `submissionsCount` |
| **UI** | Direct file upload | Submission selector + file upload |
| **Resubmissions** | Overwrite existing | Create new submission |

---

## Migration Considerations

### Existing Data

If there is existing data in the old structure (`applications/{type}/applicants/{applicantId}/uploads`), you may need to:

1. **Migration Script** to move old data:
   ```javascript
   // For each applicant with old structure
   const uploads = await applicantDoc.collection('uploads').get();
   
   // Create first submission
   const submissionId = `${TYPE}-${applicantId}-001`;
   await applicantDoc.collection('submissions').doc(submissionId).set({
     applicantName: applicantData.applicantName,
     status: 'submitted',
     createdAt: applicantData.uploadedAt || FieldValue.serverTimestamp(),
     submittedAt: applicantData.uploadedAt || FieldValue.serverTimestamp()
   });
   
   // Move uploads to first submission
   for (const uploadDoc of uploads.docs) {
     const uploadData = uploadDoc.data();
     await applicantDoc
       .collection('submissions')
       .doc(submissionId)
       .collection('uploads')
       .doc(uploadDoc.id)
       .set(uploadData);
   }
   
   // Update applicant document
   await applicantDoc.update({
     submissionsCount: 1,
     lastUpdated: FieldValue.serverTimestamp()
   });
   ```

2. **Backward Compatibility**: Keep old structure temporarily for reference

---

## Best Practices for Admin Implementation

### 1. List All Submissions
```javascript
// Get submissions for specific applicant and type
const submissionsRef = firestore
  .collection('applications')
  .doc(type)
  .collection('applicants')
  .doc(applicantId)
  .collection('submissions')
  .orderBy('createdAt', 'desc');

const snapshot = await submissionsRef.get();
const submissions = snapshot.docs.map(doc => ({
  id: doc.id,
  ...doc.data()
}));
```

### 2. Filter by Status
```javascript
// Get only submitted applications
const submittedRef = submissionsRef.where('status', '==', 'submitted');

// Get only draft applications
const draftRef = submissionsRef.where('status', '==', 'draft');
```

### 3. Display in Admin UI
```javascript
// For each submission, show:
- Submission ID (e.g., CTPO-004-001)
- Applicant Name
- Status badge (Submitted/Draft)
- Created Date
- Submitted Date (if applicable)
- Number of uploaded documents
- Action buttons (View, Review, Approve, Reject)
```

### 4. Review Submission Details
```javascript
// Get all uploads for a specific submission
const uploadsRef = firestore
  .collection('applications')
  .doc(type)
  .collection('applicants')
  .doc(applicantId)
  .collection('submissions')
  .doc(submissionId)
  .collection('uploads');

const uploadsSnapshot = await uploadsRef.get();
```

### 5. Add Review Comments
```javascript
// Add comment to specific document
const commentRef = uploadsRef
  .doc(documentTitle)
  .collection('comments')
  .doc();

await commentRef.set({
  message: "Please provide a clearer copy",
  from: currentAdmin.name,
  createdAt: FieldValue.serverTimestamp()
});

// Set reupload permission
await uploadsRef.doc(documentTitle).update({
  reuploadAllowed: true
});
```

---

## Status Lifecycle

```
[Draft] ──────────────────────> [Submitted]
   │                                  │
   │                                  │
   │ Applicant creates            Applicant submits
   │ new submission               all required files
   │                                  │
   │                                  ▼
   │                           Admin reviews
   │                                  │
   │                          ┌───────┴────────┐
   │                          │                │
   │                     [Approved]      [Needs Revision]
   │                                           │
   │                                           │
   │                                   Admin sets
   │                                   reuploadAllowed
   │                                           │
   │◄──────────────────────────────────────────┘
   │
   │ Applicant creates
   │ new submission
   │ for resubmission
   │
   ▼
[Draft] ──> (cycle continues)
```

---

## Testing Checklist for Admin Side

- [ ] Can view list of all submissions for an applicant
- [ ] Can see submission ID, status, and dates
- [ ] Can filter submissions by status (draft/submitted)
- [ ] Can view individual submission details
- [ ] Can see all uploaded documents in a submission
- [ ] Can add comments to specific documents
- [ ] Can set `reuploadAllowed` flag
- [ ] Can see applicant's total submission count
- [ ] Can distinguish between different submissions from same applicant
- [ ] Can track submission timeline (created, submitted, reviewed)

---

## File Locations

The following files were updated to implement multi-submission support:

1. `lib/features/applicant/ctpo.dart`
2. `lib/features/applicant/PermitToCut.dart`
3. `lib/features/applicant/pltp.dart`
4. `lib/features/applicant/splt.dart`
5. `lib/features/applicant/chainsawreg.dart`
6. `lib/features/applicant/cov.dart`

All files follow the same pattern and implementation for consistency.

---

## Summary

The multi-submission system provides:

✅ **Flexibility**: Applicants can submit multiple applications of the same type
✅ **Organization**: Each submission has a unique ID and independent tracking
✅ **History**: Complete timeline of all submissions per applicant
✅ **Clarity**: Clear visual distinction between draft and submitted applications
✅ **Scalability**: Structure supports unlimited submissions per applicant
✅ **Consistency**: Same implementation across all application types

This new flow requires admin interface updates to navigate the submissions subcollection and display multiple submissions per applicant effectively.
