// lib/worker/screens/worker_jobs.dart
import 'package:flutter/material.dart';
import '../services/worker_service.dart';
import '../widgets/job_card.dart';

class WorkerJobsScreen extends StatefulWidget {
  const WorkerJobsScreen({Key? key}) : super(key: key);

  @override
  _WorkerJobsScreenState createState() => _WorkerJobsScreenState();
}

class _WorkerJobsScreenState extends State<WorkerJobsScreen> {
  final WorkerService _workerService = WorkerService();
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  String _selectedFilter = 'Available';

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    final jobs = await _workerService.getAvailableJobs();
    setState(() {
      _jobs = jobs;
      _isLoading = false;
    });
  }

  Future<void> _acceptJob(String jobId) async {
    final success = await _workerService.acceptJob(jobId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job accepted successfully!')),
      );
      _loadJobs(); // Refresh list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to accept job')),
      );
    }
  }

  Future<void> _rejectJob(String jobId) async {
    final reason = await _showRejectDialog();
    if (reason != null && reason.isNotEmpty) {
      final success = await _workerService.rejectJob(jobId, reason);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job rejected')),
        );
        _loadJobs();
      }
    }
  }

  Future<String?> _showRejectDialog() async {
    String? reason;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Job'),
        content: TextField(
          onChanged: (value) => reason = value,
          decoration: const InputDecoration(
            hintText: 'Reason for rejection (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reason),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    return reason;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Jobs'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Available', 'Accepted', 'Completed', 'All']
                    .map((filter) {
                  final isSelected = filter == _selectedFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFF2196F3),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Jobs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _jobs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.work_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No jobs available',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadJobs,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _jobs.length,
                          itemBuilder: (context, index) {
                            final job = _jobs[index];
                            return JobCard(
                              job: job,
                              onAccept: () => _acceptJob(job['id']),
                              onReject: () => _rejectJob(job['id']),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}