# Guide: Editing Encrypted Backup Files

**Version:** 1.1.0+1
**Date:** January 16, 2025

---

## 🎯 Overview

This guide explains how to edit encrypted backup files when you need to manually modify the database through JSON editing. Since backups are encrypted by default, you need to decrypt them first, edit, and then re-encrypt.

---

## 🛠️ Tools Available

### 1. BackupEditor Class
**Location:** `lib/utils/backup_editor.dart`

A Dart utility class for programmatic backup manipulation.

### 2. Command-Line Interface (CLI)
**Location:** `scripts/backup_editor_cli.dart`

A user-friendly command-line tool for quick operations.

---

## 🚀 Quick Start (Recommended Method)

### Step 1: Check Backup Type

```bash
dart run scripts/backup_editor_cli.dart check backup_encrypted.json
```

**Output:**
```
File: backup_encrypted.json
Status: ✅ ENCRYPTED
Format version: 2.0
Password protected: Yes
```

### Step 2: Decrypt Backup

**For device-based encryption:**
```bash
dart run scripts/backup_editor_cli.dart decrypt backup_encrypted.json backup_plain.json
```

**For password-protected encryption:**
```bash
dart run scripts/backup_editor_cli.dart decrypt backup_encrypted.json backup_plain.json --password "MyPassword123"
```

**Output:**
```
Reading encrypted backup from: backup_encrypted.json
Backup info:
  - Encrypted: true
  - Password protected: true
  - Format version: 2.0
Decrypting with password...
✅ Successfully decrypted to: backup_plain.json
You can now edit the JSON file manually.
```

### Step 3: Edit the JSON File

Open `backup_plain.json` in any text editor (VS Code, Notepad++, Sublime, etc.) and make your changes.

**Example JSON Structure:**
```json
{
  "schemaVersion": 1,
  "createdAt": "2025-01-16T12:34:56.789Z",
  "collections": {
    "cold_storages": [
      {
        "id": "storage1",
        "data": {
          "name": "Main Storage",
          "location": "Building A"
        }
      }
    ],
    "products": [
      {
        "id": "product1",
        "data": {
          "name": "Product A",
          "category": "Category 1"
        }
      }
    ],
    "brands": [...],
    "companies": [...],
    "receipts": [...],
    "deliveries": [...]
  }
}
```

### Step 4: Validate Your Changes

```bash
dart run scripts/backup_editor_cli.dart validate backup_plain.json
```

**Output:**
```
Validating backup JSON...
✅ Backup JSON is valid
Schema version: 1
Collections: cold_storages, products, brands, companies, receipts, deliveries
```

### Step 5: Re-encrypt

```bash
dart run scripts/backup_editor_cli.dart encrypt backup_plain.json backup_new_encrypted.json --password "MyPassword123"
```

**Output:**
```
Reading plain backup from: backup_plain.json
Encrypting with password...
✅ Successfully encrypted to: backup_new_encrypted.json
Backup is now encrypted and ready to restore.
```

### Step 6: Import Back to App

Use the app's restore function to import `backup_new_encrypted.json` with your password.

---

## 💻 Programmatic Method (Using Dart Code)

### Example: Complete Edit Workflow

```dart
import 'package:cold_storage/utils/backup_editor.dart';

Future<void> editBackup() async {
  final editor = BackupEditor();

  // Step 1: Check backup type
  await editor.checkBackupType('backup_encrypted.json');

  // Step 2: Decrypt
  await editor.decryptForEditing(
    encryptedPath: 'backup_encrypted.json',
    plainPath: 'backup_editable.json',
    password: 'MyPassword123',
  );

  // Step 3: Edit backup_editable.json manually here
  // (Open in text editor and modify)

  print('Pausing for manual edit. Press Enter when done...');
  stdin.readLineSync();

  // Step 4: Validate
  final isValid = await editor.validateBackupJson('backup_editable.json');
  if (!isValid) {
    print('❌ Validation failed!');
    return;
  }

  // Step 5: Re-encrypt
  await editor.reencryptAfterEditing(
    plainPath: 'backup_editable.json',
    encryptedPath: 'backup_new_encrypted.json',
    password: 'MyPassword123',
  );

  print('✅ Done! Import backup_new_encrypted.json into the app.');
}
```

### Individual Operations

```dart
final editor = BackupEditor();

// Decrypt only
await editor.decryptBackupFile(
  inputPath: 'encrypted.json',
  outputPath: 'plain.json',
  password: 'MyPass',
);

// Encrypt only
await editor.encryptBackupFile(
  inputPath: 'plain.json',
  outputPath: 'encrypted.json',
  password: 'MyPass',
);

// Check type
await editor.checkBackupType('backup.json');

// Validate
final isValid = await editor.validateBackupJson('plain.json');
```

---

## 📋 Common Editing Scenarios

### Scenario 1: Update Product Information

**Goal:** Change product names or categories

1. Decrypt backup
2. Find the product in `collections.products[]`
3. Modify the `data` fields
4. Validate and re-encrypt

**Example:**
```json
{
  "collections": {
    "products": [
      {
        "id": "prod123",
        "data": {
          "name": "Old Product Name",  // Change this
          "category": "Old Category"    // Change this
        }
      }
    ]
  }
}
```

### Scenario 2: Delete Corrupted Records

**Goal:** Remove problematic entries

1. Decrypt backup
2. Find and delete the problematic object from the array
3. Validate and re-encrypt

**Example:**
```json
{
  "collections": {
    "receipts": [
      {
        "id": "receipt1",
        "data": { ... }
      },
      // DELETE THIS CORRUPTED ENTRY:
      // {
      //   "id": "receipt2_corrupted",
      //   "data": { "invalid": "data" }
      // },
      {
        "id": "receipt3",
        "data": { ... }
      }
    ]
  }
}
```

### Scenario 3: Bulk Update References

**Goal:** Update all references to a cold storage ID

1. Decrypt backup
2. Use text editor's find & replace
3. Replace all instances of old ID with new ID
4. Validate and re-encrypt

**Example Find & Replace:**
- Find: `"cold_storage_id":"old_id_123"`
- Replace: `"cold_storage_id":"new_id_456"`

### Scenario 4: Add Missing Fields

**Goal:** Add new fields to existing records

1. Decrypt backup
2. Add fields to relevant documents
3. Validate and re-encrypt

**Example:**
```json
{
  "id": "company1",
  "data": {
    "name": "Company A",
    "email": "contact@companya.com",
    "phone": "+1234567890",
    // ADD NEW FIELD:
    "tax_id": "TAX123456"
  }
}
```

---

## ⚠️ Important Considerations

### DO's ✅

1. **Always backup original file**
   ```bash
   cp backup_encrypted.json backup_encrypted_BACKUP.json
   ```

2. **Validate after editing**
   ```bash
   dart run scripts/backup_editor_cli.dart validate backup_plain.json
   ```

3. **Test on non-production data first**
   - Create test backup
   - Edit and restore test backup
   - Verify results before using on production

4. **Use JSON validation tools**
   - VS Code has built-in JSON validation
   - Online validators: jsonlint.com
   - Command line: `python -m json.tool backup.json`

5. **Keep consistent formatting**
   - Use 2-space indentation
   - Keep same structure as original
   - Don't modify `schemaVersion` unless you know what you're doing

6. **Document your changes**
   ```bash
   # Keep a log of what you changed
   echo "2025-01-16: Updated product names in categories" >> edit_log.txt
   ```

### DON'Ts ❌

1. **Don't edit without backing up**
   - Always keep original encrypted file
   - Keep multiple backup copies

2. **Don't modify encrypted files directly**
   - Always decrypt first
   - Never try to edit encrypted JSON

3. **Don't skip validation**
   - Invalid JSON will fail import
   - Validation catches 90% of errors

4. **Don't change schema version carelessly**
   ```json
   // DON'T CHANGE THIS unless you know what you're doing:
   "schemaVersion": 1
   ```

5. **Don't forget to delete plain JSON after re-encrypting**
   ```bash
   # After successful re-encryption:
   rm backup_plain.json
   ```

6. **Don't share plain JSON files**
   - They contain unencrypted sensitive data
   - Only share encrypted backups with proper password

---

## 🔍 Troubleshooting

### Error: "File is not encrypted or is already plain JSON"

**Problem:** Trying to decrypt a plain JSON file

**Solution:** Check file type first:
```bash
dart run scripts/backup_editor_cli.dart check backup.json
```

If already plain, skip decryption step.

---

### Error: "This backup is password-protected. Please provide the password."

**Problem:** Missing password for password-protected backup

**Solution:** Add `--password` flag:
```bash
dart run scripts/backup_editor_cli.dart decrypt backup.json plain.json --password "YourPass"
```

---

### Error: "Invalid JSON format"

**Problem:** Syntax error in edited JSON

**Solution:**
1. Use JSON validator to find error
2. Common issues:
   - Missing comma between array items
   - Trailing comma after last item
   - Unescaped quotes in strings
   - Mismatched brackets `{[}]`

**Example Error:**
```json
// WRONG - trailing comma:
{
  "name": "Product",
  "category": "Category",  // ← Remove this comma
}

// CORRECT:
{
  "name": "Product",
  "category": "Category"
}
```

---

### Error: "Missing required field: schemaVersion"

**Problem:** Accidentally deleted required field

**Solution:** Add it back:
```json
{
  "schemaVersion": 1,
  "createdAt": "2025-01-16T12:34:56.789Z",
  "collections": { ... }
}
```

---

### Error: "Validation failed"

**Problem:** Backup structure is invalid

**Solution:** Check:
- `schemaVersion` field exists
- `collections` field exists and is an object
- Each collection is an array
- Each document has `id` and `data` fields

**Correct Structure:**
```json
{
  "schemaVersion": 1,
  "createdAt": "2025-01-16T12:34:56.789Z",
  "collections": {
    "products": [
      {
        "id": "product_id",
        "data": {
          // Actual product data
        }
      }
    ]
  }
}
```

---

## 📚 Advanced Topics

### Escaping Special Characters

When editing JSON, escape these characters in strings:
- `"` becomes `\"`
- `\` becomes `\\`
- Newline becomes `\n`
- Tab becomes `\t`

**Example:**
```json
{
  "description": "Product with \"quotes\" and backslash \\"
}
```

### Handling Timestamps

Firestore timestamps are stored in ISO 8601 format:

**Original Firestore:**
```dart
Timestamp(seconds: 1705411200, nanoseconds: 0)
```

**In Backup JSON:**
```json
{
  "__type__": "timestamp",
  "value": "2025-01-16T12:00:00.000Z"
}
```

**To modify:** Change the ISO string but keep the format.

### Handling GeoPoints

**In Backup JSON:**
```json
{
  "__type__": "geopoint",
  "lat": 40.7128,
  "lng": -74.0060
}
```

**To modify:** Change `lat` and `lng` values.

### Handling Document References

**In Backup JSON:**
```json
{
  "__type__": "docRef",
  "path": "cold_storages/storage123"
}
```

**To modify:** Change the path string, but keep format `collection/document_id`.

---

## 🔒 Security Best Practices

### 1. Handle Plain JSON Securely

```bash
# Decrypt to a secure temporary location
dart run scripts/backup_editor_cli.dart decrypt encrypted.json /tmp/backup_plain.json --password "Pass"

# Edit
nano /tmp/backup_plain.json

# Re-encrypt
dart run scripts/backup_editor_cli.dart encrypt /tmp/backup_plain.json encrypted_new.json --password "Pass"

# Securely delete plain file
shred -u /tmp/backup_plain.json  # Linux
# or
rm -P /tmp/backup_plain.json     # macOS
# or
del /tmp/backup_plain.json        # Windows (use SDelete for secure delete)
```

### 2. Use Strong Passwords

```bash
# Good password:
--password "MyC0mpl3x!P@ssw0rd#2025"

# Bad password:
--password "123456"
```

### 3. Don't Commit to Version Control

**.gitignore:**
```
# Ignore decrypted backups
*_plain.json
*_editable.json
backup_plain_*.json

# Keep encrypted backups in a separate secure location
```

---

## 🎓 Example Workflows

### Workflow 1: Quick Product Update

```bash
# 1. Decrypt
dart run scripts/backup_editor_cli.dart decrypt backup.json plain.json -p "Pass123"

# 2. Edit with VS Code
code plain.json
# (Make changes, save, close)

# 3. Validate
dart run scripts/backup_editor_cli.dart validate plain.json

# 4. Re-encrypt
dart run scripts/backup_editor_cli.dart encrypt plain.json backup_new.json -p "Pass123"

# 5. Clean up
rm plain.json

# 6. Import in app
# Use app's restore function with backup_new.json
```

### Workflow 2: Complex Multi-Collection Edit

```bash
# 1. Create working directory
mkdir backup_editing
cd backup_editing

# 2. Copy original backup
cp ../backup_encrypted.json ./original.json

# 3. Decrypt
dart run ../scripts/backup_editor_cli.dart decrypt original.json editable.json -p "Pass"

# 4. Create checkpoint
cp editable.json editable_checkpoint.json

# 5. Edit with your favorite editor
vim editable.json

# 6. If needed, revert to checkpoint
# cp editable_checkpoint.json editable.json

# 7. Validate
dart run ../scripts/backup_editor_cli.dart validate editable.json

# 8. Re-encrypt
dart run ../scripts/backup_editor_cli.dart encrypt editable.json final.json -p "Pass"

# 9. Test import
# (Use app to import final.json on test device)

# 10. If successful, clean up
rm editable.json editable_checkpoint.json
mv final.json ../backup_edited_$(date +%Y%m%d).json
cd ..
rm -rf backup_editing
```

---

## 📊 File Naming Convention

Use clear, descriptive names for your backup files:

```
backup_encrypted_YYYYMMDD_HHMM.json       - Original encrypted
backup_plain_YYYYMMDD_HHMM.json           - Decrypted for editing
backup_edited_YYYYMMDD_HHMM.json          - Re-encrypted after editing
backup_backup_YYYYMMDD_HHMM.json          - Safety backup
```

**Example:**
```
backup_encrypted_20250116_1430.json
backup_plain_20250116_1430.json
backup_edited_20250116_1445.json
backup_backup_20250116_1430.json
```

---

## ✅ Checklist for Safe Editing

Before you start:
- [ ] Backup original encrypted file to safe location
- [ ] Have password written down securely
- [ ] Have tested restore process before

During editing:
- [ ] Decrypt to temporary location
- [ ] Use proper JSON editor with syntax highlighting
- [ ] Make one type of change at a time
- [ ] Create checkpoint copies before major changes

After editing:
- [ ] Validate JSON structure
- [ ] Verify all brackets/braces match
- [ ] Check for trailing commas
- [ ] Re-encrypt successfully
- [ ] Test restore on non-production device first
- [ ] Delete plain JSON files
- [ ] Keep encrypted backup secure

---

## 🆘 Emergency Recovery

### If you accidentally corrupted the backup:

1. **Revert to original:**
   ```bash
   cp backup_encrypted_BACKUP.json backup_encrypted.json
   ```

2. **If no backup exists:**
   - Check app's automatic backups (if enabled)
   - Check cloud storage sync (Google Drive, Dropbox, etc.)
   - Restore from device if backup was device-based

3. **If JSON is partially corrupted:**
   - Use online JSON repair tools
   - Manually fix brackets/commas
   - Remove corrupted sections and re-import remaining data

---

## 📞 Support

For issues with backup editing:

1. Check this guide first
2. Validate JSON at jsonlint.com
3. Review DATA_ENCRYPTION_MODULE.md for encryption details
4. Check app logs for specific error messages

---

## 🎉 Summary

You now have complete control over encrypted backups:

✅ **Decrypt** encrypted backups to plain JSON
✅ **Edit** JSON with any text editor
✅ **Validate** changes before re-encrypting
✅ **Re-encrypt** for secure storage
✅ **CLI tool** for easy command-line operations
✅ **Programmatic API** for automated workflows
✅ **Safe practices** to avoid data loss

**Remember:** Always backup before editing!

---

*Guide created on January 16, 2025*
*Cold Storage App v1.1.0+1*
