import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spectrum_flutter/models/nutrition_models.dart';

class NutritionSummaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch the real-time stream of user's nutrition summary
  Stream<NutritionSummaryModel> getSummaryStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return NutritionSummaryModel.empty();
      }
      final data = snapshot.data()!;
      if (data.containsKey('nutrition_summary')) {
        return NutritionSummaryModel.fromMap(data['nutrition_summary']);
      }
      return NutritionSummaryModel.empty();
    });
  }

  /// Reset summary (if needed)
  Future<void> resetSummary(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'nutrition_summary': {
        'totalCalories': 0,
        'totalProtein': 0,
        'totalFat': 0,
        'totalCarbs': 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      }
    });
  }
}
