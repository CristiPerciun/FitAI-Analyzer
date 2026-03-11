import 'package:fitai_analyzer/services/ai_service.dart';
import 'package:fitai_analyzer/services/auth_service.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:fitai_analyzer/services/mfp_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service providers - dependency injection via Riverpod
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final garminServiceProvider = Provider<GarminService>((ref) => GarminService());
final mfpServiceProvider = Provider<MfpService>((ref) => MfpService());
final aiServiceProvider = Provider<AiService>((ref) => AiService());
