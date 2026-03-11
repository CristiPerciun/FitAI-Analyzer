import 'package:fitai_analyzer/services/ai_service.dart';
import 'package:fitai_analyzer/services/auth_service.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:fitai_analyzer/services/health_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service providers - dependency injection via Riverpod
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final garminServiceProvider = Provider<GarminService>((ref) => GarminService());
final healthServiceProvider = Provider<HealthService>((ref) => HealthService());
final aiServiceProvider = Provider<AiService>((ref) => AiService());
