import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class MealScanService {
  /// Change ONLY this when backend IP changes
  static String get baseUrl {
    if (Platform.isAndroid) {
      // 🔹 FOR REAL DEVICE: Use LAN IP (e.g. 10.110.80.87)
      // 🔹 FOR EMULATOR: Use 10.0.2.2
      return "http://10.110.80.87:8500"; 
    } else {
      return "http://10.110.80.87:8500";
    }
  }

  /// Scan meal image and get nutrition analysis
  static Future<Map<String, dynamic>> scanMeal(File imageFile, String userId) async {
    try {
      final uri = Uri.parse("$baseUrl/analyze-food");

      final request = http.MultipartRequest("POST", uri);
      
      // Inject Login ID for Firebase tracking
      request.fields['login_id'] = userId;

      request.files.add(
        await http.MultipartFile.fromPath(
          "image", // MUST match FastAPI param name
          imageFile.path,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception("Server error ${response.statusCode}: ${response.body}");
      }

      final data = jsonDecode(response.body);
      
      if (data["status"] == "success" || data["status"] == "failure") {
        return {
          "success": true,
          "data": data,
        };
      } else {
        return {
          "success": false,
          "error": data["message"] ?? "Unknown error",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }
}
