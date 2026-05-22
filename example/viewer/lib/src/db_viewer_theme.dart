import 'package:flutter/material.dart';

/// Holds all visual customisation points for [DbViewerWidget].
///
/// Every field has a default that reproduces the original G-ANT DB Viewer look,
/// so callers only need to override what they care about:
///
/// ```dart
/// DbViewerWidget(
///   theme: DbViewerThemeData(
///     primaryColor: Colors.teal,
///     spatialTableIcon: Icons.terrain,
///   ),
/// )
/// ```
@immutable
class DbViewerThemeData {
  // ── Semantic colors ─────────────────────────────────────────────────────────

  /// Toolbar background, active buttons, column-header text, selected states.
  final Color primaryColor;

  /// Spatial/geometry tables, geometry columns, EPSG chips.
  final Color geometryColor;

  /// Primary-key column icons and schema folder icons.
  final Color primaryKeyColor;

  /// Destructive actions (e.g. Drop table) and error states.
  final Color errorColor;

  // ── Tree icons ──────────────────────────────────────────────────────────────

  /// Schema node when collapsed.
  final IconData schemaIcon;

  /// Schema node when expanded.
  final IconData schemaOpenIcon;

  /// Regular (non-spatial) table.
  final IconData tableIcon;

  /// Spatial / geometry table.
  final IconData spatialTableIcon;

  /// Regular column.
  final IconData columnIcon;

  /// Geometry / spatial column.
  final IconData spatialColumnIcon;

  /// Primary-key column.
  final IconData primaryKeyIcon;

  const DbViewerThemeData({
    this.primaryColor = const Color(0xFF1565C0),
    this.geometryColor = const Color(0xFF2E7D32),
    this.primaryKeyColor = const Color(0xFFF57F17),
    this.errorColor = const Color(0xFFB71C1C),
    this.schemaIcon = Icons.folder,
    this.schemaOpenIcon = Icons.folder_open,
    this.tableIcon = Icons.table_chart,
    this.spatialTableIcon = Icons.map,
    this.columnIcon = Icons.short_text,
    this.spatialColumnIcon = Icons.place,
    this.primaryKeyIcon = Icons.key,
  });

  /// Returns a copy with any provided fields replaced.
  DbViewerThemeData copyWith({
    Color? primaryColor,
    Color? geometryColor,
    Color? primaryKeyColor,
    Color? errorColor,
    IconData? schemaIcon,
    IconData? schemaOpenIcon,
    IconData? tableIcon,
    IconData? spatialTableIcon,
    IconData? columnIcon,
    IconData? spatialColumnIcon,
    IconData? primaryKeyIcon,
  }) {
    return DbViewerThemeData(
      primaryColor: primaryColor ?? this.primaryColor,
      geometryColor: geometryColor ?? this.geometryColor,
      primaryKeyColor: primaryKeyColor ?? this.primaryKeyColor,
      errorColor: errorColor ?? this.errorColor,
      schemaIcon: schemaIcon ?? this.schemaIcon,
      schemaOpenIcon: schemaOpenIcon ?? this.schemaOpenIcon,
      tableIcon: tableIcon ?? this.tableIcon,
      spatialTableIcon: spatialTableIcon ?? this.spatialTableIcon,
      columnIcon: columnIcon ?? this.columnIcon,
      spatialColumnIcon: spatialColumnIcon ?? this.spatialColumnIcon,
      primaryKeyIcon: primaryKeyIcon ?? this.primaryKeyIcon,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DbViewerThemeData &&
      primaryColor == other.primaryColor &&
      geometryColor == other.geometryColor &&
      primaryKeyColor == other.primaryKeyColor &&
      errorColor == other.errorColor &&
      schemaIcon == other.schemaIcon &&
      schemaOpenIcon == other.schemaOpenIcon &&
      tableIcon == other.tableIcon &&
      spatialTableIcon == other.spatialTableIcon &&
      columnIcon == other.columnIcon &&
      spatialColumnIcon == other.spatialColumnIcon &&
      primaryKeyIcon == other.primaryKeyIcon;

  @override
  int get hashCode => Object.hash(
        primaryColor,
        geometryColor,
        primaryKeyColor,
        errorColor,
        schemaIcon,
        schemaOpenIcon,
        tableIcon,
        spatialTableIcon,
        columnIcon,
        spatialColumnIcon,
        primaryKeyIcon,
      );
}

/// Provides a [DbViewerThemeData] to all descendant widgets.
///
/// Falls back to [DbViewerThemeData()] (i.e. all defaults) when no ancestor
/// is present, so individual panels are safe to use outside the full viewer.
class DbViewerTheme extends InheritedWidget {
  final DbViewerThemeData data;

  const DbViewerTheme({
    super.key,
    required this.data,
    required super.child,
  });

  static DbViewerThemeData of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<DbViewerTheme>()
            ?.data ??
        const DbViewerThemeData();
  }

  @override
  bool updateShouldNotify(DbViewerTheme old) => data != old.data;
}
