import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/verification_request.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'verification_detail_screen.dart';

class VerificationListScreen extends StatefulWidget {
  final String? initialStatus;
  
  const VerificationListScreen({
    super.key,
    this.initialStatus,
  });

  @override
  State<VerificationListScreen> createState() => _VerificationListScreenState();
}

class _VerificationListScreenState extends State<VerificationListScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<VerificationRequest> _requests = [];
  String? _errorMessage;
  String? _selectedStatus;
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMorePages = true;
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
    _scrollController.addListener(_scrollListener);
    _loadVerificationRequests();
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (_hasMorePages && !_isLoadingMore) {
        _loadMoreVerificationRequests();
      }
    }
  }
  
  Future<void> _loadVerificationRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 0;
      _hasMorePages = true;
    });
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final requests = await apiService.getVerificationRequests(
        status: _selectedStatus,
        page: _currentPage + 1, // API uses 1-based indexing
        limit: _pageSize,
      );
      
      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
          _hasMorePages = requests.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load verification requests: $e';
          _isLoading = false;
        });
        
        // Log the error for debugging
        debugPrint('Error loading verification requests: $e');
      }
    }
  }
  
  Future<void> _loadMoreVerificationRequests() async {
    if (!_hasMorePages || _isLoadingMore) {
      return;
    }
    
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final requests = await apiService.getVerificationRequests(
        status: _selectedStatus,
        page: _currentPage + 1, // API uses 1-based indexing
        limit: _pageSize,
      );
      
      if (mounted) {
        setState(() {
          _requests.addAll(requests);
          _isLoadingMore = false;
          _hasMorePages = requests.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentPage--; // Revert page increment on error
          _isLoadingMore = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load more requests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _onStatusFilterChanged(String? status) {
    if (status == _selectedStatus) {
      return;
    }
    
    setState(() {
      _selectedStatus = status;
    });
    
    _loadVerificationRequests();
  }
  
  void _viewVerificationDetails(String requestId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationDetailScreen(requestId: requestId),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVerificationRequests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadVerificationRequests,
        child: _buildBody(),
      ),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_errorMessage != null && _requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadVerificationRequests,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_selectedStatus?.toLowerCase() ?? ''} verification requests found',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadVerificationRequests,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      itemCount: _requests.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _requests.length) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        
        return _buildRequestCard(_requests[index]);
      },
    );
  }
  
  Widget _buildRequestCard(VerificationRequest request) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    
    // Status color and icon
    Color statusColor;
    IconData statusIcon;
    
    switch (request.status) {
      case KYCStatus.PENDING:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case KYCStatus.VERIFIED:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case KYCStatus.REJECTED:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case KYCStatus.EXPIRED:
        statusColor = Colors.grey;
        statusIcon = Icons.timer_off;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _viewVerificationDetails(request.id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${request.firstName} ${request.lastName}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          color: statusColor,
                          size: 16,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          request.status.toString().split('.').last,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ID: ${request.id}',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Email: ${request.email}',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Submitted: ${dateFormat.format(request.createdAt)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Time: ${timeFormat.format(request.createdAt)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter by Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterOption(null, 'All'),
              _buildFilterOption('PENDING', 'Pending'),
              _buildFilterOption('VERIFIED', 'Verified'),
              _buildFilterOption('REJECTED', 'Rejected'),
              _buildFilterOption('EXPIRED', 'Expired'),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildFilterOption(String? value, String label) {
    return ListTile(
      title: Text(label),
      leading: Radio<String?>(
        value: value,
        groupValue: _selectedStatus,
        onChanged: (value) {
          Navigator.pop(context);
          _onStatusFilterChanged(value);
        },
      ),
    );
  }
}
