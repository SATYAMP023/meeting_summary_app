import 'package:dio/dio.dart';

class ApiService {
  static final Dio dio = Dio(BaseOptions(baseUrl: "http://192.168.137.1:3000"));

  static Future<Map<String, dynamic>> uploadAudio(String path) async {
    try {
      print("🚀 [UPLOAD START]");
      print("📁 File path: $path");

      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          path,
          filename: path.split("/").last, // ✅ dynamic filename
        ),
      });

      print("📦 FormData created");
      print("🌐 Sending request to: /api/upload");

      final response = await dio.post("/api/upload", data: formData);

      print("✅ [RESPONSE RECEIVED]");
      print("📡 Status Code: ${response.statusCode}");
      print("📄 Response Data: ${response.data}");

      return response.data;
    } catch (e) {
      print("❌ [UPLOAD ERROR]");
      print("Error: $e");
      rethrow;
    }
  }
}
