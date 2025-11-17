# 🌲 TreeSure Application Workflow & Data Structure

## Overview
This document describes the complete workflow for CTPO, PLTP, and SPLTP applications, including appointment management, tree inventory, and revisit functionality.

---

## 📋 Application Types

### 1. **CTPO (Certificate of Tree Plantation Ownership)**
- Full workflow with tree tagging, revisit, and certificate claiming
- Original/primary application type

### 2. **PLTP (Private Land Timber Permit)**
- Requires completed CTPO reference
- Tree tagging only (no revisit)
- Copies tree inventory from CTPO for verification

### 3. **SPLTP (Special Private Land Timber Permit)**
- Requires completed CTPO reference
- Tree tagging only (no revisit)
- Copies tree inventory from CTPO for verification

---

## 🔄 Application Workflow

### CTPO Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    CTPO APPLICATION FLOW                     │
└─────────────────────────────────────────────────────────────┘

1. Applicant Submits CTPO
   └─> Admin reviews submission
   
2. Admin Assigns Tree Tagging Appointment
   └─> Creates: tree_tagging_appointment_XX
   └─> Status: "Pending"
   └─> Assigns: Forester(s)
   
3. Forester Performs Tree Tagging
   └─> Tags trees with QR codes (T1, T2, T3...)
   └─> Records: height, diameter, specie, location, photo
   └─> Saves to: appointments/{appointment_id}/tree_inventory/{tree_id}
   └─> Updates appointment status: "Completed"
   
4. Admin Can Assign Revisit (Optional)
   └─> Creates: revisit_appointment_XX
   └─> Copies tree data to: tree_revisit subcollection
   └─> Structure: { old: {...}, new: {...} }
   
5. Forester Performs Revisit
   └─> Verifies each tree
   └─> Updates measurements in "new" fields
   └─> Updates appointment status: "Completed"
   
6. Admin Issues Certificate
   └─> Sends notification to applicant
   └─> Applicant can claim certificate
```

---

### PLTP/SPLTP Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                 PLTP/SPLTP APPLICATION FLOW                  │
└─────────────────────────────────────────────────────────────┘

1. Applicant Submits PLTP/SPLTP
   └─> Admin reviews submission
   
2. Admin Selects CTPO Reference
   └─> Opens "Select CTPO Reference" modal
   └─> Shows CTPO submissions with completed tree tagging
   └─> Admin selects matching CTPO submission
   └─> CTPO ID saved to: ctpoReference field
   
3. Admin Assigns Tree Tagging Appointment
   └─> Creates: tree_tagging_appointment_XX
   └─> Status: "Pending"
   └─> Assigns: Forester(s)
   
4. System Auto-Copies Tree Inventory
   ┌─> Priority 1: Check for completed CTPO Revisit
   │   └─> If found: Copy from tree_revisit (most recent data)
   │   └─> Uses "new" measurements (updated values)
   │
   └─> Priority 2: No revisit? Use original Tree Tagging
       └─> Copy from tree_inventory (original data)
   
   └─> Saves to: appointments/{appointment_id}/tree_inventory/{tree_id}
   └─> Structure: {
         ctpo_tree_ref: (reference to CTPO tree),
         ctpo_data: { ...CTPO measurements },
         source_type: "revisit" or "tree_tagging",
         height: null,  // For forester to verify
         diameter: null,
         specie: null,
         ...
       }
   
5. Forester Verifies Trees
   └─> Reviews CTPO data (ctpo_data field)
   └─> Verifies/updates measurements
   └─> Records new measurements if needed
   └─> Updates appointment status: "Completed"
   
6. No Revisit for PLTP/SPLTP
   └─> Button hidden after tree tagging completion
```

---

## 🗄️ Firebase Data Structure

### Appointments Collection
**Path:** `appointments/{appointment_id}`

#### Tree Tagging Appointment Document
```javascript
{
  // Document ID: tree_tagging_appointment_01, tree_tagging_appointment_02, etc.
  
  adminId: "admin@email.com",
  applicantId: "005",
  applicantName: "John Doe",
  appointmentType: "Tree Tagging",
  applicationType: "ctpo" | "pltp" | "splt",
  applicationID: "submission_id_here",
  location: "Barangay Location",
  status: "Pending" | "Completed",
  remarks: "Optional remarks",
  createdAt: Timestamp,
  completedAt: Timestamp | null,
  foresterIds: ["forester_id_1", "forester_id_2"],
  treeIds: []
}
```

#### Revisit Appointment Document (CTPO Only)
```javascript
{
  // Document ID: revisit_appointment_01, revisit_appointment_02, etc.
  
  adminId: "admin@email.com",
  applicantId: "005",
  applicantName: "John Doe",
  appointmentType: "Revisit",
  applicationType: "ctpo",
  applicationID: "submission_id_here",
  location: "Barangay Location",
  status: "Pending" | "Completed",
  remarks: "Optional remarks",
  createdAt: Timestamp,
  completedAt: Timestamp | null,
  foresterIds: ["forester_id_1", "forester_id_2"],
  originalAppointmentRef: "tree_tagging_appointment_01", // Reference to original
  treeIds: []
}
```

---

### Tree Inventory Subcollection (CTPO Tree Tagging)
**Path:** `appointments/{tree_tagging_appointment_id}/tree_inventory/{tree_id}`

```javascript
{
  // Document ID: T1, T2, T3, etc.
  
  appointment_id: "tree_tagging_appointment_01",
  tree_id: "T1",
  tree_no: "T1",
  
  // Measurements
  height: 12,
  diameter: 12,
  volume: 1357.17,
  specie: "narra",
  
  // Location
  latitude: 18.309936,
  longitude: 121.60892,
  
  // Media
  photo_url: "https://...",
  qr_url: "https://...tree_qrcodes/T1.png",
  
  // Status
  tree_status: "Not Yet Ready" | "Ready" | "Harvested",
  
  // Forester Info
  forester_id: "003",
  forester_name: "Dos",
  
  // Metadata
  timestamp: Timestamp,
  tree_tagging_appointment_id: null
}
```

---

### Tree Revisit Subcollection (CTPO Revisit)
**Path:** `appointments/{revisit_appointment_id}/tree_revisit/{tree_id}`

```javascript
{
  // Document ID: T1, T2, T3, etc.
  
  tree_tagging_ref: DocumentReference, // Points to original tree in tree_inventory
  treeId: "T1",
  createdAt: Timestamp,
  
  // OLD DATA (from original tree tagging)
  old: {
    height: 12,
    diameter: 12,
    specie: "narra",
    latitude: 18.309936,
    longitude: 121.60892,
    photo_url: "https://...",
    tree_status: "Not Yet Ready",
    volume: 1357.17,
    qr_url: "https://...tree_qrcodes/T1.png",
    tree_no: "T1",
    timestamp: Timestamp,
    forester_name: "Dos",
    forester_id: "003"
  },
  
  // NEW DATA (filled by forester during revisit)
  new: {
    height: null,         // Updated measurement
    diameter: null,       // Updated measurement
    specie: null,         // Usually same, but can update
    tree_status: null,    // Updated status
    volume: null,         // Recalculated volume
    photo_url: null,      // New photo
    qr_url: null,         // New QR if needed
    updatedAt: null,      // Timestamp of update
    forester_name: null,  // Revisit forester
    forester_id: null     // Revisit forester ID
  }
}
```

---

### Tree Inventory Subcollection (PLTP/SPLTP Tree Tagging)
**Path:** `appointments/{tree_tagging_appointment_id}/tree_inventory/{tree_id}`

```javascript
{
  // Document ID: T1, T2, T3, etc.
  
  tree_id: "T1",
  appointment_id: "tree_tagging_appointment_02",
  timestamp: Timestamp,
  
  // REFERENCE to CTPO tree data
  ctpo_tree_ref: DocumentReference, // Points to CTPO tree (inventory or revisit)
  source_type: "revisit" | "tree_tagging", // Indicates source
  
  // CTPO DATA (for reference - read-only for forester)
  ctpo_data: {
    height: 12,              // From CTPO
    diameter: 12,            // From CTPO
    specie: "narra",         // From CTPO
    latitude: 18.309936,     // From CTPO
    longitude: 121.60892,    // From CTPO
    photo_url: "https://...", // From CTPO
    qr_url: "https://...",   // From CTPO
    tree_status: "Ready",    // From CTPO
    volume: 1357.17,         // From CTPO
    tree_no: "T1",           // From CTPO
    forester_name: "Dos",    // Original CTPO forester
    forester_id: "003"       // Original CTPO forester ID
  },
  
  // NEW VERIFICATION DATA (filled by PLTP/SPLTP forester)
  height: null,           // Verified/updated measurement
  diameter: null,         // Verified/updated measurement
  specie: null,           // Verified specie
  latitude: null,         // Verified location
  longitude: null,        // Verified location
  photo_url: null,        // New verification photo
  qr_url: null,           // Same QR or new
  tree_status: null,      // Updated status
  volume: null,           // Recalculated volume
  tree_no: null,          // Same tree number
  forester_name: null,    // PLTP/SPLTP forester
  forester_id: null       // PLTP/SPLTP forester ID
}
```

---

## 🔄 Data Flow Diagrams

### CTPO Tree Tagging → Revisit Flow

```
┌────────────────────────────────────────────────────────────────┐
│               CTPO TREE TAGGING (Initial)                       │
├────────────────────────────────────────────────────────────────┤
│ appointments/tree_tagging_appointment_01/                      │
│   └─ tree_inventory/                                           │
│      ├─ T1: { height: 12, diameter: 12, ... }                 │
│      ├─ T2: { height: 15, diameter: 14, ... }                 │
│      └─ T3: { height: 10, diameter: 11, ... }                 │
└────────────────────────────────────────────────────────────────┘
                            ↓
                   [Admin assigns revisit]
                            ↓
┌────────────────────────────────────────────────────────────────┐
│                  CTPO REVISIT (Follow-up)                       │
├────────────────────────────────────────────────────────────────┤
│ appointments/revisit_appointment_01/                           │
│   originalAppointmentRef: "tree_tagging_appointment_01"        │
│   └─ tree_revisit/                                             │
│      ├─ T1:                                                    │
│      │   ├─ tree_tagging_ref: → tree_inventory/T1             │
│      │   ├─ old: { height: 12, diameter: 12, ... }            │
│      │   └─ new: { height: 14, diameter: 13, ... } ← Updated  │
│      │                                                          │
│      ├─ T2:                                                    │
│      │   ├─ tree_tagging_ref: → tree_inventory/T2             │
│      │   ├─ old: { height: 15, diameter: 14, ... }            │
│      │   └─ new: { height: 16, diameter: 15, ... } ← Updated  │
│      │                                                          │
│      └─ T3:                                                    │
│          ├─ tree_tagging_ref: → tree_inventory/T3             │
│          ├─ old: { height: 10, diameter: 11, ... }            │
│          └─ new: { height: 12, diameter: 12, ... } ← Updated  │
└────────────────────────────────────────────────────────────────┘
```

---

### CTPO → PLTP/SPLTP Reference Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                 CTPO (Completed Tree Tagging)                    │
├─────────────────────────────────────────────────────────────────┤
│ applications/ctpo/applicants/005/submissions/sub_001/           │
│                                                                  │
│ appointments/tree_tagging_appointment_01/ (Status: Completed)   │
│   └─ tree_inventory/                                            │
│      ├─ T1: { height: 12, diameter: 12, specie: "narra", ... } │
│      ├─ T2: { height: 15, diameter: 14, specie: "mahogany"...} │
│      └─ T3: { height: 10, diameter: 11, specie: "acacia", ... }│
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    [Optionally has revisit]
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              CTPO Revisit (If completed - Priority!)            │
├─────────────────────────────────────────────────────────────────┤
│ appointments/revisit_appointment_01/ (Status: Completed)        │
│   └─ tree_revisit/                                              │
│      ├─ T1: { old: {...}, new: { height: 14, diameter: 13 } }  │
│      ├─ T2: { old: {...}, new: { height: 16, diameter: 15 } }  │
│      └─ T3: { old: {...}, new: { height: 12, diameter: 12 } }  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
              [PLTP/SPLTP selects this CTPO as reference]
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  PLTP/SPLTP (New Application)                    │
├─────────────────────────────────────────────────────────────────┤
│ applications/pltp/applicants/005/submissions/sub_002/           │
│   ctpoReference: "sub_001"  ← Links to CTPO submission         │
│                                                                  │
│ appointments/tree_tagging_appointment_02/                       │
│   └─ tree_inventory/                                            │
│      ├─ T1:                                                     │
│      │   ├─ ctpo_tree_ref: → revisit_appointment_01/T1         │
│      │   ├─ source_type: "revisit"                             │
│      │   ├─ ctpo_data: { height: 14, diameter: 13, ... }       │
│      │   │              ↑ Uses REVISIT "new" data (Priority!)  │
│      │   └─ height: null ← Forester verifies                   │
│      │                                                           │
│      ├─ T2:                                                     │
│      │   ├─ ctpo_tree_ref: → revisit_appointment_01/T2         │
│      │   ├─ source_type: "revisit"                             │
│      │   ├─ ctpo_data: { height: 16, diameter: 15, ... }       │
│      │   └─ height: null ← Forester verifies                   │
│      │                                                           │
│      └─ T3:                                                     │
│          ├─ ctpo_tree_ref: → revisit_appointment_01/T3         │
│          ├─ source_type: "revisit"                             │
│          ├─ ctpo_data: { height: 12, diameter: 12, ... }       │
│          └─ height: null ← Forester verifies                   │
└─────────────────────────────────────────────────────────────────┘
```

**Note:** If no revisit exists, PLTP/SPLTP copies from `tree_inventory` instead, and `source_type` will be `"tree_tagging"`.

---

## 🎯 Admin Button States

### CTPO Button Logic
```javascript
No appointments → "Assign for Tree Tagging"
Pending tree tagging → "Modify Tree Tagging Assignment"
Completed tree tagging → "Assign for Revisit" + Show "Claim Certificate"
Pending revisit → "Modify Revisit Assignment"
Completed revisit → Show "Claim Certificate" only
```

### PLTP/SPLTP Button Logic
```javascript
No appointments → "Select CTPO Reference"
After CTPO selected → Opens tree tagging modal
Pending tree tagging → "Modify Tree Tagging Assignment"
Completed tree tagging → Hide button (no revisit for PLTP/SPLTP)
```

---

## 📱 Forester App Implementation Guide

### 1. Authentication
- Forester logs in with credentials
- Retrieve forester ID and name from user document

### 2. View Assigned Appointments
**Query:**
```javascript
appointments
  .where("foresterIds", "array-contains", currentForesterId)
  .where("status", "==", "Pending")
  .orderBy("createdAt", "desc")
```

### 3. Tree Tagging Screen (CTPO)

**Steps:**
1. Open appointment
2. Scan/Generate QR code for tree (T1, T2, T3...)
3. Capture tree photo
4. Input measurements:
   - Height (meters)
   - Diameter (cm)
   - Species
   - Get GPS coordinates automatically
5. Calculate volume (if formula available)
6. Save to: `appointments/{appointment_id}/tree_inventory/{tree_id}`

**Data to save:**
```javascript
{
  appointment_id: "tree_tagging_appointment_01",
  tree_id: "T1",
  tree_no: "T1",
  height: 12,
  diameter: 12,
  volume: 1357.17,
  specie: "narra",
  latitude: 18.309936,
  longitude: 121.60892,
  photo_url: "uploaded_photo_url",
  qr_url: "generated_qr_url",
  tree_status: "Not Yet Ready",
  forester_id: currentForesterId,
  forester_name: currentForesterName,
  timestamp: FieldValue.serverTimestamp()
}
```

### 4. Tree Tagging Screen (PLTP/SPLTP)

**Differences from CTPO:**
1. Load tree list from `tree_inventory` subcollection (pre-populated)
2. Display CTPO reference data (`ctpo_data` field) as read-only
3. Show comparison view:
   - **CTPO Data** (left/top): ctpo_data fields
   - **Current Verification** (right/bottom): Empty fields to fill
4. Forester verifies and updates measurements
5. Save updates to same tree document (update null fields)

**UI Example:**
```
┌─────────────────────────────────────────────┐
│ Tree: T1                                     │
├─────────────────────────────────────────────┤
│ CTPO Reference (Read-only)                  │
│ Source: Revisit ✓                           │
│ Height: 14m | Diameter: 13cm                │
│ Species: Narra | Volume: 1400L              │
│ Status: Ready | Photo: [View]               │
├─────────────────────────────────────────────┤
│ PLTP Verification (Update)                  │
│ Height: [____] m                            │
│ Diameter: [____] cm                         │
│ Species: [Narra ▼]                          │
│ Status: [Ready ▼]                           │
│ Photo: [Capture]                            │
│ Location: [Get GPS]                         │
│                                              │
│ [✓ Verify Tree] [Skip]                     │
└─────────────────────────────────────────────┘
```

### 5. Revisit Screen (CTPO Only)

**Steps:**
1. Load trees from `tree_revisit` subcollection
2. Display "old" data as reference
3. Collect new measurements in "new" fields
4. Update tree document

**UI Example:**
```
┌─────────────────────────────────────────────┐
│ Tree: T1 (Revisit)                          │
├─────────────────────────────────────────────┤
│ Original Data (Read-only)                   │
│ Height: 12m | Diameter: 12cm                │
│ Species: Narra | Status: Not Yet Ready      │
│ Tagged: Jan 15, 2025 by Dos                 │
├─────────────────────────────────────────────┤
│ Updated Measurements                         │
│ Height: [14] m (+2m)                        │
│ Diameter: [13] cm (+1cm)                    │
│ Status: [Ready ▼]                           │
│ Photo: [Capture New]                        │
│                                              │
│ [✓ Update Tree] [Skip]                     │
└─────────────────────────────────────────────┘
```

**Data to update:**
```javascript
// Update the "new" object in tree_revisit document
{
  new: {
    height: 14,
    diameter: 13,
    specie: "narra",
    tree_status: "Ready",
    volume: 1450.50,
    photo_url: "new_photo_url",
    forester_name: currentForesterName,
    forester_id: currentForesterId,
    updatedAt: FieldValue.serverTimestamp()
  }
}
```

### 6. Complete Appointment

**When all trees processed:**
```javascript
// Update appointment status
appointments/{appointment_id}.update({
  status: "Completed",
  completedAt: FieldValue.serverTimestamp()
})
```

---

## 📱 Applicant App Implementation Guide

### 1. Create Submission
**Path:** `applications/{type}/applicants/{userId}/submissions/{submissionId}`

### 2. Upload Documents
**Path:** `applications/{type}/applicants/{userId}/submissions/{submissionId}/uploads/{docId}`

### 3. View Appointments
**Query:**
```javascript
appointments
  .where("applicantId", "==", currentUserId)
  .where("applicationID", "==", currentSubmissionId)
  .orderBy("createdAt", "desc")
```

### 4. View Tree Inventory

**For CTPO:**
```javascript
// Original tagging
appointments/{tree_tagging_id}/tree_inventory

// If revisit exists
appointments/{revisit_id}/tree_revisit
```

**For PLTP/SPLTP:**
```javascript
appointments/{tree_tagging_id}/tree_inventory
// Shows both ctpo_data and verified data
```

### 5. Track Trees
Display trees with:
- Tree ID (T1, T2, T3...)
- QR Code (for scanning)
- Measurements
- Photos
- Status
- GPS location (map view)

### 6. Claim Certificate (CTPO Only)
- Available when tree tagging is completed
- Notification sent by admin
- Download/view certificate

---

## 🔍 Query Examples

### Get Completed CTPO Submissions for Reference
```javascript
// For PLTP/SPLTP - finding valid CTPO references
const ctpoSubmissions = await db
  .collection('applications/ctpo/applicants/${userId}/submissions')
  .orderBy('createdAt', 'desc')
  .get();

// Find completed tree tagging for each submission
const appointments = await db
  .collection('appointments')
  .where('applicantId', '==', userId)
  .where('status', '==', 'Completed')
  .get();
```

### Get Tree Data Priority (CTPO → PLTP/SPLTP)
```javascript
// Priority 1: Completed revisit
const revisit = await db
  .collection('appointments')
  .where('applicationID', '==', ctpoSubmissionId)
  .where('appointmentType', '==', 'Revisit')
  .where('status', '==', 'Completed')
  .limit(1)
  .get();

if (!revisit.empty) {
  // Use tree_revisit subcollection (most recent data)
  const trees = await db
    .collection(`appointments/${revisit.docs[0].id}/tree_revisit`)
    .get();
} else {
  // Priority 2: Original tree tagging
  const tagging = await db
    .collection('appointments')
    .where('applicationID', '==', ctpoSubmissionId)
    .where('appointmentType', '==', 'Tree Tagging')
    .where('status', '==', 'Completed')
    .limit(1)
    .get();
    
  if (!tagging.empty) {
    // Use tree_inventory subcollection
    const trees = await db
      .collection(`appointments/${tagging.docs[0].id}/tree_inventory`)
      .get();
  }
}
```

---

## ✅ Validation Rules

### Admin Side
- ✅ PLTP/SPLTP requires completed CTPO reference
- ✅ CTPO can have multiple revisits
- ✅ PLTP/SPLTP cannot have revisits
- ✅ Cannot assign appointment without submission selection
- ✅ Must select at least one forester

### Forester Side
- ✅ Can only see assigned appointments
- ✅ Must fill all required tree fields
- ✅ GPS coordinates required for CTPO tree tagging
- ✅ Photo required for each tree
- ✅ Cannot complete appointment with incomplete trees

### Applicant Side
- ✅ Must submit all required documents
- ✅ Can track appointment status
- ✅ Can view tree inventory after completion
- ✅ Can claim certificate only after completion

---

## 🚀 Key Features Summary

### ✅ Implemented Features

1. **Multi-submission Support**
   - Each applicant can have multiple submissions
   - Each submission tracked independently

2. **CTPO Reference System**
   - PLTP/SPLTP must select completed CTPO
   - Modal shows only eligible CTPO submissions
   - Reference saved to submission document

3. **Smart Tree Data Copying**
   - Priority system: Revisit > Tree Tagging
   - Preserves original data for reference
   - Foresters can verify/update

4. **Appointment Management**
   - Incremental ID generation
   - Multi-forester assignment
   - Status tracking
   - Modify forester assignments

5. **Tree Inventory Structure**
   - QR code generation
   - GPS tracking
   - Photo storage
   - Volume calculation
   - Status management

6. **Revisit System (CTPO)**
   - Copy original tree data
   - Compare old vs new measurements
   - Track changes over time

---

## 📝 Notes for Development

### Mobile App Considerations
1. **Offline Support:** Cache appointment and tree data
2. **Photo Optimization:** Compress images before upload
3. **GPS Accuracy:** Require minimum accuracy threshold
4. **QR Code:** Generate unique codes, ensure scannable
5. **Sync:** Handle offline data sync when connection restored

### Performance Optimization
1. **Pagination:** Limit query results (e.g., 20 per page)
2. **Indexing:** Create composite indexes for common queries
3. **Lazy Loading:** Load tree inventory only when needed
4. **Caching:** Cache frequently accessed data (foresters, species list)

### Security Rules (Firestore)
```javascript
// Example rules structure
match /appointments/{appointmentId} {
  // Admin can create/update
  allow create, update: if isAdmin();
  
  // Forester can read if assigned
  allow read: if request.auth.uid in resource.data.foresterIds;
  
  // Forester can update tree inventory if assigned
  match /tree_inventory/{treeId} {
    allow write: if request.auth.uid in get(/databases/$(database)/documents/appointments/$(appointmentId)).data.foresterIds;
  }
}
```

---

## 🎨 UI/UX Recommendations

### Admin Dashboard
- Color coding for appointment types
- Status badges (Pending, Completed)
- Quick filters (By type, By status, By forester)
- Search by applicant name

### Forester App
- Dashboard showing assigned appointments
- Tree tagging wizard (step-by-step)
- Offline mode indicator
- Sync status display
- Map view of tagged trees

### Applicant App
- Submission timeline
- Appointment status cards
- Tree gallery view
- Interactive map
- Certificate download

---

## 📞 Support & Questions

For questions about this workflow:
1. Review this document thoroughly
2. Check Firebase console for actual data structure
3. Test with sample data before production
4. Document any deviations from this structure

---

**Document Version:** 1.0  
**Last Updated:** November 16, 2025  
**Status:** ✅ Implemented and Working
