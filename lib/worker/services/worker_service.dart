// lib/worker/services/worker_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class WorkerService {
  static const String baseUrl = "http://10.0.2.2:8000";
  
  // Get jobs for a worker (using a default worker ID for demo)
  Future<List<Map<String, dynamic>>> getAvailableJobs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/worker/worker_001/jobs?status=pending'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Convert list of dynamic to list of Map<String, dynamic>
          final List<dynamic> jobs = data['jobs'] ?? [];
          return jobs.map((job) => Map<String, dynamic>.from(job)).toList();
        }
      }
      return [];
    } catch (e) {
      print("Error fetching jobs: $e");
      return [];
    }
  }
  
  // Accept a job
  Future<bool> acceptJob(String jobId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/worker/worker_001/job-action'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'job_id': jobId,
          'action': 'accept',
          'reason': '',
        }),
      );
      
      final data = json.decode(response.body);
      return data['success'] == true;
    } catch (e) {
      print("Error accepting job: $e");
      return false;
    }
  }
  
  // Reject a job
  Future<bool> rejectJob(String jobId, String reason) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/worker/worker_001/job-action'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'job_id': jobId,
          'action': 'reject',
          'reason': reason,
        }),
      );
      
      final data = json.decode(response.body);
      return data['success'] == true;
    } catch (e) {
      print("Error rejecting job: $e");
      return false;
    }
  }
  
  // Get worker stats (demo data)
  Future<Map<String, dynamic>> getWorkerStats() async {
    // For demo, return mock data
    await Future.delayed(const Duration(seconds: 1));
    
    return {
      'total_jobs': 42,
      'completed_jobs': 35,
      'pending_jobs': 2,
      'rating': 4.5,
      'total_earnings': 3150.00,
      'active_jobs': 2,
    };
  }
}