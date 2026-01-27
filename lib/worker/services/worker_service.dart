// lib/worker/services/worker_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class WorkerService {
  // Use localhost for Chrome/web, 10.0.2.2 for Android emulator
  static const String baseUrl = "http://localhost:8000";

  // Current worker ID - in production, this would come from authentication
  String? _currentWorkerId;

  void setWorkerId(String workerId) {
    _currentWorkerId = workerId;
  }

  String get currentWorkerId => _currentWorkerId ?? 'demo_worker';

  // Get worker profile and stats from Firestore via backend
  Future<Map<String, dynamic>> getWorkerProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/worker/$currentWorkerId/profile'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'worker': data['worker'] ?? {},
            'stats': data['stats'] ?? {},
          };
        }
      }
      // Return default/demo data if API fails
      return _getDemoProfile();
    } catch (e) {
      print("Error fetching worker profile: $e");
      return _getDemoProfile();
    }
  }

  // Get worker stats (wraps getWorkerProfile for backwards compatibility)
  Future<Map<String, dynamic>> getWorkerStats() async {
    final profile = await getWorkerProfile();
    return profile['stats'] ?? _getDemoStats();
  }

  // Get jobs for a worker, optionally filtered by status
  Future<List<Map<String, dynamic>>> getWorkerJobs({String? status}) async {
    try {
      String url = '$baseUrl/worker/$currentWorkerId/jobs';
      if (status != null && status.isNotEmpty) {
        url += '?status=$status';
      }

      print('DEBUG: Fetching jobs for workerId: $currentWorkerId');
      print('DEBUG: Request URL: $url');

      final response = await http.get(Uri.parse(url));

      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> jobs = data['jobs'] ?? [];
          return jobs.map((job) => Map<String, dynamic>.from(job)).toList();
        }
      }
      return [];
    } catch (e) {
      print("Error fetching worker jobs: $e");
      return [];
    }
  }

  // Get available/pending jobs for the worker
  Future<List<Map<String, dynamic>>> getAvailableJobs() async {
    return getWorkerJobs(status: 'pending');
  }

  // Get accepted jobs (in progress)
  Future<List<Map<String, dynamic>>> getAcceptedJobs() async {
    return getWorkerJobs(status: 'accepted');
  }

  // Get completed jobs
  Future<List<Map<String, dynamic>>> getCompletedJobs() async {
    return getWorkerJobs(status: 'completed');
  }

  // Accept a job
  Future<bool> acceptJob(String jobId) async {
    return _performJobAction(jobId, 'accept');
  }

  // Reject a job
  Future<bool> rejectJob(String jobId, String reason) async {
    return _performJobAction(jobId, 'reject', reason: reason);
  }

  // Start a job (mark as in progress)
  Future<bool> startJob(String jobId) async {
    return _performJobAction(jobId, 'start');
  }

  // Complete a job
  Future<bool> completeJob(String jobId) async {
    return _performJobAction(jobId, 'complete');
  }

  // Internal method to perform job actions
  Future<bool> _performJobAction(String jobId, String action, {String reason = ''}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/worker/$currentWorkerId/job-action'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'job_id': jobId,
          'action': action,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print("Error performing job action ($action): $e");
      return false;
    }
  }

  // Demo data for when API is unavailable
  Map<String, dynamic> _getDemoProfile() {
    return {
      'worker': {
        'id': 'demo_worker',
        'name': 'Demo Worker',
        'category': 'plumber',
        'location': 'Mumbai',
        'rating': 4.5,
        'hourly_rate': 45,
        'experience': '5 years exp.',
        'verified': true,
      },
      'stats': _getDemoStats(),
    };
  }

  Map<String, dynamic> _getDemoStats() {
    return {
      'total_jobs': 42,
      'completed_jobs': 35,
      'pending_jobs': 2,
      'active_jobs': 5,
      'rating': 4.5,
      'total_earnings': 3150.00,
    };
  }
}
