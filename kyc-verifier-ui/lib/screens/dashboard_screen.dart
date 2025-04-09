import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/verification_request.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'verification_list_screen.dart';
import 'profile_screen.dart';
import 'verifier_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  Map<String, int> _stats = {};
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadStats();
  }
  
  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // Get counts for different statuses
      final pendingRequests = await apiService.getVerificationRequests(
        status: 'PENDING',
        page: 1,
        limit: 1,
      );
      
      final verifiedRequests = await apiService.getVerificationRequests(
        status: 'VERIFIED',
        page: 1,
        limit: 1,
      );
      
      final rejectedRequests = await apiService.getVerificationRequests(
        status: 'REJECTED',
        page: 1,
        limit: 1,
      );
      
      final expiredRequests = await apiService.getVerificationRequests(
        status: 'EXPIRED',
        page: 1,
        limit: 1,
      );
      
      if (mounted) {
        setState(() {
          _stats = {
            'pending': pendingRequests.length,
            'verified': verifiedRequests.length,
            'rejected': rejectedRequests.length,
            'expired': expiredRequests.length,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load statistics: $e';
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load statistics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_getScreenTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.logout(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _getScreenBody(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Requests',
          ),
          if (currentUser?.role == 'ADMIN')
            const BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Verifiers',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
  
  String _getScreenTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Verification Requests';
      case 2:
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        if (currentUser?.role == 'ADMIN') {
          return 'Manage Verifiers';
        } else {
          return 'Profile';
        }
      case 3:
        return 'Profile';
      default:
        return 'Dashboard';
    }
  }
  
  Widget _getScreenBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardScreen();
      case 1:
        return const VerificationListScreen();
      case 2:
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        if (currentUser?.role == 'ADMIN') {
          return const VerifierManagementScreen();
        } else {
          return const ProfileScreen();
        }
      case 3:
        return const ProfileScreen();
      default:
        return _buildDashboardScreen();
    }
  }
  
  Widget _buildDashboardScreen() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${Provider.of<AuthService>(context).currentUser?.firstName ?? 'User'}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Here\'s an overview of verification requests',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _buildStatCard(
                        'Pending',
                        _stats['pending'] ?? 0,
                        Icons.hourglass_empty,
                        Colors.orange,
                        () => _navigateToRequestList('PENDING'),
                      ),
                      _buildStatCard(
                        'Verified',
                        _stats['verified'] ?? 0,
                        Icons.check_circle,
                        Colors.green,
                        () => _navigateToRequestList('VERIFIED'),
                      ),
                      _buildStatCard(
                        'Rejected',
                        _stats['rejected'] ?? 0,
                        Icons.cancel,
                        Colors.red,
                        () => _navigateToRequestList('REJECTED'),
                      ),
                      _buildStatCard(
                        'Expired',
                        _stats['expired'] ?? 0,
                        Icons.timer_off,
                        Colors.grey,
                        () => _navigateToRequestList('EXPIRED'),
                      ),
                    ],
                  ),
            const SizedBox(height: 32),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _navigateToRequestList('PENDING'),
              icon: const Icon(Icons.assignment),
              label: const Text('View Pending Requests'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _navigateToRequestList(null),
              icon: const Icon(Icons.list),
              label: const Text('View All Requests'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(
    String title,
    int count,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _navigateToRequestList(String? status) {
    setState(() {
      _selectedIndex = 1;
    });
    
    // This is a bit of a hack to navigate to the VerificationListScreen with a specific status
    // In a real app, you might want to use a more sophisticated navigation approach
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
        ),
      );
    });
  }
}
