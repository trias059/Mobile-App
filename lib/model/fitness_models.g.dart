// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fitness_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutPlanAdapter extends TypeAdapter<WorkoutPlan> {
  @override
  final int typeId = 7;

  @override
  WorkoutPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutPlan(
      id: fields[0] as String,
      name: fields[1] as String,
      category: fields[2] as String,
      targetMuscles: (fields[3] as List).cast<String>(),
      durationWeeks: fields[4] as int,
      difficulty: fields[5] as String,
      workoutDays: (fields[6] as List).cast<WorkoutDay>(),
      createdAt: fields[7] as DateTime,
      isActive: fields[8] as bool,
      notes: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutPlan obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.targetMuscles)
      ..writeByte(4)
      ..write(obj.durationWeeks)
      ..writeByte(5)
      ..write(obj.difficulty)
      ..writeByte(6)
      ..write(obj.workoutDays)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutDayAdapter extends TypeAdapter<WorkoutDay> {
  @override
  final int typeId = 8;

  @override
  WorkoutDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutDay(
      dayName: fields[0] as String,
      exercises: (fields[1] as List).cast<Exercise>(),
      focus: fields[2] as String?,
      restMinutes: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutDay obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.dayName)
      ..writeByte(1)
      ..write(obj.exercises)
      ..writeByte(2)
      ..write(obj.focus)
      ..writeByte(3)
      ..write(obj.restMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutDayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExerciseAdapter extends TypeAdapter<Exercise> {
  @override
  final int typeId = 9;

  @override
  Exercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Exercise(
      id: fields[0] as String,
      name: fields[1] as String,
      category: fields[2] as String,
      muscleGroup: fields[3] as String,
      sets: fields[4] as int,
      reps: fields[5] as int,
      duration: fields[6] as int?,
      weight: fields[7] as double?,
      notes: fields[8] as String?,
      videoUrl: fields[9] as String?,
      equipment: (fields[10] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Exercise obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.muscleGroup)
      ..writeByte(4)
      ..write(obj.sets)
      ..writeByte(5)
      ..write(obj.reps)
      ..writeByte(6)
      ..write(obj.duration)
      ..writeByte(7)
      ..write(obj.weight)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.videoUrl)
      ..writeByte(10)
      ..write(obj.equipment);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutSessionAdapter extends TypeAdapter<WorkoutSession> {
  @override
  final int typeId = 10;

  @override
  WorkoutSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSession(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      workoutPlanId: fields[2] as String,
      exercises: (fields[3] as List).cast<ExerciseLog>(),
      durationMinutes: fields[4] as int,
      caloriesBurned: fields[5] as int,
      notes: fields[6] as String?,
      bodyWeight: fields[7] as double?,
      feelingScore: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSession obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.workoutPlanId)
      ..writeByte(3)
      ..write(obj.exercises)
      ..writeByte(4)
      ..write(obj.durationMinutes)
      ..writeByte(5)
      ..write(obj.caloriesBurned)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.bodyWeight)
      ..writeByte(8)
      ..write(obj.feelingScore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExerciseLogAdapter extends TypeAdapter<ExerciseLog> {
  @override
  final int typeId = 11;

  @override
  ExerciseLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExerciseLog(
      exerciseId: fields[0] as String,
      exerciseName: fields[1] as String,
      sets: (fields[2] as List).cast<SetLog>(),
      isCompleted: fields[3] as bool,
      notes: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ExerciseLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.exerciseId)
      ..writeByte(1)
      ..write(obj.exerciseName)
      ..writeByte(2)
      ..write(obj.sets)
      ..writeByte(3)
      ..write(obj.isCompleted)
      ..writeByte(4)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SetLogAdapter extends TypeAdapter<SetLog> {
  @override
  final int typeId = 12;

  @override
  SetLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SetLog(
      reps: fields[0] as int,
      weight: fields[1] as double,
      isCompleted: fields[2] as bool,
      duration: fields[3] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, SetLog obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.reps)
      ..writeByte(1)
      ..write(obj.weight)
      ..writeByte(2)
      ..write(obj.isCompleted)
      ..writeByte(3)
      ..write(obj.duration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NutritionPlanAdapter extends TypeAdapter<NutritionPlan> {
  @override
  final int typeId = 13;

  @override
  NutritionPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NutritionPlan(
      id: fields[0] as String,
      name: fields[1] as String,
      goal: fields[2] as String,
      targetCalories: fields[3] as int,
      macros: fields[4] as MacroTargets,
      mealPlans: (fields[5] as List).cast<MealPlan>(),
      createdAt: fields[6] as DateTime,
      isActive: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, NutritionPlan obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.goal)
      ..writeByte(3)
      ..write(obj.targetCalories)
      ..writeByte(4)
      ..write(obj.macros)
      ..writeByte(5)
      ..write(obj.mealPlans)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MacroTargetsAdapter extends TypeAdapter<MacroTargets> {
  @override
  final int typeId = 14;

  @override
  MacroTargets read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MacroTargets(
      protein: fields[0] as int,
      carbs: fields[1] as int,
      fat: fields[2] as int,
      fiber: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, MacroTargets obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.protein)
      ..writeByte(1)
      ..write(obj.carbs)
      ..writeByte(2)
      ..write(obj.fat)
      ..writeByte(3)
      ..write(obj.fiber);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacroTargetsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MealPlanAdapter extends TypeAdapter<MealPlan> {
  @override
  final int typeId = 15;

  @override
  MealPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealPlan(
      mealType: fields[0] as String,
      foods: (fields[1] as List).cast<Food>(),
      time: fields[2] as String,
      targetCalories: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, MealPlan obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.mealType)
      ..writeByte(1)
      ..write(obj.foods)
      ..writeByte(2)
      ..write(obj.time)
      ..writeByte(3)
      ..write(obj.targetCalories);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FoodAdapter extends TypeAdapter<Food> {
  @override
  final int typeId = 16;

  @override
  Food read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Food(
      id: fields[0] as String,
      name: fields[1] as String,
      category: fields[2] as String,
      quantity: fields[3] as double,
      unit: fields[4] as String,
      calories: fields[5] as int,
      macros: fields[6] as Macros,
      vitamins: (fields[7] as List).cast<String>(),
      barcode: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Food obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.unit)
      ..writeByte(5)
      ..write(obj.calories)
      ..writeByte(6)
      ..write(obj.macros)
      ..writeByte(7)
      ..write(obj.vitamins)
      ..writeByte(8)
      ..write(obj.barcode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MacrosAdapter extends TypeAdapter<Macros> {
  @override
  final int typeId = 17;

  @override
  Macros read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Macros(
      protein: fields[0] as double,
      carbs: fields[1] as double,
      fat: fields[2] as double,
      fiber: fields[3] as double,
      sugar: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Macros obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.protein)
      ..writeByte(1)
      ..write(obj.carbs)
      ..writeByte(2)
      ..write(obj.fat)
      ..writeByte(3)
      ..write(obj.fiber)
      ..writeByte(4)
      ..write(obj.sugar);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacrosAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FoodLogAdapter extends TypeAdapter<FoodLog> {
  @override
  final int typeId = 18;

  @override
  FoodLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodLog(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      entries: (fields[2] as List).cast<FoodEntry>(),
      totalCalories: fields[3] as int,
      totalMacros: fields[4] as Macros,
      waterIntake: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, FoodLog obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.entries)
      ..writeByte(3)
      ..write(obj.totalCalories)
      ..writeByte(4)
      ..write(obj.totalMacros)
      ..writeByte(5)
      ..write(obj.waterIntake);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FoodEntryAdapter extends TypeAdapter<FoodEntry> {
  @override
  final int typeId = 19;

  @override
  FoodEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodEntry(
      foodId: fields[0] as String,
      foodName: fields[1] as String,
      mealType: fields[2] as String,
      quantity: fields[3] as double,
      unit: fields[4] as String,
      calories: fields[5] as int,
      macros: fields[6] as Macros,
      time: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FoodEntry obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.foodId)
      ..writeByte(1)
      ..write(obj.foodName)
      ..writeByte(2)
      ..write(obj.mealType)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.unit)
      ..writeByte(5)
      ..write(obj.calories)
      ..writeByte(6)
      ..write(obj.macros)
      ..writeByte(7)
      ..write(obj.time);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WaterIntakeLogAdapter extends TypeAdapter<WaterIntakeLog> {
  @override
  final int typeId = 20;

  @override
  WaterIntakeLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WaterIntakeLog(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      entries: (fields[2] as List).cast<WaterEntry>(),
      totalLiters: fields[3] as double,
      targetLiters: fields[4] as double,
      reminders: (fields[5] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, WaterIntakeLog obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.entries)
      ..writeByte(3)
      ..write(obj.totalLiters)
      ..writeByte(4)
      ..write(obj.targetLiters)
      ..writeByte(5)
      ..write(obj.reminders);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaterIntakeLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WaterEntryAdapter extends TypeAdapter<WaterEntry> {
  @override
  final int typeId = 21;

  @override
  WaterEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WaterEntry(
      time: fields[0] as DateTime,
      amount: fields[1] as double,
      type: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WaterEntry obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.time)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaterEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BodyMeasurementAdapter extends TypeAdapter<BodyMeasurement> {
  @override
  final int typeId = 22;

  @override
  BodyMeasurement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BodyMeasurement(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      weight: fields[2] as double,
      height: fields[3] as double?,
      bodyFat: fields[4] as double?,
      muscleMass: fields[5] as double?,
      measurements: (fields[6] as Map).cast<String, double>(),
      photos: (fields[7] as List).cast<String>(),
      notes: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BodyMeasurement obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.weight)
      ..writeByte(3)
      ..write(obj.height)
      ..writeByte(4)
      ..write(obj.bodyFat)
      ..writeByte(5)
      ..write(obj.muscleMass)
      ..writeByte(6)
      ..write(obj.measurements)
      ..writeByte(7)
      ..write(obj.photos)
      ..writeByte(8)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BodyMeasurementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FootballTrainingAdapter extends TypeAdapter<FootballTraining> {
  @override
  final int typeId = 23;

  @override
  FootballTraining read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FootballTraining(
      id: fields[0] as String,
      name: fields[1] as String,
      category: fields[2] as String,
      drills: (fields[3] as List).cast<FootballDrill>(),
      durationMinutes: fields[4] as int,
      difficulty: fields[5] as String,
      equipment: (fields[6] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, FootballTraining obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.drills)
      ..writeByte(4)
      ..write(obj.durationMinutes)
      ..writeByte(5)
      ..write(obj.difficulty)
      ..writeByte(6)
      ..write(obj.equipment);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FootballTrainingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FootballDrillAdapter extends TypeAdapter<FootballDrill> {
  @override
  final int typeId = 24;

  @override
  FootballDrill read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FootballDrill(
      name: fields[0] as String,
      description: fields[1] as String,
      duration: fields[2] as int,
      sets: fields[3] as int,
      restSeconds: fields[4] as int,
      focus: fields[5] as String,
      videoUrl: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FootballDrill obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.duration)
      ..writeByte(3)
      ..write(obj.sets)
      ..writeByte(4)
      ..write(obj.restSeconds)
      ..writeByte(5)
      ..write(obj.focus)
      ..writeByte(6)
      ..write(obj.videoUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FootballDrillAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HealthMetricsAdapter extends TypeAdapter<HealthMetrics> {
  @override
  final int typeId = 25;

  @override
  HealthMetrics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HealthMetrics(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      heartRate: fields[2] as int?,
      bloodPressure: fields[3] as String?,
      sleepHours: fields[4] as int?,
      sleepQuality: fields[5] as int,
      stressLevel: fields[6] as int,
      energyLevel: fields[7] as int,
      symptoms: (fields[8] as List).cast<String>(),
      notes: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HealthMetrics obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.heartRate)
      ..writeByte(3)
      ..write(obj.bloodPressure)
      ..writeByte(4)
      ..write(obj.sleepHours)
      ..writeByte(5)
      ..write(obj.sleepQuality)
      ..writeByte(6)
      ..write(obj.stressLevel)
      ..writeByte(7)
      ..write(obj.energyLevel)
      ..writeByte(8)
      ..write(obj.symptoms)
      ..writeByte(9)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthMetricsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
