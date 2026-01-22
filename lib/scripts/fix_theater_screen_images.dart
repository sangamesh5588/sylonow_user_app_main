import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Script to convert base64-encoded theater screen images to Supabase Storage URLs
///
/// This script:
/// 1. Finds theater_screens with base64-encoded images
/// 2. Converts base64 strings to image files
/// 3. Uploads images to Supabase Storage
/// 4. Updates the database with proper image URLs
///
/// Run this script once to fix the image fetching issue.

const String supabaseUrl = 'https://txgszrxjyanazlrupaty.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4Z3N6cnhqeWFuYXpscnVwYXR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzUzNzc1NjIsImV4cCI6MjA1MDk1MzU2Mn0.wFYFhbChHlC0wqDhSe9T6Qu2Xgj4cWz_gzAXPn4Qf1g';

void main() async {
  print('🎬 Starting theater screen image conversion...');

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final supabase = Supabase.instance.client;

  try {
    // Step 1: Find screens with base64 images
    print('📋 Finding screens with base64 images...');
    final response = await supabase
        .from('theater_screens')
        .select('id, screen_name, theater_id, images')
        .eq('is_active', true);

    final screens = response as List<dynamic>;
    print('✅ Found ${screens.length} active screens');

    int convertedCount = 0;
    int skippedCount = 0;

    // Step 2: Process each screen
    for (final screen in screens) {
      final String screenId = screen['id'];
      final String screenName = screen['screen_name'];
      final String theaterId = screen['theater_id'];
      final List<dynamic> images = screen['images'] ?? [];

      if (images.isEmpty) {
        print('⚠️  Screen "$screenName" has no images, skipping...');
        skippedCount++;
        continue;
      }

      final List<String> convertedUrls = [];
      bool needsConversion = false;

      // Step 3: Check each image
      for (int i = 0; i < images.length; i++) {
        final String imageData = images[i];

        // Check if it's already a URL
        if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
          print('✓ Image $i for "$screenName" is already a URL');
          convertedUrls.add(imageData);
          continue;
        }

        // Check if it's base64
        if (imageData.length < 1000) {
          print('⚠️  Image $i for "$screenName" is too short, might be invalid');
          continue;
        }

        needsConversion = true;
        print('🔄 Converting image $i for "$screenName" (base64 → URL)...');

        try {
          // Extract base64 data (handle data:image/xxx;base64, prefix if present)
          String base64Data = imageData;
          if (imageData.contains(',')) {
            base64Data = imageData.split(',').last;
          }

          // Decode base64 to bytes
          final Uint8List imageBytes = base64Decode(base64Data);

          // Determine file extension from base64 header
          String extension = 'jpg';
          if (imageData.contains('data:image/png')) {
            extension = 'png';
          } else if (imageData.contains('data:image/jpeg') || imageData.contains('data:image/jpg')) {
            extension = 'jpg';
          } else if (imageData.contains('data:image/webp')) {
            extension = 'webp';
          }

          // Create unique filename
          final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          final String fileName = 'theater_screen_${screenId}_${timestamp}_$i.$extension';
          final String storagePath = '$theaterId/theater-screens/$fileName';

          print('   📤 Uploading to: $storagePath');

          // Upload to Supabase Storage
          await supabase.storage
              .from('service-listing-media')
              .uploadBinary(
                storagePath,
                imageBytes,
                fileOptions: FileOptions(
                  contentType: 'image/$extension',
                  upsert: false,
                ),
              );

          // Get public URL
          final String publicUrl = supabase.storage
              .from('service-listing-media')
              .getPublicUrl(storagePath);

          convertedUrls.add(publicUrl);
          print('   ✅ Uploaded: $publicUrl');

        } catch (e) {
          print('   ❌ Error converting image $i for "$screenName": $e');
          // Keep original if conversion fails
          if (images[i] != null) {
            convertedUrls.add(images[i]);
          }
        }
      }

      // Step 4: Update database if any conversions were made
      if (needsConversion && convertedUrls.isNotEmpty) {
        try {
          await supabase
              .from('theater_screens')
              .update({'images': convertedUrls})
              .eq('id', screenId);

          print('✅ Updated screen "$screenName" with ${convertedUrls.length} image URLs');
          convertedCount++;
        } catch (e) {
          print('❌ Error updating screen "$screenName": $e');
        }
      } else if (!needsConversion) {
        print('✓ Screen "$screenName" already has proper URLs, skipping...');
        skippedCount++;
      }
    }

    print('\n🎉 Conversion complete!');
    print('   ✅ Converted: $convertedCount screens');
    print('   ⏭️  Skipped: $skippedCount screens (already have URLs)');

  } catch (e, stackTrace) {
    print('❌ Fatal error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }

  exit(0);
}
