// lib/screens/db_diagnostics_screen.dart
import 'package:flutter/material.dart';
import '../utils/db_diagnostics.dart';

class DbDiagnosticsScreen extends StatefulWidget {
  const DbDiagnosticsScreen({Key? key}) : super(key: key);

  @override
  _DbDiagnosticsScreenState createState() => _DbDiagnosticsScreenState();
}

class _DbDiagnosticsScreenState extends State<DbDiagnosticsScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _diagnosticResults;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await DbDiagnostics.runDiagnostics();

      // Print the results to console for debugging
      DbDiagnostics.printDiagnostics(results);

      setState(() {
        _diagnosticResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDiagnostics,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _runDiagnostics,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              )
              : _buildDiagnosticsView(),
    );
  }

  Widget _buildDiagnosticsView() {
    if (_diagnosticResults == null) {
      return const Center(child: Text('No diagnostic data available'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          'Platform Information',
          _buildPlatformInfo(_diagnosticResults!['platform']),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          'Environment Variables',
          _buildEnvVarsInfo(_diagnosticResults!['env_variables']),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          'Network Connectivity',
          _buildNetworkInfo(_diagnosticResults!['network']),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          'Database Connection',
          _buildDatabaseInfo(_diagnosticResults!['database']),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _runDiagnostics,
          child: const Text('Run Diagnostics Again'),
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, Widget content) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformInfo(Map<String, dynamic> platformInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Platform', platformInfo['platform'].toString()),
        _buildInfoRow('Version', platformInfo['version'].toString()),
        _buildInfoRow('Is Web', platformInfo['is_web'].toString()),
      ],
    );
  }

  Widget _buildEnvVarsInfo(Map<String, dynamic> envVars) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Env File Loaded', envVars['dotenv_loaded'].toString()),
        if (envVars['dotenv_error'] != null)
          _buildInfoRow(
            'Env Load Error',
            envVars['dotenv_error'].toString(),
            isError: true,
          ),
        _buildInfoRow(
          'MONGO_URI Exists',
          envVars['mongo_uri_exists'].toString(),
        ),
        if (envVars['mongo_uri_exists'] == true) ...[
          _buildInfoRow(
            'MONGO_URI Format Valid',
            envVars['mongo_uri_format_valid'].toString(),
          ),
          _buildInfoRow('MONGO_URI', envVars['mongo_uri_masked'].toString()),
        ],
      ],
    );
  }

  Widget _buildNetworkInfo(Map<String, dynamic> network) {
    if (network['status'] == 'skipped_web') {
      return const Text('Network checks skipped on web platform');
    }

    if (network['status'] == 'error') {
      return Text(
        'Error: ${network['error']}',
        style: const TextStyle(color: Colors.red),
      );
    }

    final items = <Widget>[];
    network.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        if (value['success'] == true) {
          items.add(_buildInfoRow(key, 'Connected ✓', isSuccess: true));
        } else {
          items.add(_buildInfoRow(key, 'Failed ✗', isError: true));
          if (value['error'] != null) {
            items.add(
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Text(
                  value['error'].toString(),
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            );
          }
        }
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

  Widget _buildDatabaseInfo(Map<String, dynamic> db) {
    final items = <Widget>[
      _buildInfoRow('Initialized', db['is_initialized'].toString()),
      _buildInfoRow('Connected', db['is_connected'].toString()),
    ];

    if (db['connection_error'] != null) {
      items.add(
        _buildInfoRow(
          'Connection Error',
          db['connection_error'].toString(),
          isError: true,
        ),
      );
    }

    items.add(
      _buildInfoRow(
        'Ping Success',
        db['ping_success'].toString(),
        isSuccess: db['ping_success'] == true,
        isError: db['ping_success'] == false,
      ),
    );

    if (db['users_collection_exists'] != null) {
      items.add(
        _buildInfoRow(
          'Users Collection Exists',
          db['users_collection_exists'].toString(),
          isSuccess: db['users_collection_exists'] == true,
          isError: db['users_collection_exists'] == false,
        ),
      );
    }

    if (db['users_document_count'] != null) {
      items.add(
        _buildInfoRow(
          'Users Document Count',
          db['users_document_count'].toString(),
        ),
      );
    }

    if (db['collections_error'] != null) {
      items.add(
        _buildInfoRow(
          'Collections Error',
          db['collections_error'].toString(),
          isError: true,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color:
                    isError
                        ? Colors.red
                        : isSuccess
                        ? Colors.green
                        : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
