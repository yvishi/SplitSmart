/// SplitSmart — Receipt image uploader.
///
/// Uploads a compressed receipt image to Firebase Storage at:
///   receipts/{uid}/{expenseId}.jpg
/// and returns the public download URL.
///
/// The URL is stored in [Expense.receiptImagePath] so the expense detail
/// screen can show an attached receipt thumbnail.

import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class ReceiptStorageService {
  static final _storage = FirebaseStorage.instance;

  /// Upload [imageFile] to Storage under [uid]'s receipts folder.
  ///
  /// [expenseId] is used as the filename so re-uploads overwrite the same path.
  /// Returns the public download URL on success, null on any error.
  static Future<String?> upload({
    required File imageFile,
    required String uid,
    required String expenseId,
  }) async {
    try {
      final ref = _storage.ref('receipts/$uid/$expenseId.jpg');
      final bytes = await imageFile.readAsBytes();
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('⚠️ [ReceiptStorage] upload failed: $e');
      return null;
    }
  }

  /// Upload raw [bytes] (already compressed) instead of a file.
  static Future<String?> uploadBytes({
    required Uint8List bytes,
    required String uid,
    required String expenseId,
  }) async {
    try {
      final ref = _storage.ref('receipts/$uid/$expenseId.jpg');
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('⚠️ [ReceiptStorage] uploadBytes failed: $e');
      return null;
    }
  }

  /// Delete a receipt by its full Storage path (for cleanup when expense deleted).
  static Future<void> delete(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('⚠️ [ReceiptStorage] delete failed: $e');
    }
  }
}
