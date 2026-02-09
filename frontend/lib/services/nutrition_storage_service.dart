import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spectrum_flutter/models/nutrition_models.dart';

class NutritionStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save a new scan and update the user's aggregated totals
  Future<void> saveScan(NutritionScanModel scan) async {
    final userDocRef = _firestore.collection('users').doc(scan.userId);
    final scansCollectionRef = userDocRef.collection('scans');

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Create new scan document
        final newScanDoc = scansCollectionRef.doc(); // Auto-ID
        // We override the scanId in the model with the Firestore auto-ID for consistency if needed,
        // or usage the one passed. Ideally, we let Firestore generate ID or use the one we generated.
        // Let's assume we use the generated ID if scanId is empty, but the model requires it.
        // Better:
        final finalScanDoc = scansCollectionRef.doc();
        final scanToSave = NutritionScanModel(
          scanId: finalScanDoc.id,
          userId: scan.userId,
          scanType: scan.scanType,
          foodName: scan.foodName,
          calories: scan.calories,
          protein: scan.protein,
          fat: scan.fat,
          carbs: scan.carbs,
          imageUrl: scan.imageUrl,
          rawApiResponse: scan.rawApiResponse,
          createdAt: scan.createdAt,
        );
        
        transaction.set(finalScanDoc, scanToSave.toMap());

        // 2. Update Aggregated Summary on the User Document
        // We use SetOptions(merge: true) to ensure we don't overwrite other user profile data
        // We use FieldValue.increment for atomic updates
        transaction.set(userDocRef, {
          'nutrition_summary': {
            'totalCalories': FieldValue.increment(scan.calories),
            'totalProtein': FieldValue.increment(scan.protein),
            'totalFat': FieldValue.increment(scan.fat),
            'totalCarbs': FieldValue.increment(scan.carbs),
            'lastUpdated': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      });
    } catch (e) {
      throw Exception('Failed to save scan: $e');
    }
  }

  /// Fetch all scans for a user, ordered by date
  Stream<List<NutritionScanModel>> getUserScans(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('scans')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return NutritionScanModel.fromMap(doc.data());
      }).toList();
    });
  }

  /// Fetch the user's nutrition summary
  Stream<NutritionSummaryModel> getUserSummary(String userId) {
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
}
