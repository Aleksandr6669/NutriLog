import 'dart:convert';
import 'package:http/http.dart' as http;

class BarcodeService {
  static const String _offApiUrl = 'https://world.openfoodfacts.org/api/v0/product/';

  Future<Map<String, dynamic>?> fetchProductByBarcode(String barcode) async {
    try {
      final response = await http.get(Uri.parse('$_offApiUrl$barcode.json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          return data['product'] as Map<String, dynamic>;
        }
      }
    } catch (_) {
      // Handle error or return null
    }
    return null;
  }
}
