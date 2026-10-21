import 'package:flutter/material.dart';

/// Colours with a meaning that the Material colour scheme doesn't cover.
/// Each has a light and a dark version so dark mode stays readable.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Workshop / event sessions.
  final Color session;

  /// Something partly wrong (e.g. some variants sold out).
  final Color warning;

  /// Something done (e.g. sale recorded).
  final Color success;

  const AppColors({required this.session, required this.warning, required this.success});

  static const light = AppColors(
    session: Color(0xFF6A3FB5),
    warning: Color(0xFFB45309),
    success: Color(0xFF2E7D32),
  );

  static const dark = AppColors(
    session: Color(0xFFC7A6FF),
    warning: Color(0xFFFBBF77),
    success: Color(0xFF81C784),
  );

  @override
  AppColors copyWith({Color? session, Color? warning, Color? success}) => AppColors(
        session: session ?? this.session,
        warning: warning ?? this.warning,
        success: success ?? this.success,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      session: Color.lerp(session, other.session, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
