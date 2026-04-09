import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light => FlexThemeData.light(
        scheme: FlexScheme.money,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 10,
          blendOnColors: false,
          useM2StyleDividerInM3: true,
          inputDecoratorBorderType: FlexInputBorderType.outline,
          inputDecoratorRadius: 8.0,
          cardRadius: 12.0,
          elevatedButtonRadius: 8.0,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      );

  static ThemeData get dark => FlexThemeData.dark(
        scheme: FlexScheme.money,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 13,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 20,
          useM2StyleDividerInM3: true,
          inputDecoratorBorderType: FlexInputBorderType.outline,
          inputDecoratorRadius: 8.0,
          cardRadius: 12.0,
          elevatedButtonRadius: 8.0,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      );
}
