/// Mirrors backend's StorageController.UploadResponse
/// (backend/storage/.../StorageController.java).
class UploadedFile {
  final String key;
  final String url;

  const UploadedFile({required this.key, required this.url});

  factory UploadedFile.fromJson(Map<String, dynamic> json) {
    return UploadedFile(key: json['key'] as String, url: json['url'] as String);
  }
}
