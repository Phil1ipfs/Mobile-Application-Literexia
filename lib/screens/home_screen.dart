import 'package:flutter/material.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/ui/pre_assessment_question_screen.dart';
import 'package:literexia/features/lessons/logic/aralin/aralin_provider.dart';
import 'package:literexia/screens/profile_screen.dart';
import 'package:literexia/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../config/router.dart';
import '../features/auth/logic/auth_provider.dart';
import '../screens/settings_screen.dart';
import 'package:mongo_dart/mongo_dart.dart' show Db, DbCollection, where;
import '../features/settings/provider/theme_provider.dart';

// ... existing code ... 