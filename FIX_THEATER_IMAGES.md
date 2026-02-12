# Theater Screen Image Fix

## Problem

The theater screen listing was failing to display images because some theater screens in the database have **base64-encoded images** stored directly in the `images` column, while the Flutter app expects **image URLs** (Supabase Storage URLs).

### Error Details

- **Location**: Theater screens selection screen ([lib/features/theater/screens/theater_screens_selection_screen.dart:196](lib/features/theater/screens/theater_screens_selection_screen.dart#L196))
- **Component**: `CachedNetworkImage`
- **Issue**: Trying to fetch base64 strings as network URLs
- **Affected Screens**: 2 out of 15 theater screens
  - Screen ID: `fb8d70aa-e7c7-4c02-88c3-cb411636b3aa` (name: "fghh")
  - Screen ID: `35351705-406a-438a-9f70-40e8a9385b5a` (name: "Test Screen")

## Solution

A conversion script has been created to:
1. Identify theater screens with base64-encoded images
2. Convert base64 strings to actual image files
3. Upload images to Supabase Storage
4. Update the database with proper Supabase Storage URLs

## How to Run the Fix

### Option 1: Using the Batch Script (Windows)

Simply double-click the batch file:
```
scripts/run_fix_images.bat
```

### Option 2: Using Dart Command (All Platforms)

Run from the project root:
```bash
dart run lib/scripts/fix_theater_screen_images.dart
```

### Option 3: Manual Execution (Alternative)

If you prefer to fix it manually via Supabase Dashboard:

1. Go to [Supabase Storage](https://txgszrxjyanazlrupaty.supabase.co/project/default/storage/buckets/service-listing-media)
2. For each affected screen:
   - Download the base64 image data
   - Convert to image file using online tool (e.g., base64-to-image converter)
   - Upload to Storage bucket: `service-listing-media/{theater_id}/theater-screens/`
   - Update the `theater_screens.images` column with the new URL

## Expected Output

When you run the script, you should see:

```
🎬 Starting theater screen image conversion...
📋 Finding screens with base64 images...
✅ Found 15 active screens
✓ Image 0 for "Premium theatre" is already a URL
...
🔄 Converting image 0 for "fghh" (base64 → URL)...
   📤 Uploading to: {theater_id}/theater-screens/theater_screen_{id}_{timestamp}_0.jpg
   ✅ Uploaded: https://txgszrxjyanazlrupaty.supabase.co/storage/v1/object/public/...
✅ Updated screen "fghh" with 1 image URLs
...
🎉 Conversion complete!
   ✅ Converted: 2 screens
   ⏭️  Skipped: 13 screens (already have URLs)
```

## Verification

After running the script, verify the fix:

1. **Check Database**:
```sql
SELECT screen_name, images[1]
FROM theater_screens
WHERE is_active = true
AND (id = 'fb8d70aa-e7c7-4c02-88c3-cb411636b3aa'
     OR id = '35351705-406a-438a-9f70-40e8a9385b5a');
```

The `images[1]` values should now be URLs starting with `https://txgszrxjyanazlrupaty.supabase.co/storage/`

2. **Test in App**:
   - Run the Flutter app
   - Navigate to: Home → Theater section
   - Select a theater
   - Verify all screens display images correctly

## Prevention

To prevent this issue in the future:

### For Developers

When creating new theater screens through the admin panel or API:

1. **ALWAYS upload images to Supabase Storage first**
2. **NEVER store base64 strings in the database**
3. Use the `ImageUploadService` class for proper image handling

### Correct Implementation

```dart
// ✅ CORRECT: Upload to Storage first
final file = XFile('/path/to/image.jpg');
final imageUrl = await ImageUploadService().uploadImage(
  file,
  bucket: 'service-listing-media',
  path: '$theaterId/theater-screens/',
);

// Then save the URL to database
await supabase
  .from('theater_screens')
  .insert({'images': [imageUrl]});
```

```dart
// ❌ WRONG: Don't save base64 to database
final base64Image = base64Encode(imageBytes);
await supabase
  .from('theater_screens')
  .insert({'images': [base64Image]});  // DON'T DO THIS!
```

## Technical Details

### Database Schema

Table: `theater_screens`
- Column: `images` (type: `text[]` - array of text)
- Expected: Array of Supabase Storage URLs
- Format: `https://txgszrxjyanazlrupaty.supabase.co/storage/v1/object/public/service-listing-media/{path}/{filename}`

### Storage Configuration

- Bucket: `service-listing-media`
- Path pattern: `{theater_id}/theater-screens/{filename}`
- Public access: Yes (required for `CachedNetworkImage`)

## Related Files

- Script: [lib/scripts/fix_theater_screen_images.dart](lib/scripts/fix_theater_screen_images.dart)
- Batch runner: [scripts/run_fix_images.bat](scripts/run_fix_images.bat)
- Affected screen: [lib/features/theater/screens/theater_screens_selection_screen.dart:196](lib/features/theater/screens/theater_screens_selection_screen.dart#L196)
- Model: [lib/features/theater/models/theater_screen_model.dart:23](lib/features/theater/models/theater_screen_model.dart#L23)
- Repository: [lib/features/theater/repositories/theater_repository.dart:703-741](lib/features/theater/repositories/theater_repository.dart#L703-L741)

## Support

If you encounter any issues:

1. Check the Supabase Storage bucket permissions
2. Verify your Supabase credentials in the script
3. Check the console output for specific error messages
4. Ensure you have write access to the `theater_screens` table

## Summary

✅ **Problem identified**: Base64 images stored in database instead of URLs
✅ **Solution created**: Automated conversion script
✅ **Affected screens**: 2 out of 15 theater screens
✅ **Prevention**: Developer guidelines added

Run the script once to fix the issue permanently.
