import 'package:flutter/material.dart';

List<Map<String, Object>> quizData = [];
List<dynamic> quizResult = [];
Map<String, dynamic> markingScheme = {"type": "default"};
Map<String, dynamic> attemptLimits = {"type": "none"};
int time = 10; // in seconds, 0 means unlimited
int perQuestionTime = 0; // in seconds, 0 means use global quiz timer
bool completeRandomShuffle = false;
bool isReviewMode = false;
Map<String, List<String>> correctAnswers = {};
Map<String, String> solutions = {};
String ID = "";
String currentAttemptId = "";
Map<String, dynamic>? currentUserProfile;
Map<String, dynamic>? creatorProfile;
Map<String, dynamic>? featureFlags;
bool isAdmin = false;
bool isRegisteredAdmin = false;

// Local Session Cache for Permissions & Ownership
Set<String> ownedQuizIds = {};
Map<String, Map<String, dynamic>> managedQuizzes = {}; // quizId -> permissions map

// 🎨 Theme Colors (ThinkFast Palette)
const Color bgColor = Color(0xFF0F172A); // Deep Blue/Black Background
const Color cardColor = Color(0xFF1E293B); // Slate Surface/Card Color
const Color primaryAccent = Color(0xFF3B82F6); // Bright Blue Accent
const Color btnColor = Color(0xFF2563EB); // Solid Blue for Buttons
const Color labelColor = Color(0xFF94A3B8); // Muted Gray for Labels/Hints
const Color valueColor = Color(0xFFE2E8F0); // Light Gray for Text/Values
const Color borderColor = Color(0xFF334155); // Subtle Border/Divider Color
const Color hintColor = Color(0xFF475569); // Muted Blue/Gray for hints/disabled
const Color successColor = Colors.greenAccent;
const Color errorColor = Colors.redAccent;
const Color warningColor = Colors.orangeAccent;
const Color reviewColor = Colors.purple;
const Color infoColor = Colors.blueAccent;
