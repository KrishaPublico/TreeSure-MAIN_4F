# Template Download Feature - Setup Guide

## Overview
The application now supports downloading templates for each application type. Applicants can download provided templates to help them fill out their documents correctly.

## How It Works

1. **Template Storage**: Templates are stored in Firebase Storage and their URLs are saved in Firestore
2. **Template Display**: When a template exists for a document, a "Download Template" button appears
3. **Template Access**: Clicking the button opens the template in the user's default application

## Firestore Structure

Templates are stored in the following Firestore collection:

```
application_templates/
  ├── ctpo/
  │   ├── "Letter of Application": "https://firebasestorage.../template.pdf"
  │   ├── "Special Power of Attorney (SPA) – Applicable if the client is a representative": "https://..."
  │   └── ...
  ├── ptc/
  │   ├── "Letter request": "https://..."
  │   ├── "Barangay Certification": "https://..."
  │   └── ...
  ├── pltp/
  │   ├── "Application Letter": "https://..."
  │   └── ...
  └── splt/
      ├── "Application Letter": "https://..."
      └── ...
```

## Setup Instructions

### Step 1: Upload Templates to Firebase Storage

1. Go to Firebase Console → Storage
2. Create a folder called `templates`
3. Upload your template files (PDF, DOC, DOCX)
4. Copy the download URL for each template

### Step 2: Add Template URLs to Firestore

Using Firebase Console or your admin interface:

**For CTPO (Certificate to Cut Planted Trees on Private Land):**
```javascript
// In Firestore Console, create document:
Collection: application_templates
Document ID: ctpo

// Add fields with document titles as keys and template URLs as values:
{
  "Letter of Application": "https://firebasestorage.googleapis.com/.../letter_template.pdf",
  "Special Power of Attorney (SPA) – Applicable if the client is a representative": "https://firebasestorage.googleapis.com/.../spa_template.pdf",
  // Add more as needed
}
```

**For Permit to Cut (PTC):**
```javascript
Collection: application_templates
Document ID: ptc

{
  "Letter request": "https://firebasestorage.googleapis.com/.../ptc_letter_template.pdf",
  "Barangay Certification": "https://firebasestorage.googleapis.com/.../barangay_cert_template.pdf",
  // Add more as needed
}
```

**For PLTP (Private Land Timber Permit):**
```javascript
Collection: application_templates
Document ID: pltp

{
  "Application Letter": "https://firebasestorage.googleapis.com/.../pltp_application_template.pdf",
  "LGU Endorsement/Certification of No Objection": "https://firebasestorage.googleapis.com/.../lgu_endorsement_template.pdf",
  // Add more as needed
}
```

**For SPLT (Special Land Timber Permit):**
```javascript
Collection: application_templates
Document ID: splt

{
  "Application Letter": "https://firebasestorage.googleapis.com/.../splt_application_template.pdf",
  // Add more as needed
}
```

### Step 3: Exact Document Title Matching

**IMPORTANT**: The field names in Firestore must **exactly match** the document titles in the app. Here are the exact titles for each application type:

#### CTPO Document Titles:
- `Letter of Application`
- `OCT, TCT, Judicial Title, CLOA, Tax Declared Alienable and Disposable Lands`
- `Data on the number of seedlings planted, species and area planted`
- `Endorsement from concerned LGU interposing no objection to the cutting of trees`
- `If the trees to be cut fall within one barangay, endorsement from the Barangay Captain`
- `If within more than one barangay, endorsement from the Municipal/City Mayor or all Captains`
- `If within more than one municipality/city, endorsement from the Provincial Governor or all Mayors`
- `Special Power of Attorney (SPA) – Applicable if the client is a representative`

#### PTC Document Titles:
- `Letter request`
- `Barangay Certification`
- `Certified copy of Title / Electronic Copy of Title`
- `Special Power of Attorney (SPA) / Deed of Sale from the owner of the Land Title`

#### PLTP Document Titles:
- `Application Letter`
- `LGU Endorsement/Certification of No Objection`
- `Endorsement from concerned LGU`
- `Barangay Captain Endorsement`
- `Municipal/City Mayor Endorsement`
- `Provincial Governor Endorsement`
- `Environmental Compliance Certificate (ECC)/Certificate of Non-Coverage (CNC)`
- `Utilization Plan`
- `Endorsement by Local Agrarian Reform Officer`
- `PTA/Organization Resolution`

#### SPLT Document Titles:
- `Application Letter`
- `LGU Endorsement/Certification of No Objection`
- `Endorsement from concerned LGU interposing no objection to the cutting of trees under the following conditions`
- `If the trees to be cut fall within one barangay, an endorsement from the Barangay Captain shall be secured`
- `If the trees to be cut fall within more than one barangay, endorsement shall be secured either from the Municipal/City Mayor or all the Barangay Captains concerned`
- `If the trees to be cut fall within more than one municipality/city, endorsement shall be secured either from the Provincial Governor or all the Municipality/City Mayors concerned`
- `Environmental Compliance Certificate (ECC)/Certificate of Non-Coverage (CNC)`
- `Utilization Plan`
- `Endorsement by Local Agrarian Reform Officer`
- `PTA/Organization Resolution`

## User Experience

When a template is available:
1. A blue "Download Template" button with a download icon appears below the document title
2. Clicking the button opens the template in a new window/tab or downloads it
3. The button is styled consistently across all application types

When no template is available:
- The download button doesn't appear
- Users proceed to upload their documents normally

## Notes

- Templates are optional - documents without templates will work normally
- You can add templates gradually (not all documents need templates at once)
- Templates can be updated by changing the URL in Firestore
- Supported template formats: PDF, DOC, DOCX (recommended: PDF for universal compatibility)

## Firebase Security Rules

Ensure your Firebase Storage rules allow read access to templates:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /templates/{allPaths=**} {
      allow read: if request.auth != null; // Authenticated users can download templates
    }
  }
}
```

## Testing

1. Add at least one template URL to Firestore for a specific application type
2. Navigate to that application form in the app
3. Verify the "Download Template" button appears for documents with templates
4. Click the button and confirm the template opens/downloads correctly

## Troubleshooting

**Button not appearing:**
- Check if the document title in Firestore exactly matches the one in the app
- Verify the template URL is valid
- Check browser console for errors

**Template won't open:**
- Verify the Firebase Storage URL is publicly accessible or the user is authenticated
- Check Firebase Storage security rules
- Ensure the URL hasn't expired (if using signed URLs)

**Wrong template downloads:**
- Double-check the document title matches exactly (case-sensitive)
- Verify you're looking at the correct application type document in Firestore
