# Forester Tree Registration Guide

## Overview
This document explains how foresters register trees in the TreeSure application, including the data fields, workflow, and Firestore structure for admin reference.

---

## Three Types of Tree Registration

### 1. **CTPO (Tree Tagging) Registration** - `ctpo_register_trees.dart`
Initial tree tagging/registration by CTPO foresters.

### 2. **PLTP (Cutting Registration)** - `pltp_register_trees.dart`
Tree cutting registration that references previously tagged trees.

### 3. **SPLTP (Special Cutting Registration)** - `spltp_register_trees.dart`
Special permit tree cutting registration.

---

## Data Fields & Input Methods

### Common Fields Across All Registration Types

| Field | Type | Input Method | Description |
|-------|------|--------------|-------------|
| `tree_id` | String | Auto-generated | Format: `T1`, `T2`, `T3`, etc. Based on count + 1 |
| `tree_no` | String | Auto-generated | Same as `tree_id` |
| `specie` | String | Manual input | Tree species name |
| `diameter` | Double | Manual input (cm) | Tree diameter in centimeters |
| `height` | Double | Manual input (m) | Tree height in meters |
| `volume` | Double | Auto-calculated | Formula: π × (diameter/2)² × height |
| `latitude` | Double | GPS fetch | Location latitude (6 decimal places) |
| `longitude` | Double | GPS fetch | Location longitude (6 decimal places) |
| `forester_id` | String | From session | ID of the forester registering the tree |
| `forester_name` | String | From session | Name of the forester |
| `appointment_id` | String | From navigation | Document ID of the appointment |
| `photo_url` | String | Image upload | Firebase Storage URL of tree photo |
| `qr_url` | String | Auto-generated | Firebase Storage URL of QR code |
| `timestamp` | Timestamp | Auto-generated | Server timestamp of registration |

### CTPO-Specific Fields
| Field | Type | Default Value | Description |
|-------|------|---------------|-------------|
| `tree_status` | String | `"Not Yet Ready"` | Status for cutting readiness |
| `tree_tagging_appointment_id` | String | `""` (empty) | Reference to tree tagging appointment |

### PLTP-Specific Fields
| Field | Type | Source | Description |
|-------|------|--------|-------------|
| `tree_tagging_appointment_id` | String | From selected tree | Document ID of the tree_tagging_appointment |
| `tree_status` | String | From selected tree | Inherited from tagged tree |
| **Selected Tree Dropdown** | - | Firestore query | PLTP loads trees from tree_tagging_appointment matching `applicantId` |

### SPLTP-Specific Fields
| Field | Type | Default Value | Description |
|-------|------|---------------|-------------|
| `tree_status` | String | `"Not Yet"` | Cutting status |

---

## Firestore Structure

### Path Pattern
```
appointments/{appointmentId}/tree_inventory/{treeId}
```

### Document Structure Example
```json
{
  "tree_id": "T1",
  "tree_no": "T1",
  "specie": "Mahogany",
  "diameter": 45.5,
  "height": 12.3,
  "volume": 20.15,
  "latitude": 14.599512,
  "longitude": 120.984222,
  "forester_id": "forester_123",
  "forester_name": "Juan Dela Cruz",
  "appointment_id": "appointment_abc123",
  "tree_tagging_appointment_id": "tagging_xyz789",
  "tree_status": "Not Yet Ready",
  "photo_url": "https://firebasestorage.googleapis.com/.../tree_photos/T1_1234567890.jpg",
  "qr_url": "https://firebasestorage.googleapis.com/.../tree_qrcodes/T1.png",
  "timestamp": "2025-11-17T10:30:45.123Z"
}
```

---

## Registration Workflows

### CTPO Tree Tagging Workflow
1. **Navigate** → Forester opens CTPO registration page with `appointmentId`
2. **Input Data** → Manually enter specie, diameter, height
3. **Fetch Location** → Get GPS coordinates via button press
4. **Upload Photo** → Optional tree photo from gallery
5. **Auto-Calculate** → Volume calculated automatically from diameter × height
6. **Submit** → Data saved to Firestore
7. **QR Generation** → QR code generated and uploaded to Firebase Storage
8. **Status Update** → Appointment status set to `"In Progress"`
9. **Clear Form** → Fields cleared for next tree registration

### PLTP Cutting Registration Workflow
1. **Navigate** → Forester opens PLTP registration page with `appointmentId` (cutting appointment)
2. **Load Trees** → System fetches trees from tree_tagging_appointment matching `applicantId`
3. **Select Tree** → Forester selects a tagged tree from dropdown
4. **Auto-Fill** → Form auto-fills with data from selected tree
5. **QR Scan (Alternative)** → Can scan QR code to load tree data
6. **Update/Confirm Data** → Forester can update measurements if needed
7. **Upload Photo** → Optional new photo
8. **Submit** → Data saved to cutting appointment's tree_inventory
9. **Link Appointments** → `tree_tagging_appointment_id` links back to original tagging
10. **Status Update** → Appointment status set to `"In Progress"`

### SPLTP Special Cutting Workflow
Similar to CTPO but with `tree_status` defaulting to `"Not Yet"`.

---

## QR Code Structure

### QR Payload Format (JSON)
```json
{
  "format": "treesure.v2",
  "inventory_doc_id": "T1",
  "appointment_id": "appointment_abc123",
  "tree_id": "T1",
  "tree_no": "T1",
  "tree_status": "Not Yet Ready",
  "tree_tagging_appointment_id": "tagging_xyz789",
  "specie": "Mahogany",
  "diameter": 45.5,
  "height": 12.3,
  "volume": 20.15,
  "latitude": 14.599512,
  "longitude": 120.984222,
  "forester_id": "forester_123",
  "forester_name": "Juan Dela Cruz",
  "photo_url": "https://...",
  "timestamp": "2025-11-17T10:30:45.123Z",
  "generated_at": "2025-11-17T10:30:46.456Z"
}
```

### QR Code Storage
- **Path**: `tree_qrcodes/{treeId}.png`
- **Format**: PNG image, 300x300 pixels
- **Generated**: After tree data is saved to Firestore
- **Linked**: `qr_url` field in tree document

---

## Firebase Storage Structure

### Tree Photos
```
tree_photos/
  ├── T1_1700123456789.jpg
  ├── T2_1700123567890.jpg
  └── T3_1700123678901.jpg
```

**Naming Convention**: `{treeId}_{timestamp}.jpg`

**Metadata**:
- `foresterId`: ID of the forester who uploaded
- `treeId`: Tree ID
- `timestamp`: Upload timestamp

### QR Codes
```
tree_qrcodes/
  ├── T1.png
  ├── T2.png
  └── T3.png
```

**Naming Convention**: `{treeId}.png`

---

## Appointment Status Management

### Status Values
- `"Pending"` → Initial state
- `"In Progress"` → Set when first tree is registered
- `"Completed"` → Set when all foresters complete their work

### Completion Tracking
Each appointment has a `completionStatus` map:
```json
{
  "completionStatus": {
    "forester_123": {
      "completed": true,
      "completedAt": "2025-11-17T10:30:45.123Z"
    },
    "forester_456": {
      "completed": false
    }
  }
}
```

### Multi-Forester Appointments
- Tracks completion per forester
- Status becomes `"Completed"` only when ALL foresters finish
- Uses `foresterIds` array to determine total count

---

## Key Relationships

### CTPO → PLTP Linking
1. **CTPO** creates trees in tree_tagging_appointment
2. **PLTP** queries tree_tagging_appointment by `applicantId`
3. **PLTP** saves tree to cutting_appointment with reference
4. **Link Field**: `tree_tagging_appointment_id` stores the doc ID

```
tree_tagging_appointment (CTPO)
  └── tree_inventory/T1
            ↓ (referenced by)
cutting_appointment (PLTP)
  └── tree_inventory/T1
        └── tree_tagging_appointment_id: "tagging_xyz789"
```

### Appointment → Tree Inventory
```
appointments/{appointmentId}
  ├── status: "In Progress"
  ├── foresterIds: ["forester_123", "forester_456"]
  ├── applicantId: "applicant_789"
  └── tree_inventory/ (subcollection)
        ├── T1/ (document)
        ├── T2/ (document)
        └── T3/ (document)
```

---

## Validation Rules

### Required Fields (All Types)
- ✅ Specie (non-empty string)
- ✅ Diameter (positive number)
- ✅ Height (positive number)
- ✅ Latitude (valid double)
- ✅ Longitude (valid double)

### Auto-Generated (No Input Required)
- Tree ID (T1, T2, T3...)
- Tree Number (same as Tree ID)
- Volume (calculated)
- Timestamp (server time)
- QR URL (after generation)

### Optional Fields
- Photo URL (can be empty string)

---

## Admin Query Examples

### Get All Trees for an Appointment
```dart
FirebaseFirestore.instance
  .collection('appointments')
  .doc(appointmentId)
  .collection('tree_inventory')
  .get();
```

### Get Trees by Forester
```dart
FirebaseFirestore.instance
  .collection('appointments')
  .doc(appointmentId)
  .collection('tree_inventory')
  .where('forester_id', isEqualTo: foresterId)
  .get();
```

### Get Trees by Status
```dart
FirebaseFirestore.instance
  .collection('appointments')
  .doc(appointmentId)
  .collection('tree_inventory')
  .where('tree_status', isEqualTo: 'Ready for Cutting')
  .get();
```

### Get Total Volume for Appointment
```dart
final snapshot = await FirebaseFirestore.instance
  .collection('appointments')
  .doc(appointmentId)
  .collection('tree_inventory')
  .get();

double totalVolume = snapshot.docs
  .map((doc) => doc.data()['volume'] as double)
  .reduce((a, b) => a + b);
```

### Get Tree Count per Forester
```dart
final snapshot = await FirebaseFirestore.instance
  .collection('appointments')
  .doc(appointmentId)
  .collection('tree_inventory')
  .get();

Map<String, int> countPerForester = {};
for (var doc in snapshot.docs) {
  String foresterId = doc.data()['forester_id'];
  countPerForester[foresterId] = (countPerForester[foresterId] ?? 0) + 1;
}
```

---

## Special Features

### PLTP Tree Dropdown
- **Source**: Queries `tree_tagging_appointment` collection
- **Filter**: Matches `applicantId` from cutting appointment
- **Purpose**: Allows PLTP foresters to select and reference previously tagged trees
- **Data Flow**: 
  1. Get cutting appointment's `applicantId`
  2. Query all tree_tagging_appointments with same `applicantId`
  3. Load their `tree_inventory` subcollections
  4. Display in dropdown with tree details

### PLTP QR Scanner
- **Tab**: Separate "Scan QR" tab in PLTP UI
- **Library**: `mobile_scanner` package
- **Function**: Scans QR from tagged trees to auto-fill form
- **Data**: Parses QR payload and fetches full tree data from Firestore

### PLTP Map View
- **Library**: `flutter_map` package
- **Features**:
  - Shows current forester location (blue marker)
  - Shows scanned tree location (red marker)
  - Displays path between locations
  - Distance and bearing information

---

## Error Handling

### Common Validation Errors
- `"⚠️ Please fill out all fields."` → Missing required field
- `"⚠️ Failed to get location: {error}"` → GPS permission/availability issue
- `"⚠️ Failed to pick image: {error}"` → Image picker error

### Submission Errors
- `"❌ Submission failed: {error}"` → Firestore write failed
- `"❌ QR generation/upload failed: {error}"` → QR creation error
- `"❌ Image upload error: {error}"` → Photo upload failed

### PLTP Specific Errors
- `"❌ Please select a tree from the dropdown."` → No tree selected
- `"❌ Appointment not found."` → Invalid appointmentId
- `"❌ No tagged trees found in the appointment"` → Empty tree_tagging_appointment

---

## Summary for Admin Dashboard

### Key Metrics to Track
1. **Total Trees per Appointment**
2. **Trees per Forester**
3. **Total Volume (cubic meters)**
4. **Average Tree Size (diameter/height)**
5. **Completion Status per Forester**
6. **Trees with/without Photos**
7. **Tree Status Distribution** (Ready/Not Ready)

### Important Collections
- `appointments/{appointmentId}` → Main appointment data
- `appointments/{appointmentId}/tree_inventory` → Tree documents
- `tree_tagging_appointment` → CTPO tagged trees
- `cutting_appointment` → PLTP/SPLTP cutting trees

### Critical Fields for Reports
- `tree_id`, `tree_no` → Identification
- `specie`, `diameter`, `height`, `volume` → Measurements
- `forester_id`, `forester_name` → Attribution
- `timestamp` → Timeline tracking
- `tree_status` → Cutting readiness
- `appointment_id`, `tree_tagging_appointment_id` → Relationships

---

## Version History
- **Format Version**: `treesure.v2` (in QR payload)
- **Last Updated**: November 17, 2025
- **Files**: `ctpo_register_trees.dart`, `pltp_register_trees.dart`, `spltp_register_trees.dart`, `tree_services.dart`
