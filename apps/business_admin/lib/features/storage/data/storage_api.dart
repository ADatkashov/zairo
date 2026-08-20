import 'dart:typed_data';

import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'uploaded_file.dart';

/// Wraps backend's generic storage module (backend/storage), which proxies
/// uploads to MinIO server-side — the app never talks to MinIO directly
/// (see StorageController's doc comment for why).
class StorageApi {
  final DioClient _dioClient;

  StorageApi(this._dioClient);

  Future<UploadedFile> uploadBytes(Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dioClient.post('/uploads', data: formData);
    return UploadedFile.fromJson(response.data as Map<String, dynamic>);
  }
}
