import 'package:cloud_firestore/cloud_firestore.dart';

class NutritionScanModel {
  final String scanId;
  final String userId;
  final String scanType; // 'meal_scan' or 'barcode_scan'
  final String foodName;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final String? imageUrl;
  final Map<String, dynamic> rawApiResponse;
  final DateTime createdAt;

  NutritionScanModel({
    required this.scanId,
    required this.userId,
    required this.scanType,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.imageUrl,
    required this.rawApiResponse,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'scanId': scanId,
      'userId': userId,
      'scanType': scanType,
      'foodName': foodName,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
      'imageUrl': imageUrl,
      'rawApiResponse': rawApiResponse,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory NutritionScanModel.fromMap(Map<String, dynamic> map) {
    return NutritionScanModel(
      scanId: map['scanId'] ?? '',
      userId: map['userId'] ?? '',
      scanType: map['scanType'] ?? 'unknown',
      foodName: map['foodName'] ?? 'Unknown Food',
      calories: (map['calories'] ?? 0).toDouble(),
      protein: (map['protein'] ?? 0).toDouble(),
      fat: (map['fat'] ?? 0).toDouble(),
      carbs: (map['carbs'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'],
      rawApiResponse: Map<String, dynamic>.from(map['rawApiResponse'] ?? {}),
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}

class NutritionSummaryModel {
  final double totalCalories;
  final double totalProtein;
  final double totalFat;
  final double totalCarbs;
  final DateTime lastUpdated;

  NutritionSummaryModel({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbs,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalFat': totalFat,
      'totalCarbs': totalCarbs,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory NutritionSummaryModel.fromMap(Map<String, dynamic> map) {
    return NutritionSummaryModel(
      totalCalories: (map['totalCalories'] ?? 0).toDouble(),
      totalProtein: (map['totalProtein'] ?? 0).toDouble(),
      totalFat: (map['totalFat'] ?? 0).toDouble(),
      totalCarbs: (map['totalCarbs'] ?? 0).toDouble(),
      lastUpdated: map['lastUpdated'] is Timestamp 
          ? (map['lastUpdated'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  factory NutritionSummaryModel.empty() {
    return NutritionSummaryModel(
      totalCalories: 0,
      totalProtein: 0,
      totalFat: 0,
      totalCarbs: 0,
      lastUpdated: DateTime.now(),
    );
  }
}
