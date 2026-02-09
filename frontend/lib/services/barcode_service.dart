import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  /// Change ONLY this when backend IP changes
  static String get baseUrl {
    if (Platform.isAndroid) {
      return "http://10.110.80.87:8500"; // Assuming same host/port or separate? 
    } else {
      return "http://10.110.80.87:8500";
    }
  }

  static Future<Map<String, dynamic>> fetchProductByBarcode(
      String barcode, String userId) async {
    try {
      final url = Uri.parse("$baseUrl/scan/$barcode?login_id=$userId");
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception("Server error ${response.statusCode}");
      }

      final data = jsonDecode(response.body);
      return {
        "success": data["status"] == "success",
        "data": data,
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }
}
