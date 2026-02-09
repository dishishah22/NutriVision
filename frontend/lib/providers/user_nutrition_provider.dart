import 'package:flutter/material.dart';
import 'package:spectrum_flutter/models/nutrition_models.dart';
import 'package:spectrum_flutter/services/nutrition_storage_service.dart';

class UserNutritionProvider with ChangeNotifier {
  final NutritionStorageService _storageService = NutritionStorageService();
  
  String? _userId; // The logged-in user's ID
  
  // Data streams/values
  Stream<List<NutritionScanModel>>? _scansStream;
  Stream<NutritionSummaryModel>? _summaryStream;

  String? get userId => _userId;
  Stream<List<NutritionScanModel>>? get scansStream => _scansStream;
  Stream<NutritionSummaryModel>? get summaryStream => _summaryStream;

  /// Call this when the user logs in
  void setUserId(String id) {
    _userId = id;
    _initStreams();
    notifyListeners();
  }

  /// Call this on logout
  void clearUser() {
    _userId = null;
    _scansStream = null;
    _summaryStream = null;
    notifyListeners();
  }

  void _initStreams() {
    if (_userId != null) {
      _scansStream = _storageService.getUserScans(_userId!);
      _summaryStream = _storageService.getUserSummary(_userId!);
    }
  }

  /// Save a new scan result
  Future<void> addScan({
    required String scanType,
    required String foodName,
    required double calories,
    required double protein,
    required double fat,
    required double carbs,
    String? imageUrl,
    required Map<String, dynamic> rawApiResponse,
  }) async {
    if (_userId == null) {
      throw Exception("User not logged in");
    }

    final newScan = NutritionScanModel(
      scanId: '', // Service will generate this
      userId: _userId!,
      scanType: scanType,
      foodName: foodName,
      calories: calories,
      protein: protein,
      fat: fat,
      carbs: carbs,
      imageUrl: imageUrl,
      rawApiResponse: rawApiResponse,
      createdAt: DateTime.now(),
    );

    await _storageService.saveScan(newScan);
  }
}
