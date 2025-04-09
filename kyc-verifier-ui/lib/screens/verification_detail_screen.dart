import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/verification_request.dart';
import '../models/document.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class VerificationDetailScreen extends StatefulWidget {
  final String requestId;
  
  const VerificationDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  State<VerificationDetailScreen> createState() => _VerificationDetailScreenState();
}

class _VerificationDetailScreenState extends State<VerificationDetailScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  VerificationRequest? _request;
  List<Document> _documents = [];
  String? _errorMessage;
  final TextEditingController _rejectionReasonController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadVerificationRequest();
  }
  
  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }
  
  Future<void> _loadVerificationRequest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final request = await apiService.getVerificationRequest(widget.requestId);
      final documents = await apiService.getDocumentsForVerificationRequest(widget.requestId);
      
      if (mounted) {
        setState(() {
          _request = request;
          _documents = documents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load verification request: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _updateStatus(KYCStatus status) async {
    // Don't allow updating if already in the same status
    if (_request?.status == status) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      String? rejectionReason;
      if (status == KYCStatus.REJECTED) {
        // Show dialog to get rejection reason
        rejectionReason = await _showRejectionReasonDialog();
        if (rejectionReason == null) {
          setState(() {
            _isProcessing = false;
          });
          return; // User cancelled
        }
      }
      
      await apiService.updateVerificationRequestStatus(
        widget.requestId,
        status,
        rejectionReason: rejectionReason,
      );
      
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        // Reload the request to get updated status
        _loadVerificationRequest();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification status updated to ${status.toString().split('.').last}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<String?> _showRejectionReasonDialog() async {
    _rejectionReasonController.clear();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rejection Reason'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejecting this verification request:'),
              const SizedBox(height: 16),
              TextField(
                controller: _rejectionReasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = _rejectionReasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a rejection reason'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, reason);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _viewDocument(Document document) async {
    try {
      setState(() {
        _isProcessing = true;
      });
      
      final apiService = Provider.of<ApiService>(context, listen: false);
      final downloadUrl = await apiService.getDocumentDownloadUrl(document.id);
      
      setState(() {
        _isProcessing = false;
      });
      
      final Uri url = Uri.parse(downloadUrl);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVerificationRequest,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? Center(
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
                        onPressed: _loadVerificationRequest,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _request == null
                  ? const Center(
                      child: Text('Verification request not found'),
                    )
                  : Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: _loadVerificationRequest,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatusCard(),
                                const SizedBox(height: 16),
                                _buildUserInfoCard(),
                                const SizedBox(height: 16),
                                _buildDocumentsCard(),
                                const SizedBox(height: 16),
                                _buildVerificationActions(),
                                const SizedBox(height: 80), // Space for bottom buttons
                              ],
                            ),
                          ),
                        ),
                        if (_isProcessing)
                          Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
    );
  }
  
  Widget _buildStatusCard() {
    final statusColor = _getStatusColor(_request!.status);
    final statusIcon = _getStatusIcon(_request!.status);
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Status:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    _request!.status.toString().split('.').last,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: statusColor,
                  avatar: Icon(
                    statusIcon,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            _buildInfoRow('Request ID:', _request!.id),
            _buildInfoRow('Submitted:', dateFormat.format(_request!.createdAt)),
            if (_request!.updatedAt != null)
              _buildInfoRow('Last Updated:', dateFormat.format(_request!.updatedAt!)),
            if (_request!.verifiedAt != null)
              _buildInfoRow('Verified:', dateFormat.format(_request!.verifiedAt!)),
            if (_request!.rejectionReason != null && _request!.rejectionReason!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Divider(),
                  const Text(
                    'Rejection Reason:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _request!.rejectionReason!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUserInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('User ID:', _request!.userId),
            _buildInfoRow('Full Name:', '${_request!.firstName} ${_request!.lastName}'),
            _buildInfoRow('Email:', _request!.email),
            if (_request!.phone != null && _request!.phone!.isNotEmpty)
              _buildInfoRow('Phone:', _request!.phone!),
            _buildInfoRow('Date of Birth:', DateFormat('MMM d, yyyy').format(_request!.dateOfBirth)),
            _buildInfoRow('Address:', _formatAddress()),
            if (_request!.additionalInfo != null && _request!.additionalInfo!.isNotEmpty)
              _buildInfoRow('Additional Info:', _request!.additionalInfo!),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDocumentsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Documents',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _documents.isEmpty
                ? const Center(
                    child: Text(
                      'No documents found',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final document = _documents[index];
                      return _buildDocumentItem(document);
                    },
                  ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDocumentItem(Document document) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _getDocumentTypeIcon(document.type),
        title: Text(document.type.toString().split('.').last),
        subtitle: Text('Uploaded: ${dateFormat.format(document.uploadedAt)}'),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.visibility),
          label: const Text('View'),
          onPressed: () => _viewDocument(document),
        ),
      ),
    );
  }
  
  Widget _buildVerificationActions() {
    // Only show actions if the request is pending
    if (_request!.status != KYCStatus.PENDING) {
      return const SizedBox.shrink();
    }
    
    return Card(
      elevation: 2,
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verification Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isProcessing
                        ? null
                        : () => _updateStatus(KYCStatus.VERIFIED),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isProcessing
                        ? null
                        : () => _updateStatus(KYCStatus.REJECTED),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: This action cannot be undone. Please review all documents carefully before approving or rejecting.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatAddress() {
    final parts = [
      _request!.addressLine1,
      _request!.addressLine2,
      _request!.city,
      _request!.state,
      _request!.postalCode,
      _request!.country,
    ];
    
    return parts
        .where((part) => part != null && part.isNotEmpty)
        .join(', ');
  }
  
  Color _getStatusColor(KYCStatus status) {
    switch (status) {
      case KYCStatus.PENDING:
        return Colors.orange;
      case KYCStatus.VERIFIED:
        return Colors.green;
      case KYCStatus.REJECTED:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getStatusIcon(KYCStatus status) {
    switch (status) {
      case KYCStatus.PENDING:
        return Icons.hourglass_empty;
      case KYCStatus.VERIFIED:
        return Icons.check_circle;
      case KYCStatus.REJECTED:
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
  
  Widget _getDocumentTypeIcon(DocumentType type) {
    IconData iconData;
    Color color;
    
    switch (type) {
      case DocumentType.ID_CARD:
        iconData = Icons.credit_card;
        color = Colors.blue;
        break;
      case DocumentType.PASSPORT:
        iconData = Icons.book;
        color = Colors.indigo;
        break;
      case DocumentType.DRIVERS_LICENSE:
        iconData = Icons.drive_eta;
        color = Colors.green;
        break;
      case DocumentType.UTILITY_BILL:
        iconData = Icons.receipt;
        color = Colors.orange;
        break;
      case DocumentType.BANK_STATEMENT:
        iconData = Icons.account_balance;
        color = Colors.purple;
        break;
      case DocumentType.SELFIE:
        iconData = Icons.face;
        color = Colors.teal;
        break;
      default:
        iconData = Icons.description;
        color = Colors.grey;
    }
    
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.2),
      child: Icon(
        iconData,
        color: color,
      ),
    );
  }
}
