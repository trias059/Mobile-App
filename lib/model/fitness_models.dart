import 'package:hive/hive.dart';

part 'fitness_models.g.dart';

// ============= WORKOUT MODELS =============

@HiveType(typeId: 7)
class WorkoutPlan extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // "Bulking Program", "Football Training", etc

  @HiveField(2)
  String category; // "gym", "football", "cardio", "flexibility"

  @HiveField(3)
  List<String> targetMuscles; // ["chest", "triceps", "shoulders"]

  @HiveField(4)
  int durationWeeks;

  @HiveField(5)
  String difficulty; // "beginner", "intermediate", "advanced"

  @HiveField(6)
  List<WorkoutDay> workoutDays;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  bool isActive;

  @HiveField(9)
  String? notes;

  WorkoutPlan({
    required this.id,
    required this.name,
    required this.category,
    required this.targetMuscles,
    required this.durationWeeks,
    required this.difficulty,
    required this.workoutDays,
    required this.createdAt,
    this.isActive = false,
    this.notes,
  });

  // Get difficulty label in Indonesian
  String get difficultyLabel {
    switch (difficulty) {
      case 'beginner':
        return 'Pemula';
      case 'intermediate':
        return 'Menengah';
      case 'advanced':
        return 'Lanjutan';
      default:
        return difficulty;
    }
  }

  // Get category label in Indonesian
  String get categoryLabel {
    switch (category) {
      case 'gym':
        return 'Gym';
      case 'football':
        return 'Sepak Bola';
      case 'cardio':
        return 'Kardio';
      case 'flexibility':
        return 'Fleksibilitas';
      default:
        return category;
    }
  }

  // Get total exercises count
  int get totalExercises {
    return workoutDays.fold(0, (sum, day) => sum + day.exercises.length);
  }

  @override
  String toString() {
    return 'WorkoutPlan(name: $name, category: $category, difficulty: $difficulty, active: $isActive)';
  }
}

@HiveType(typeId: 8)
class WorkoutDay extends HiveObject {
  @HiveField(0)
  String dayName; // "Monday", "Tuesday", etc

  @HiveField(1)
  List<Exercise> exercises;

  @HiveField(2)
  String? focus; // "Upper Body", "Legs", "Full Body"

  @HiveField(3)
  int restMinutes; // Rest between exercises

  WorkoutDay({
    required this.dayName,
    required this.exercises,
    this.focus,
    this.restMinutes = 60,
  });
}

@HiveType(typeId: 9)
class Exercise extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // "Bench Press", "Squats", etc

  @HiveField(2)
  String category; // "strength", "cardio", "flexibility", "football_drill"

  @HiveField(3)
  String muscleGroup; // "chest", "legs", "back", etc

  @HiveField(4)
  int sets;

  @HiveField(5)
  int reps; // For strength exercises

  @HiveField(6)
  int? duration; // For cardio/drills (in seconds)

  @HiveField(7)
  double? weight; // In kg

  @HiveField(8)
  String? notes; // "Focus on form", "Explosive movement"

  @HiveField(9)
  String? videoUrl; // Tutorial video link

  @HiveField(10)
  List<String> equipment; // ["barbell", "dumbbell", "none"]

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
    this.duration,
    this.weight,
    this.notes,
    this.videoUrl,
    this.equipment = const [],
  });
}

@HiveType(typeId: 26)
class WorkoutSession extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String workoutPlanId;

  @HiveField(3)
  List<ExerciseLog> exercises;

  @HiveField(4)
  int durationMinutes;

  @HiveField(5)
  int caloriesBurned;

  @HiveField(6)
  String? notes;

  @HiveField(7)
  double? bodyWeight; // Track weight per session

  @HiveField(8)
  int feelingScore; // 1-5 how you felt

  WorkoutSession({
    required this.id,
    required this.date,
    required this.workoutPlanId,
    required this.exercises,
    required this.durationMinutes,
    required this.caloriesBurned,
    this.notes,
    this.bodyWeight,
    this.feelingScore = 3,
  });
}

@HiveType(typeId: 11)
class ExerciseLog extends HiveObject {
  @HiveField(0)
  String exerciseId;

  @HiveField(1)
  String exerciseName;

  @HiveField(2)
  List<SetLog> sets;

  @HiveField(3)
  bool isCompleted;

  @HiveField(4)
  String? notes;

  ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    this.isCompleted = false,
    this.notes,
  });
}

@HiveType(typeId: 12)
class SetLog extends HiveObject {
  @HiveField(0)
  int reps;

  @HiveField(1)
  double weight;

  @HiveField(2)
  bool isCompleted;

  @HiveField(3)
  int? duration; // For timed exercises

  SetLog({
    required this.reps,
    required this.weight,
    this.isCompleted = false,
    this.duration,
  });
}

// ============= NUTRITION MODELS =============

@HiveType(typeId: 13)
class NutritionPlan extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // "Bulking Diet", "Cutting Diet"

  @HiveField(2)
  String goal; // "muscle_gain", "fat_loss", "maintain"

  @HiveField(3)
  int targetCalories;

  @HiveField(4)
  MacroTargets macros;

  @HiveField(5)
  List<MealPlan> mealPlans;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  bool isActive;

  NutritionPlan({
    required this.id,
    required this.name,
    required this.goal,
    required this.targetCalories,
    required this.macros,
    required this.mealPlans,
    required this.createdAt,
    this.isActive = false,
  });
}

@HiveType(typeId: 14)
class MacroTargets extends HiveObject {
  @HiveField(0)
  int protein; // grams

  @HiveField(1)
  int carbs; // grams

  @HiveField(2)
  int fat; // grams

  @HiveField(3)
  int fiber; // grams

  MacroTargets({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
  });
}

@HiveType(typeId: 15)
class MealPlan extends HiveObject {
  @HiveField(0)
  String mealType; // "breakfast", "lunch", "dinner", "snack"

  @HiveField(1)
  List<Food> foods;

  @HiveField(2)
  String time; // "07:00", "12:00", etc

  @HiveField(3)
  int targetCalories;

  MealPlan({
    required this.mealType,
    required this.foods,
    required this.time,
    required this.targetCalories,
  });
}

@HiveType(typeId: 16)
class Food extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String category; // "protein", "carbs", "vegetables", etc

  @HiveField(3)
  double quantity;

  @HiveField(4)
  String unit; // "gram", "cup", "piece"

  @HiveField(5)
  int calories;

  @HiveField(6)
  Macros macros;

  @HiveField(7)
  List<String> vitamins;

  @HiveField(8)
  String? barcode; // For scanning

  Food({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.macros,
    this.vitamins = const [],
    this.barcode,
  });
}

@HiveType(typeId: 17)
class Macros extends HiveObject {
  @HiveField(0)
  double protein;

  @HiveField(1)
  double carbs;

  @HiveField(2)
  double fat;

  @HiveField(3)
  double fiber;

  @HiveField(4)
  double sugar;

  Macros({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
  });
}

@HiveType(typeId: 18)
class FoodLog extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  List<FoodEntry> entries;

  @HiveField(3)
  int totalCalories;

  @HiveField(4)
  Macros totalMacros;

  @HiveField(5)
  double waterIntake; // in liters

  FoodLog({
    required this.id,
    required this.date,
    required this.entries,
    required this.totalCalories,
    required this.totalMacros,
    this.waterIntake = 0.0,
  });
}

@HiveType(typeId: 19)
class FoodEntry extends HiveObject {
  @HiveField(0)
  String foodId;

  @HiveField(1)
  String foodName;

  @HiveField(2)
  String mealType;

  @HiveField(3)
  double quantity;

  @HiveField(4)
  String unit;

  @HiveField(5)
  int calories;

  @HiveField(6)
  Macros macros;

  @HiveField(7)
  DateTime time;

  FoodEntry({
    required this.foodId,
    required this.foodName,
    required this.mealType,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.macros,
    required this.time,
  });
}

// ============= WATER TRACKING =============

@HiveType(typeId: 20)
class WaterIntakeLog extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  List<WaterEntry> entries;

  @HiveField(3)
  double totalLiters;

  @HiveField(4)
  double targetLiters;

  @HiveField(5)
  List<String> reminders; // Times for reminders

  WaterIntakeLog({
    required this.id,
    required this.date,
    required this.entries,
    required this.totalLiters,
    this.targetLiters = 3.0, // Default 3L per day
    this.reminders = const [],
  });
}

@HiveType(typeId: 21)
class WaterEntry extends HiveObject {
  @HiveField(0)
  DateTime time;

  @HiveField(1)
  double amount; // in ml

  @HiveField(2)
  String type; // "water", "juice", "tea", etc

  WaterEntry({
    required this.time,
    required this.amount,
    this.type = "water",
  });
}

// ============= BODY MEASUREMENTS =============

@HiveType(typeId: 22)
class BodyMeasurement extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  double weight; // kg

  @HiveField(3)
  double? height; // cm

  @HiveField(4)
  double? bodyFat; // percentage

  @HiveField(5)
  double? muscleMass; // kg

  @HiveField(6)
  Map<String, double> measurements; // {"chest": 100, "waist": 80, "arms": 35}

  @HiveField(7)
  List<String> photos; // Progress photos paths

  @HiveField(8)
  String? notes;

  BodyMeasurement({
    required this.id,
    required this.date,
    required this.weight,
    this.height,
    this.bodyFat,
    this.muscleMass,
    this.measurements = const {},
    this.photos = const [],
    this.notes,
  });

  // Calculate BMI
  double? get bmi {
    if (height != null && height! > 0) {
      return weight / ((height! / 100) * (height! / 100));
    }
    return null;
  }

  // Get BMI category
  String get bmiCategory {
    final bmiValue = bmi;
    if (bmiValue == null) return 'Unknown';

    if (bmiValue < 18.5) return 'Kurus';
    if (bmiValue < 25.0) return 'Normal';
    if (bmiValue < 30.0) return 'Kegemukan';
    return 'Obesitas';
  }

  // Calculate lean body mass
  double? get leanBodyMass {
    if (bodyFat != null) {
      return weight * (1 - bodyFat! / 100);
    }
    return muscleMass;
  }

  // Format date
  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  String toString() {
    return 'BodyMeasurement(date: $formattedDate, weight: ${weight}kg, BMI: ${bmi?.toStringAsFixed(1) ?? "N/A"})';
  }
}

// ============= FOOTBALL TRAINING =============

@HiveType(typeId: 23)
class FootballTraining extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // "Speed Training", "Ball Control", etc

  @HiveField(2)
  String category; // "technical", "physical", "tactical"

  @HiveField(3)
  List<FootballDrill> drills;

  @HiveField(4)
  int durationMinutes;

  @HiveField(5)
  String difficulty;

  @HiveField(6)
  List<String> equipment; // ["ball", "cones", "ladder"]

  FootballTraining({
    required this.id,
    required this.name,
    required this.category,
    required this.drills,
    required this.durationMinutes,
    required this.difficulty,
    this.equipment = const [],
  });
}

@HiveType(typeId: 24)
class FootballDrill extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String description;

  @HiveField(2)
  int duration; // seconds

  @HiveField(3)
  int sets;

  @HiveField(4)
  int restSeconds;

  @HiveField(5)
  String focus; // "speed", "agility", "shooting", etc

  @HiveField(6)
  String? videoUrl;

  FootballDrill({
    required this.name,
    required this.description,
    required this.duration,
    required this.sets,
    required this.restSeconds,
    required this.focus,
    this.videoUrl,
  });
}

// ============= HEALTH TRACKING =============

@HiveType(typeId: 25)
class HealthMetrics extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  int? heartRate; // BPM

  @HiveField(3)
  String? bloodPressure; // "120/80"

  @HiveField(4)
  int? sleepHours;

  @HiveField(5)
  int sleepQuality; // 1-5

  @HiveField(6)
  int stressLevel; // 1-5

  @HiveField(7)
  int energyLevel; // 1-5

  @HiveField(8)
  List<String> symptoms; // ["headache", "fatigue", etc]

  @HiveField(9)
  String? notes;

  HealthMetrics({
    required this.id,
    required this.date,
    this.heartRate,
    this.bloodPressure,
    this.sleepHours,
    this.sleepQuality = 3,
    this.stressLevel = 3,
    this.energyLevel = 3,
    this.symptoms = const [],
    this.notes,
  });
}