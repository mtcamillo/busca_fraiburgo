import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class ImageUploadService {
  static final _picker = ImagePicker();

  static Future<String?> pickAndUploadStoreImage({
    required String storeId,
    bool alsoUpdateStoreRow = true,
  }) async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (xfile == null) return null;

    final Uint8List bytes = await xfile.readAsBytes();
    final ext = p.extension(xfile.name).toLowerCase();
    final safeExt = (ext.isEmpty || ext == '.jpeg') ? '.jpg' : ext; 
    final filename = '${DateTime.now().millisecondsSinceEpoch}$safeExt';
    final objectPath = 'stores/$storeId/$filename';

    await SupabaseService.client.storage
        .from('store-images')
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final publicUrl = SupabaseService.client.storage
        .from('store-images')
        .getPublicUrl(objectPath);

    if (alsoUpdateStoreRow) {
      await SupabaseService.client
          .from('stores')
          .update({'image_url': publicUrl})
          .eq('id', storeId);
    }

    return publicUrl;
  }
}
