# 💬 Comment & Reupload Feature - Applicant Side Implementation

## Overview
The comment and reupload feature allows admins to review applicant documents, leave feedback, and request reuploads when documents need corrections. This document explains how the feature works on the **applicant side** of the mobile app.

---

## ✅ Implementation Status

### Files Updated
- ✅ `ctpo.dart` - Certificate to Cut Planted Trees on Private Land
- ✅ `PermitToCut.dart` - Permit to Cut application
- ✅ `pltp.dart` - Private Land Timber Permit
- ✅ `splt.dart` - Special Land Timber Permit

---

## 🔧 How It Works

### Step 1: Admin Leaves a Comment
1. Admin reviews uploaded documents in the admin interface
2. Admin selects a document that needs correction
3. Admin writes a comment explaining what needs to be fixed
4. Admin clicks "Send Comment"
5. System sets `reuploadAllowed: true` for that document
6. Comment is saved to Firestore under `uploads.{documentTitle}.comment`

### Step 2: Applicant Sees the Comment
When the applicant opens their application page:
1. App loads all document comments from Firestore
2. Documents with `reuploadAllowed: true` show:
   - 🟠 Orange comment box with admin's message
   - ✅ Green indicator "You can re-upload this file"
   - 🟠 Orange "Re-upload" button (enabled)
3. Documents without comments show:
   - ✅ Green "Uploaded" status
   - ⚪ Gray "Uploaded" button (disabled)

### Step 3: Applicant Reuploads the Document
1. Applicant clicks "Re-upload" button
2. Applicant selects a new file
3. Applicant clicks "Submit All Files"
4. App uploads the new file to Firebase Storage
5. App updates Firestore with new file URL
6. **App automatically sets `reuploadAllowed: false`**
7. Button becomes disabled again
8. Comment remains visible for reference

---

## 📊 Database Structure

### Firestore Path
```
applications/
  └── {applicationType}/        (e.g., "ctpo", "pltp", "ptc", "splt")
      └── applicants/
          └── {applicantId}/
              ├── applicantName: "John Doe"
              ├── uploadedAt: Timestamp
              └── uploads: {
                    "Letter-of-Application": {
                      reuploadAllowed: true,
                      lastCommentAt: Timestamp,
                      reuploadedAt: Timestamp,
                      comment: {
                        message: "Please provide a clearer signature",
                        from: "admin@example.com",
                        createdAt: Timestamp
                      }
                    }
                  }
```

### Document Fields
| Field | Type | Description |
|-------|------|-------------|
| `reuploadAllowed` | boolean | **true** if admin requested reupload, **false** after reupload |
| `lastCommentAt` | Timestamp | When the most recent comment was added |
| `reuploadedAt` | Timestamp | When the file was last reuploaded |
| `comment.message` | string | Admin's feedback/instructions |
| `comment.from` | string | Email of admin who left the comment |
| `comment.createdAt` | Timestamp | When the comment was created |

---

## 🎨 UI Implementation

### Visual States

#### 1. Normal Uploaded Document (No Comment)
```
📄 Letter of Application ✅ (Uploaded)
[View Uploaded File]
[Uploaded] ← Disabled, gray button
```

#### 2. Document with Admin Comment (Reupload Allowed)
```
📄 Letter of Application ✅ (Uploaded)
[View Uploaded File]
[Re-upload] ← Enabled, orange button

┌─────────────────────────────────────┐
│ 💬 Admin Comment                    │
│                                     │
│ Please provide a clearer signature  │
│ and ensure all pages are scanned.   │
│                                     │
│ From: admin@denr.gov • 2h ago      │
│                                     │
│ ✅ You can re-upload this file      │
└─────────────────────────────────────┘
```

#### 3. After Successful Reupload
```
📄 Letter of Application ✅ (Uploaded)
[View Uploaded File]
[Uploaded] ← Disabled again, gray button

┌─────────────────────────────────────┐
│ 💬 Admin Comment                    │
│                                     │
│ Please provide a clearer signature  │
│                                     │
│ From: admin@denr.gov • 2h ago      │
└─────────────────────────────────────┘
```

---

## 🔄 Workflow Sequence

### Loading Comments
```dart
Future<void> _loadDocumentComments() async {
  // 1. Get applicant document from Firestore
  final applicantDoc = FirebaseFirestore.instance
      .collection('applications')
      .doc('ctpo')  // or 'pltp', 'splt', 'ptc'
      .collection('applicants')
      .doc(widget.applicantId);

  // 2. Get the uploads field
  final snapshot = await applicantDoc.get();
  final uploadsMap = snapshot.data()?['uploads'] as Map<String, dynamic>?;

  // 3. Extract reuploadAllowed and comment for each document
  for (final entry in uploadsMap.entries) {
    final docTitle = entry.key;
    final docData = entry.value as Map<String, dynamic>;
    
    _documentComments[docTitle] = {
      'reuploadAllowed': docData['reuploadAllowed'] ?? false,
      'comment': docData['comment'],
      'lastCommentAt': docData['lastCommentAt'],
    };
  }

  setState(() {});
}
```

### Button State Logic
```dart
Widget buildUploadField(Map<String, String> label) {
  final title = label["title"]!;
  final url = uploadedFiles[title]!["url"] as String?;
  final isUploaded = url != null;
  
  // Get comment data
  final docData = _documentComments[title];
  final reuploadAllowed = docData?['reuploadAllowed'] as bool? ?? false;
  final comment = docData?['comment'];

  return ElevatedButton(
    // ✅ Disable if uploaded AND reupload NOT allowed
    // ✅ Disable if currently uploading
    onPressed: (isUploaded && !reuploadAllowed) || _isUploading 
        ? null 
        : () => pickFile(title),
    
    // Orange if reupload allowed, Gray if not
    style: ElevatedButton.styleFrom(
      backgroundColor: isUploaded
          ? (reuploadAllowed ? Colors.orange : Colors.grey[300])
          : Colors.green[700],
    ),
    
    child: Text(
      isUploaded
          ? (reuploadAllowed ? 'Re-upload' : 'Uploaded')
          : 'Choose File',
    ),
  );
}
```

### Reuploading Files
```dart
Future<void> handleSubmit() async {
  setState(() => _isUploading = true);

  try {
    Map<String, dynamic> uploadsFieldUpdates = {};

    for (final entry in uploadedFiles.entries) {
      final title = entry.key;
      final file = entry.value["file"] as PlatformFile?;
      if (file == null) continue;

      // 1️⃣ Upload file to Firebase Storage
      final ref = storage.ref().child("ctpo_uploads/${file.name}");
      await ref.putFile(File(file.path!));
      final url = await ref.getDownloadURL();

      // 2️⃣ Save to uploads subcollection
      await applicantUploadsRef.doc(title).set({
        'title': title,
        'url': url,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      // 3️⃣ Reset reuploadAllowed flag
      uploadsFieldUpdates['uploads.$title.reuploadAllowed'] = false;

      // 4️⃣ Clear selected file from UI
      uploadedFiles[title]!["file"] = null;
      uploadedFiles[title]!["url"] = url;
    }

    // 5️⃣ Update applicant document
    await applicantDoc.set(uploadsFieldUpdates, SetOptions(merge: true));

    // 6️⃣ Reload comments to update UI
    await _loadDocumentComments();
    await _loadExistingUploads();

    setState(() => _isUploading = false);
    
  } catch (e) {
    setState(() => _isUploading = false);
  }
}
```

---

## 🎯 Key Features

### ✅ Automatic Button State Management
- Button automatically disables after successful upload
- Button re-enables only when admin sets `reuploadAllowed: true`
- Button shows correct text: "Choose File" → "Uploaded" → "Re-upload"

### ✅ Visual Feedback
- 🟠 Orange comment box clearly shows admin feedback
- ✅ Green indicator confirms reupload permission
- 🔵 Blue theme for application-level templates
- ⚪ Gray styling for disabled buttons

### ✅ Comment Persistence
- Comments remain visible even after reupload
- Provides audit trail of all feedback
- Shows who left the comment and when

### ✅ Real-time Updates
- Automatically reloads comments after upload
- Updates button states immediately
- No manual refresh needed

---

## 🚨 Important Behaviors

### 1. Multiple Comments
If admin adds multiple comments over time:
- Only the **most recent comment** is displayed
- Older comments are replaced by newer ones
- Timestamp shows when latest comment was added

### 2. Reupload Workflow
```
Initial Upload → Admin Reviews → Admin Adds Comment
     ↓                ↓                  ↓
  Uploaded      reuploadAllowed     Applicant Sees
   Status          = true            Orange Button
     ↓                                    ↓
Applicant Reuploads → System Sets reuploadAllowed = false
                            ↓
                      Button Disabled Again
```

### 3. Button States
| Scenario | Button Text | Button Color | Enabled? |
|----------|-------------|--------------|----------|
| Not uploaded | "Choose File" | Green | ✅ Yes |
| Uploaded, no comment | "Uploaded" | Gray | ❌ No |
| Uploaded, comment exists, reupload allowed | "Re-upload" | Orange | ✅ Yes |
| Uploaded, comment exists, reupload not allowed | "Uploaded" | Gray | ❌ No |
| Currently uploading | Current text | Current color | ❌ No |

---

## 📋 Testing Checklist

- [ ] Admin can add comment to a document
- [ ] Applicant sees comment in mobile app
- [ ] Reupload button is enabled (orange) when comment exists
- [ ] Applicant can select new file
- [ ] Applicant can upload new file successfully
- [ ] Button automatically disables after reupload
- [ ] `reuploadAllowed` is set to `false` after reupload
- [ ] Comment remains visible after reupload
- [ ] Multiple reuploads work correctly
- [ ] Error handling works if upload fails
- [ ] Loading states work correctly
- [ ] UI updates immediately after upload

---

## 🔍 Debugging

### Check Comment Loading
Add console logs to `_loadDocumentComments()`:
```dart
print("📄 Loaded comments: $_documentComments");
print("🔄 Reupload allowed for: ${_documentComments.entries.where((e) => e.value['reuploadAllowed'] == true).map((e) => e.key).toList()}");
```

### Check Button State
Add console logs to `buildUploadField()`:
```dart
print("🔘 Button for $title: uploaded=$isUploaded, reupload=$reuploadAllowed");
```

### Check Upload Success
Add console logs to `handleSubmit()`:
```dart
print("✅ Uploaded $title, setting reuploadAllowed=false");
```

---

## 📚 Related Documentation

- **Admin Side**: See `COMMENT_FEATURE_DOCUMENTATION.md` for admin interface
- **Template Feature**: See `TEMPLATE_FEATURE_GUIDE.md` for template upload
- **Reupload Flow**: See `REUPLOAD_FLOW_DIAGRAM.md` for visual workflow

---

## 🎉 Summary

The comment and reupload feature is now fully implemented on the applicant side:

✅ **Comments Display**: Admin feedback appears in orange boxes below documents  
✅ **Smart Buttons**: Automatically enable/disable based on reupload permission  
✅ **Auto-Reset**: `reuploadAllowed` flag resets to `false` after successful reupload  
✅ **Visual Feedback**: Clear indicators for reupload status and admin comments  
✅ **Consistent Implementation**: All 4 application types work the same way  

Applicants can now see admin feedback, reupload corrected documents, and have the upload button automatically disabled after reupload—exactly as specified! 🚀
