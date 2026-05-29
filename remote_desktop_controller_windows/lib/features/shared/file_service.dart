import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class FileItem {
  final String id;
  final String fileName;
  final String filePath;
  final String uploadedBy;
  final DateTime createdAt;

  FileItem({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      id: json['_id'] as String? ?? json['fileId'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      uploadedBy: json['uploadedBy'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class FileService {
  static const _base = 'https://remotexserver-production.up.railway.app/files';

  static String? _token() => Supabase.instance.client.auth.currentSession?.accessToken;

  static Map<String, String> _authHeaders() {
    final token = _token();
    return {'Authorization': 'Bearer ${token ?? ''}'};
  }

  static Future<List<FileItem>> getFiles() async {
    final uri = Uri.parse('$_base');
    final res = await http.get(uri, headers: _authHeaders());
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body) as List<dynamic>;
      return data.map((e) => FileItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    _handleHttpError(res.statusCode);
    return [];
  }

  static Future<FileItem> uploadFile(File file) async {
    final uri = Uri.parse('$_base/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authHeaders());
    final multipartFile = await http.MultipartFile.fromPath('file', file.path);
    request.files.add(multipartFile);

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200 || res.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(res.body) as Map<String, dynamic>;
      return FileItem.fromJson(data);
    }
    _handleHttpError(res.statusCode);
    throw Exception('Upload failed');
  }

  static Future<String> getDownloadUrl(String fileId) async {
    final uri = Uri.parse('$_base/$fileId');
    final res = await http.get(uri, headers: _authHeaders());
    if (res.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(res.body) as Map<String, dynamic>;
      return data['signedUrl'] as String? ?? '';
    }
    _handleHttpError(res.statusCode);
    return '';
  }

  static Future<void> deleteFile(String fileId) async {
    final uri = Uri.parse('$_base/$fileId');
    final res = await http.delete(uri, headers: _authHeaders());
    if (res.statusCode == 200 || res.statusCode == 204) return;
    _handleHttpError(res.statusCode);
  }

  static void _handleHttpError(int statusCode) {
    switch (statusCode) {
      case 401:
        throw HttpException('Unauthorized', uri: Uri.parse(_base));
      case 403:
        throw HttpException('Forbidden', uri: Uri.parse(_base));
      case 404:
        throw HttpException('Not Found', uri: Uri.parse(_base));
      default:
        throw HttpException('Server error: $statusCode', uri: Uri.parse(_base));
    }
  }
}
