import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report.dart';

class ReportService {
  final CollectionReference _reports =
      FirebaseFirestore.instance.collection('reports');

  Future<void> submitReport(Report report) async {
    try {
      await _reports.doc(report.id).set(report.toMap());
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  Stream<List<Report>> getReports() {
    return _reports
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Report.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }
}
