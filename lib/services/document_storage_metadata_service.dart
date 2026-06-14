import 'dart:async';

import 'package:curavault_admin/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';

/// Privacy-safe document storage metadata instrumentation.
///
/// Writes to `public.document_storage_metadata` and MUST NOT include:
/// - file name / title / category
/// - any storage path
/// - extracted text / OCR text
///
/// This table is intended for control-site aggregate reporting only.
///
/// Best-effort: failures are swallowed and never break upload flows.
class DocumentStorageMetadataService {
  DocumentStorageMetadataService._();
  static final DocumentStorageMetadataService instance = DocumentStorageMetadataService._();

  static const String _table = 'document_storage_metadata';

  Future<void> recordUploadStarted({required String documentId, int? fileSizeBytes, int? storageSizeBytes, String? mimeTypeGroup}) async {
    await _upsert(
      documentId: documentId,
      uploadStatus: 'started',
      fileSizeBytes: fileSizeBytes,
      storageSizeBytes: storageSizeBytes,
      mimeTypeGroup: mimeTypeGroup,
    );
  }

  Future<void> recordUploadCompleted({required String documentId, int? fileSizeBytes, int? storageSizeBytes, String? mimeTypeGroup}) async {
    await _upsert(
      documentId: documentId,
      uploadStatus: 'uploaded',
      fileSizeBytes: fileSizeBytes,
      storageSizeBytes: storageSizeBytes,
      mimeTypeGroup: mimeTypeGroup,
    );
  }

  Future<void> recordUploadFailed({required String documentId, String? errorCode, int? fileSizeBytes, int? storageSizeBytes, String? mimeTypeGroup}) async {
    // Store a coarse failure code only in usage_events (properties). We do NOT
    // store free-form errors here.
    await _upsert(
      documentId: documentId,
      uploadStatus: 'failed',
      fileSizeBytes: fileSizeBytes,
      storageSizeBytes: storageSizeBytes,
      mimeTypeGroup: mimeTypeGroup,
    );
  }

  Future<void> recordDeleted({required String documentId}) async {
    await _upsert(documentId: documentId, uploadStatus: 'deleted', deletedAt: DateTime.now().toUtc());
  }

  Future<void> _upsert({
    required String documentId,
    required String uploadStatus,
    int? fileSizeBytes,
    int? storageSizeBytes,
    String? mimeTypeGroup,
    DateTime? deletedAt,
  }) async {
    unawaited(_upsertImpl(
      documentId: documentId,
      uploadStatus: uploadStatus,
      fileSizeBytes: fileSizeBytes,
      storageSizeBytes: storageSizeBytes,
      mimeTypeGroup: mimeTypeGroup,
      deletedAt: deletedAt,
    ));
  }

  Future<void> _upsertImpl({
    required String documentId,
    required String uploadStatus,
    int? fileSizeBytes,
    int? storageSizeBytes,
    String? mimeTypeGroup,
    DateTime? deletedAt,
  }) async {
    try {
      if (!SupabaseConfig.isInitialized) return;
      final client = SupabaseConfig.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return;

      final safeMime = _sanitizeMimeGroup(mimeTypeGroup);
      final payload = <String, Object?>{
        'document_id': documentId,
        'owner_user_id': userId,
        if (fileSizeBytes != null && fileSizeBytes >= 0) 'file_size_bytes': fileSizeBytes,
        if (storageSizeBytes != null && storageSizeBytes >= 0) 'storage_size_bytes': storageSizeBytes,
        if (safeMime != null) 'mime_type_group': safeMime,
        'upload_status': uploadStatus,
        if (deletedAt != null) 'deleted_at': deletedAt.toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Upsert by primary key (document_id).
      await client.from(_table).upsert(payload, onConflict: 'document_id');
    } catch (e) {
      if (kDebugMode) debugPrint('[document_storage_metadata] upsert failed: $e');
    }
  }

  static String? _sanitizeMimeGroup(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == 'pdf' || v == 'image' || v == 'other') return v;
    return 'other';
  }
}
