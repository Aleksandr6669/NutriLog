import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AiReportEntry {
  final String period;
  final DateTime generatedAt;
  final String overview;
  final List<Map<String, String>> recommendations;
  final String sourceSignature;

  const AiReportEntry({
    required this.period,
    required this.generatedAt,
    required this.overview,
    required this.recommendations,
    this.sourceSignature = '',
  });

  Map<String, dynamic> toJson() => {
        'period': period,
        'generatedAt': generatedAt.toIso8601String(),
        'overview': overview,
        'recommendations': recommendations,
        'sourceSignature': sourceSignature,
      };

  factory AiReportEntry.fromJson(Map<String, dynamic> json) => AiReportEntry(
        period: json['period'] as String? ?? '',
        generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
            DateTime.now(),
        overview: json['overview'] as String? ?? '',
        recommendations: (json['recommendations'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, String>.from(
                e.map((k, v) => MapEntry(k.toString(), v.toString()))))
            .toList(growable: false),
        sourceSignature: json['sourceSignature'] as String? ?? '',
      );
}

class AiReportHistoryService {
  static const String _storageKey = 'ai_report_history';
  static const int _maxEntries = 30;

  Future<List<AiReportEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(AiReportEntry.fromJson)
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveReport(AiReportEntry entry) async {
    final history = await loadHistory();
    final updated = [entry, ...history].take(_maxEntries).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey, json.encode(updated.map((e) => e.toJson()).toList()));
  }
}
