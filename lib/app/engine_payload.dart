import 'package:flutter/material.dart';
import 'package:nested/nested.dart';

/// The core abstraction defining a standard application connecting to the Developer Sandbox/Engine.
/// Any domain-specific logic, routing, and providers must be securely bundled into a payload
/// implementing this exact signature to prevent bleeding into the core platform architecture.
abstract class EnginePayload {
  /// The absolute registered name of the target application payload (e.g., "Music App")
  String get name;

  /// The root route the Sandbox or Engine should resolve natively when this payload gracefully mounts
  String get initialRoute;

  /// Overarching custom Light Theme configuration specific to this app payload.
  /// If null, the platform will impose a core fallback constraint.
  ThemeData? get theme;

  /// Overarching custom Dark Theme configuration specific to this app payload.
  ThemeData? get darkTheme;

  /// Core structural routing layer managing page interception natively within the sandbox wrapper
  RouteFactory get onGenerateRoute;

  /// Scoped state controllers, UI repositories, and offline DAOs natively bound to this payload logic.
  /// These providers will be securely injected exclusively into the sandbox container tree.
  List<SingleChildWidget> buildProviders(BuildContext context);
}
