import 'dart:collection';

class AiDiagnosticEntry {
  final DateTime timestamp;
  final String feature;
  final String message;
  final String? details;
  final int? statusCode;
  final bool isError;

  AiDiagnosticEntry({
    required this.timestamp,
    required this.feature,
    required this.message,
    this.details,
    this.statusCode,
    this.isError = false,
  });
}

class AiErrorLogService {
  static final AiErrorLogService instance = AiErrorLogService._();
  AiErrorLogService._();

  final List<AiDiagnosticEntry> _logs = [];
  static const int _maxLogs = 100;

  List<AiDiagnosticEntry> get logs => UnmodifiableListView(_logs);

  void _addLog(AiDiagnosticEntry entry) {
    _logs.insert(0, entry);
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }
  }

  void logRequest({required String feature, String? details}) {
    _addLog(AiDiagnosticEntry(
      timestamp: DateTime.now(),
      feature: feature,
      message: 'Request Started',
      details: details,
    ));
  }

  void logSuccess({required String feature, String? details}) {
    _addLog(AiDiagnosticEntry(
      timestamp: DateTime.now(),
      feature: feature,
      message: 'Request Success',
      details: details,
    ));
  }

  void logError({
    required String feature,
    required String message,
    String? details,
    int? statusCode,
  }) {
    _addLog(AiDiagnosticEntry(
      timestamp: DateTime.now(),
      feature: feature,
      message: message,
      details: details,
      statusCode: statusCode,
      isError: true,
    ));
  }

  void clearLogs() {
    _logs.clear();
  }
}
