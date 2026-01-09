# Service Provider Category Migration Script

यह script existing approved service providers के लिए `serviceCategoryId` और `serviceCategoryName` fields को `partner_requests` से `users` collection में copy करता है।

## कब use करें

जब पुराने service providers को category-wise list में show करना हो।

## कैसे चलाएं

### Option 1: Direct run (recommended)

```powershell
dart run scripts/migrate_service_provider_categories.dart
```

### Option 2: Compile और run

```powershell
dart compile exe scripts/migrate_service_provider_categories.dart -o migrate.exe
.\migrate.exe
```

## क्या होगा

1. सभी approved service provider partner requests fetch करेगा
2. हर request के लिए corresponding user document find करेगा
3. `serviceCategoryId` और `serviceCategoryName` fields copy करेगा
4. Summary report show करेगा

## Safety features

- केवल approved requests process होंगे
- केवल service_provider role वाले users update होंगे
- पहले से category fields वाले users skip होंगे
- हर step की detailed logging होगी

## Expected output

```
🚀 Starting Service Provider Category Migration...

📋 Fetching approved service provider partner requests...
   Found 3 approved service provider requests

👤 Processing: alu@example.com
   ✅ Updated: Added category "Painter" (ID: abc123)

👤 Processing: test@example.com
   ℹ️  Skipped: Already has serviceCategoryId

═══════════════════════════════════════════════════════════
📊 Migration Summary:
   ✅ Successfully updated: 1 users
   ⚠️  Skipped: 2 users
   ❌ Errors: 0 users
═══════════════════════════════════════════════════════════

🎉 Migration completed successfully!
   Service providers should now appear in their respective categories.

✨ Done!
```

## Notes

- एक बार चलाना काफी है
- पुराने data को affect नहीं करेगा
- Rollback की जरूरत नहीं (केवल missing fields add होते हैं)
- Live database पर safely चला सकते हैं
