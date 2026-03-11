class FatsecretFood {
  final String foodId;
  final String foodName;
  final String? foodType;
  final String? foodUrl;
  final String? foodDescription;
  final List<FatsecretFoodServing>? servings;

  FatsecretFood({
    required this.foodId,
    required this.foodName,
    this.foodType,
    this.foodUrl,
    this.foodDescription,
    this.servings,
  });

  factory FatsecretFood.fromJson(Map<String, dynamic> json) {
    var servingsList = <FatsecretFoodServing>[];
    if (json['servings'] != null && json['servings']['serving'] != null) {
      if (json['servings']['serving'] is List) {
        servingsList = (json['servings']['serving'] as List)
            .map((s) => FatsecretFoodServing.fromJson(s))
            .toList();
      } else {
        servingsList = [FatsecretFoodServing.fromJson(json['servings']['serving'])];
      }
    }

    return FatsecretFood(
      foodId: json['food_id'],
      foodName: json['food_name'],
      foodType: json['food_type'],
      foodUrl: json['food_url'],
      foodDescription: json['food_description'],
      servings: servingsList,
    );
  }
}

class FatsecretFoodServing {
  final String servingId;
  final String servingDescription;
  final String? servingUrl;
  final String? metricServingAmount;
  final String? metricServingUnit;
  final String? numberOfUnits;
  final String? measurementDescription;
  final double? calories;
  final double? carbohydrate;
  final double? protein;
  final double? fat;

  FatsecretFoodServing({
    required this.servingId,
    required this.servingDescription,
    this.servingUrl,
    this.metricServingAmount,
    this.metricServingUnit,
    this.numberOfUnits,
    this.measurementDescription,
    this.calories,
    this.carbohydrate,
    this.protein,
    this.fat,
  });

  factory FatsecretFoodServing.fromJson(Map<String, dynamic> json) {
    return FatsecretFoodServing(
      servingId: json['serving_id'],
      servingDescription: json['serving_description'],
      servingUrl: json['serving_url'],
      metricServingAmount: json['metric_serving_amount'],
      metricServingUnit: json['metric_serving_unit'],
      numberOfUnits: json['number_of_units'],
      measurementDescription: json['measurement_description'],
      calories: double.tryParse(json['calories'] ?? ''),
      carbohydrate: double.tryParse(json['carbohydrate'] ?? ''),
      protein: double.tryParse(json['protein'] ?? ''),
      fat: double.tryParse(json['fat'] ?? ''),
    );
  }
}
