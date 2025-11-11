# Reupload Allowed Implementation Guide

## Overview
This guide shows how to implement the `reuploadAllowed` feature for applicant-side upload pages to automatically disable/enable the submit button based on admin comments.

## Features Implemented

✅ **Admin Comments Display** - Shows all comments from admin with timestamp
✅ **Reupload Status Check** - Loads `reuploadAllowed` flag from Firestore
✅ **Dynamic Button State** - Submit button enables only when `reuploadAllowed: true`
✅ **Visual Feedback** - Shows colored notifications (green/red) based on status

## Firestore Structure

```
applications/
├── pltp/
│   └── applicants/
│       └── {applicantId}
│           ├── reuploadAllowed: true/false
│           ├── lastCommentAt: timestamp
│           └── comments/
│               ├── comment1_doc
│               │   ├── message: "Please fix..."
│               │   ├── from: "Admin"
│               │   └── createdAt: timestamp
│               └── comment2_doc
│                   ├── message: "Reupload documents"
│                   ├── from: "Admin"
│                   └── createdAt: timestamp
```

## Implementation Steps

### 1. Add State Variables (in _State class)

```dart
bool _reuploadAllowed = false; // ✅ Track reuploadAllowed status
List<Map<String, dynamic>> _adminComments = []; // ✅ Store admin comments
```

### 2. Add Methods to Load Data

```dart
/// ✅ Load reuploadAllowed status from Firestore
Future<void> _loadReuploadStatus() async {
  try {
    final applicantRef = FirebaseFirestore.instance
        .collection('applications')
        .doc('{APPLICATION_TYPE}') // Replace with: 'pltp', 'spltp', 'ctpo'
        .collection('applicants')
        .doc(widget.applicantId);

    final snapshot = await applicantRef.get();
    if (snapshot.exists) {
      final reuploadAllowed = snapshot.data()?['reuploadAllowed'] as bool? ?? false;
      setState(() {
        _reuploadAllowed = reuploadAllowed;
      });
    }
  } catch (e) {
    print("Error loading reupload status: $e");
  }
}

/// ✅ Load admin comments from Firestore
Future<void> _loadAdminComments() async {
  try {
    final applicantRef = FirebaseFirestore.instance
        .collection('applications')
        .doc('{APPLICATION_TYPE}') // Replace with: 'pltp', 'spltp', 'ctpo'
        .collection('applicants')
        .doc(widget.applicantId);

    final commentsSnapshot = await applicantRef
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .get();
    
    final comments = commentsSnapshot.docs.map((doc) {
      return {
        'message': doc.data()['message'] as String? ?? '',
        'from': doc.data()['from'] as String? ?? 'Admin',
        'createdAt': doc.data()['createdAt'] as Timestamp?,
      };
    }).toList();

    setState(() {
      _adminComments = comments;
    });
  } catch (e) {
    print("Error loading admin comments: $e");
  }
}

/// ✅ Format timestamp to readable string
String _formatTimestamp(dynamic timestamp) {
  if (timestamp == null) return '';
  try {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  } catch (e) {
    return '';
  }
  return '';
}
```

### 3. Call Methods in initState

```dart
@override
void initState() {
  super.initState();
  // ... existing code ...
  _loadReuploadStatus(); // ✅ Load reuploadAllowed status
  _loadAdminComments();  // ✅ Load admin comments
}
```

### 4. Update Build Method - Add Comments Section

Add this after the title and before the form fields:

```dart
// ✅ Show admin comments if any
if (_adminComments.isNotEmpty) ...[
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blue[50],
      border: Border.all(color: Colors.blue[300]!, width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.comment, color: Colors.blue),
            const SizedBox(width: 8),
            const Text(
              'Admin Comments',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._adminComments.map((comment) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment['message'] ?? '',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'From: ${comment['from']} ${comment['createdAt'] != null ? '• ${_formatTimestamp(comment['createdAt'])}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    ),
  ),
  const SizedBox(height: 16),

  // ✅ Show notification based on reuploadAllowed status
  if (!_reuploadAllowed)
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You cannot re-upload files yet. Please wait for admin approval.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    )
  else
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You can re-upload files now. Please correct the issues mentioned above.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.green[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  const SizedBox(height: 16),
],
```

### 5. Update Submit Button

Replace the old button's `onPressed` and styling:

```dart
ElevatedButton(
  onPressed: (_isUploading || !_reuploadAllowed && _adminComments.isNotEmpty) 
      ? null 
      : handleSubmit,
  style: ElevatedButton.styleFrom(
    backgroundColor: (_reuploadAllowed || _adminComments.isEmpty) 
        ? Colors.green[700] 
        : Colors.grey[400],
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 20),
    textStyle: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.bold),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  child: _isUploading
      ? const CircularProgressIndicator(color: Colors.white)
      : Text(
          (_reuploadAllowed || _adminComments.isEmpty)
              ? 'Submit (Upload All Files)'
              : 'Submit Disabled - Waiting for Approval',
        ),
)
```

## How It Works

1. **Page Load** 
   - `_loadReuploadStatus()` checks if `reuploadAllowed: true` in Firestore
   - `_loadAdminComments()` fetches all comments from the comments subcollection

2. **Display Logic**
   - If NO comments → Button is ENABLED (green) - Initial submission allowed
   - If comments exist BUT `reuploadAllowed: false` → Button is DISABLED (grey) - Waiting for corrections
   - If comments exist AND `reuploadAllowed: true` → Button is ENABLED (green) - Can now re-upload

3. **Admin Updates Firestore**
   - Admin adds comment via Web dashboard
   - Sets `reuploadAllowed: true` in applicant document
   - Applicant immediately sees:
     - New comment in the comments section
     - Green notification showing they can re-upload
     - Submit button becomes enabled

## Files to Update

Apply these changes to:
- `lib/features/applicant/pltp.dart` ✅ (Already done)
- `lib/features/applicant/spltp.dart` (Apply same pattern)
- `lib/features/applicant/splt.dart` (Apply same pattern)
- `lib/features/applicant/ctpo.dart` (Apply same pattern)

## Example Firestore Document After Admin Action

```javascript
{
  "applicantName": "John Doe",
  "uploadedAt": timestamp,
  "reuploadAllowed": true,              // ✅ Set by admin
  "lastCommentAt": timestamp,
  "comments": {
    "comment_123": {
      "message": "Please update your documents. The ECC is missing.",
      "from": "Admin",
      "createdAt": timestamp,
      "reuploadAllowed": true
    }
  }
}
```

## Streaming Option (Real-time Updates)

For real-time updates without manual refresh, replace `_loadReuploadStatus()` with:

```dart
/// ✅ Listen to reuploadAllowed status in real-time
void _listenToReuploadStatus() {
  final applicantRef = FirebaseFirestore.instance
      .collection('applications')
      .doc('{APPLICATION_TYPE}')
      .collection('applicants')
      .doc(widget.applicantId);

  applicantRef.snapshots().listen((snapshot) {
    if (snapshot.exists) {
      final reuploadAllowed = snapshot.data()?['reuploadAllowed'] as bool? ?? false;
      setState(() {
        _reuploadAllowed = reuploadAllowed;
      });
    }
  });
}

/// ✅ Listen to comments in real-time
void _listenToComments() {
  final applicantRef = FirebaseFirestore.instance
      .collection('applications')
      .doc('{APPLICATION_TYPE}')
      .collection('applicants')
      .doc(widget.applicantId);

  applicantRef.collection('comments').orderBy('createdAt', descending: true).snapshots().listen((snapshot) {
    final comments = snapshot.docs.map((doc) {
      return {
        'message': doc.data()['message'] as String? ?? '',
        'from': doc.data()['from'] as String? ?? 'Admin',
        'createdAt': doc.data()['createdAt'] as Timestamp?,
      };
    }).toList();

    setState(() {
      _adminComments = comments;
    });
  });
}
```

Then call in `initState()`:
```dart
_listenToReuploadStatus();
_listenToComments();
```

This provides **instant updates** without requiring page refresh!
