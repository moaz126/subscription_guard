/// Provides [SubscriptionGuardDebugOverlay], a floating debug panel for
/// testing subscription tiers during development.
///
/// This widget is intended for **development and testing only**. Ensure
/// [SubscriptionGuardDebugOverlay.enabled] is set to `false` or guarded by
/// `kDebugMode` in production builds to avoid shipping debug UI.
library;

import 'package:flutter/material.dart';

import '../models/tier.dart';
import '../providers/subscription_guard_scope.dart';

// ---------------------------------------------------------------------------
// Part A: DebugOverlayPosition
// ---------------------------------------------------------------------------

/// Initial position for the debug overlay floating action button.
///
/// Used by [SubscriptionGuardDebugOverlay.initialPosition] to place the FAB
/// at a specific corner or side of the screen on first render.
///
/// See also:
///
/// - [SubscriptionGuardDebugOverlay], the widget that uses this position.
enum DebugOverlayPosition {
  /// Top-left corner of the screen.
  topLeft,

  /// Top-right corner of the screen.
  topRight,

  /// Bottom-left corner of the screen.
  bottomLeft,

  /// Bottom-right corner of the screen.
  bottomRight,

  /// Vertically centered on the right edge.
  centerRight,

  /// Vertically centered on the left edge.
  centerLeft;

  /// Calculates the pixel [Offset] for this position given the
  /// [screenSize] and the [overlaySize] of the FAB.
  ///
  /// Applies 16 px of padding from each edge.
  Offset toOffset(Size screenSize, Size overlaySize) {
    const padding = 16.0;
    final maxX = screenSize.width - overlaySize.width - padding;
    final maxY = screenSize.height - overlaySize.height - padding;
    final centerY = (screenSize.height - overlaySize.height) / 2;

    switch (this) {
      case DebugOverlayPosition.topLeft:
        return const Offset(padding, padding + kToolbarHeight);
      case DebugOverlayPosition.topRight:
        return Offset(maxX, padding + kToolbarHeight);
      case DebugOverlayPosition.bottomLeft:
        return Offset(padding, maxY);
      case DebugOverlayPosition.bottomRight:
        return Offset(maxX, maxY);
      case DebugOverlayPosition.centerRight:
        return Offset(maxX, centerY);
      case DebugOverlayPosition.centerLeft:
        return Offset(padding, centerY);
    }
  }
}

// ---------------------------------------------------------------------------
// Part B: SubscriptionGuardDebugOverlay
// ---------------------------------------------------------------------------

/// A floating debug overlay for testing subscription tiers during
/// development.
///
/// Wraps your app (or any subtree) and overlays a draggable floating button.
/// Tapping the button reveals a panel where you can:
/// - See the current subscription tier at a glance.
/// - Switch between tiers instantly without making real purchases.
/// - Toggle trial mode on or off.
/// - See which features are accessible at the selected tier.
/// - View summary statistics about tiers and features.
///
/// **This widget is intended for development/testing only.** Ensure
/// [enabled] is set to `false` or wrapped in `kDebugMode` for production
/// builds. When [enabled] is `false`, the widget adds zero overhead and
/// returns [child] directly.
///
/// > **Important:** The debug overlay **cannot** directly update the
/// > [SubscriptionGuardProvider]. It only signals changes via the
/// > [onTierChanged] and [onTrialToggled] callbacks. You must handle those
/// > callbacks to update the provider's `currentTier` and `trialInfo`
/// > for the changes to take effect in the widget tree.
///
/// Basic usage:
/// ```dart
/// SubscriptionGuardDebugOverlay(
///   enabled: kDebugMode,
///   child: MyApp(),
/// )
/// ```
///
/// With callbacks wired up:
/// ```dart
/// SubscriptionGuardDebugOverlay(
///   enabled: kDebugMode,
///   onTierChanged: (newTierId) {
///     setState(() => _currentTier = newTierId);
///   },
///   onTrialToggled: (isTrialing) {
///     setState(() => _trialInfo = TrialInfo(isTrialing: isTrialing));
///   },
///   child: SubscriptionGuardProvider(
///     config: config,
///     currentTier: _currentTier,
///     trialInfo: _trialInfo,
///     child: MyApp(),
///   ),
/// )
/// ```
///
/// Custom position:
/// ```dart
/// SubscriptionGuardDebugOverlay(
///   enabled: kDebugMode,
///   initialPosition: DebugOverlayPosition.topLeft,
///   child: MyApp(),
/// )
/// ```
///
/// See also:
///
/// - [DebugOverlayPosition], the enum controlling initial FAB placement.
/// - [SubscriptionGuardProvider], which provides the subscription state
///   displayed in the debug panel.
/// - [SubscriptionGuardScope], which the overlay reads to display tier and
///   feature information.
class SubscriptionGuardDebugOverlay extends StatefulWidget {
  /// Creates a [SubscriptionGuardDebugOverlay].
  ///
  /// Parameters:
  /// - [enabled]: If `false`, returns [child] directly with zero overhead.
  /// - [child]: The app or subtree to overlay with the debug panel.
  /// - [initialPosition]: Where the FAB appears initially.
  ///   Defaults to [DebugOverlayPosition.bottomRight].
  /// - [onTierChanged]: Called when the user selects a different tier in
  ///   the debug panel. **You must handle this** to update the provider.
  /// - [onTrialToggled]: Called when the user toggles trial mode. **You
  ///   must handle this** to update the provider.
  /// - [fabSize]: Diameter of the floating button. Defaults to `48.0`.
  /// - [fabColor]: Color of the floating button. Defaults to
  ///   [Colors.deepPurple].
  /// - [fabIcon]: Icon displayed on the floating button. Defaults to
  ///   [Icons.bug_report].
  /// - [panelWidth]: Width of the expanded debug panel. Defaults to `280.0`.
  /// - [opacity]: Opacity of the panel background. Defaults to `0.92`.
  const SubscriptionGuardDebugOverlay({
    super.key,
    required this.enabled,
    required this.child,
    this.initialPosition = DebugOverlayPosition.bottomRight,
    this.onTierChanged,
    this.onTrialToggled,
    this.fabSize = 48.0,
    this.fabColor,
    this.fabIcon = Icons.bug_report,
    this.panelWidth = 280.0,
    this.opacity = 0.92,
  });

  /// Whether the debug overlay is enabled.
  ///
  /// When `false`, the widget returns [child] directly with zero overhead.
  /// Typically set to `kDebugMode` from `package:flutter/foundation.dart`.
  final bool enabled;

  /// The app or subtree to overlay with the debug panel.
  final Widget child;

  /// The initial screen position of the floating button.
  ///
  /// Defaults to [DebugOverlayPosition.bottomRight].
  final DebugOverlayPosition initialPosition;

  /// Called when the user selects a different tier in the debug panel.
  ///
  /// **You must handle this callback** to update the
  /// [SubscriptionGuardProvider]'s `currentTier` parameter. The debug
  /// overlay cannot update the provider directly.
  final void Function(String tierId)? onTierChanged;

  /// Called when the user toggles trial mode in the debug panel.
  ///
  /// **You must handle this callback** to update the
  /// [SubscriptionGuardProvider]'s `trialInfo` parameter. The debug overlay
  /// cannot update the provider directly.
  final void Function(bool isTrialing)? onTrialToggled;

  /// Diameter of the floating action button.
  ///
  /// Defaults to `48.0`.
  final double fabSize;

  /// Color of the floating action button.
  ///
  /// Defaults to [Colors.deepPurple].
  final Color? fabColor;

  /// Icon displayed on the floating action button.
  ///
  /// Defaults to [Icons.bug_report].
  final IconData fabIcon;

  /// Width of the expanded debug panel.
  ///
  /// Defaults to `280.0`.
  final double panelWidth;

  /// Opacity of the panel background.
  ///
  /// Defaults to `0.92`.
  final double opacity;

  @override
  State<SubscriptionGuardDebugOverlay> createState() =>
      _SubscriptionGuardDebugOverlayState();
}

class _SubscriptionGuardDebugOverlayState
    extends State<SubscriptionGuardDebugOverlay>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  Offset? _position;
  String? _selectedTierId;
  bool _trialEnabled = false;
  bool _initialized = false;

  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _opacityAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _syncFromScope(SubscriptionGuardScope scope) {
    if (!_initialized) {
      _selectedTierId = scope.currentTier.id;
      _trialEnabled = scope.trialInfo.isTrialing;
      _initialized = true;
    }
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _collapse() {
    setState(() {
      _isExpanded = false;
      _animationController.reverse();
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size screenSize) {
    setState(() {
      final newDx = (_position!.dx + details.delta.dx)
          .clamp(0.0, screenSize.width - widget.fabSize);
      final newDy = (_position!.dy + details.delta.dy)
          .clamp(0.0, screenSize.height - widget.fabSize);
      _position = Offset(newDx, newDy);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final scope = SubscriptionGuardScope.maybeOf(context);
    final screenSize = MediaQuery.of(context).size;

    // Initialize position on first build.
    _position ??= widget.initialPosition.toOffset(
      screenSize,
      Size(widget.fabSize, widget.fabSize),
    );

    if (scope != null) {
      _syncFromScope(scope);
    }

    return Stack(
      children: [
        widget.child,
        // Panel (behind FAB in tap order, but rendered if expanded).
        if (_isExpanded && scope != null)
          _buildPanel(context, scope, screenSize),
        // FAB — always visible.
        Positioned(
          left: _position!.dx,
          top: _position!.dy,
          child: _buildFab(context, scope, screenSize),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Part C: Floating Action Button
  // -----------------------------------------------------------------------

  Widget _buildFab(
    BuildContext context,
    SubscriptionGuardScope? scope,
    Size screenSize,
  ) {
    final fabColor = widget.fabColor ?? Colors.deepPurple;
    final tierLetter = scope != null
        ? scope.currentTier.label.isNotEmpty
            ? scope.currentTier.label[0].toUpperCase()
            : '?'
        : null;

    return GestureDetector(
      onTap: () {
        if (scope == null) {
          // Show a brief tooltip-like overlay when no provider found.
          final overlay = Overlay.of(context);
          final entry = OverlayEntry(
            builder: (ctx) => Positioned(
              left: _position!.dx - 120,
              top: _position!.dy - 40,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade800,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'No SubscriptionGuardProvider found',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          );
          overlay.insert(entry);
          Future.delayed(const Duration(seconds: 2), entry.remove);
          return;
        }
        _toggle();
      },
      onPanUpdate: (details) => _onPanUpdate(details, screenSize),
      child: SizedBox(
        width: widget.fabSize,
        height: widget.fabSize,
        child: Material(
          elevation: 6,
          shape: const CircleBorder(
            side: BorderSide(color: Colors.white24),
          ),
          color: fabColor,
          child: Stack(
            children: [
              Center(
                child: Icon(
                  widget.fabIcon,
                  color: Colors.white,
                  size: widget.fabSize * 0.5,
                ),
              ),
              // Badge.
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scope != null
                        ? Color.lerp(fabColor, Colors.black, 0.3)!
                        : Colors.red.shade700,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    scope != null ? (tierLetter ?? '?') : '!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Part D: Debug Panel
  // -----------------------------------------------------------------------

  Widget _buildPanel(
    BuildContext context,
    SubscriptionGuardScope scope,
    Size screenSize,
  ) {
    // Determine panel placement based on FAB position.
    final fabCenterX = _position!.dx + widget.fabSize / 2;
    final fabCenterY = _position!.dy + widget.fabSize / 2;
    final opensLeft = fabCenterX > screenSize.width / 2;
    final opensUp = fabCenterY > screenSize.height / 2;

    final panelLeft = opensLeft
        ? _position!.dx - widget.panelWidth - 8
        : _position!.dx + widget.fabSize + 8;
    final maxPanelHeight = screenSize.height * 0.7;

    // Clamp panelLeft within screen.
    final clampedLeft =
        panelLeft.clamp(4.0, screenSize.width - widget.panelWidth - 4);

    return Positioned(
      left: clampedLeft,
      top: opensUp ? null : _position!.dy,
      bottom:
          opensUp ? screenSize.height - _position!.dy - widget.fabSize : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment(
          opensLeft ? 1.0 : -1.0,
          opensUp ? 1.0 : -1.0,
        ),
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxPanelHeight),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: widget.opacity),
              child: SizedBox(
                width: widget.panelWidth,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPanelContent(context, scope),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelContent(
    BuildContext context,
    SubscriptionGuardScope scope,
  ) {
    final theme = Theme.of(context);
    final config = scope.config;
    final currentTier = scope.currentTier;
    final trialInfo = scope.trialInfo;
    final selectedId = _selectedTierId ?? currentTier.id;
    final selectedTier = config.findTierById(selectedId) ?? currentTier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header.
        _buildHeader(context, theme),
        const Divider(height: 1),

        // Current tier info.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Current: ${currentTier.label} (Level ${currentTier.level})',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Switch Tier section.
        _buildSectionHeader(theme, 'Switch Tier'),
        _buildTierRadios(context, theme, config.tiers, selectedId),
        if (widget.onTierChanged == null)
          _buildWarning(theme, '⚠ Connect onTierChanged to update provider'),

        // Trial section.
        _buildSectionHeader(theme, 'Trial'),
        _buildTrialToggle(theme),
        if (widget.onTrialToggled == null)
          _buildWarning(theme, '⚠ Connect onTrialToggled to update provider'),

        // Accessible Features section.
        _buildSectionHeader(theme, 'Accessible Features'),
        _buildFeatureList(context, theme, config, selectedTier),

        // Info section.
        _buildSectionHeader(theme, 'Info'),
        _buildInfoSection(theme, config, selectedTier, trialInfo),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 4, top: 8, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.bug_report, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Subscription Debug',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: const Icon(Icons.close),
              onPressed: _collapse,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              height: 1,
              color: theme.dividerColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierRadios(
    BuildContext context,
    ThemeData theme,
    List<Tier> tiers,
    String selectedId,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: tiers.map((tier) {
          final isSelected = tier.id == selectedId;
          return InkWell(
            onTap: () {
              setState(() => _selectedTierId = tier.id);
              widget.onTierChanged?.call(tier.id);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${tier.label} (Level ${tier.level})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrialToggle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Trial Mode',
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            height: 28,
            child: FittedBox(
              child: Switch(
                value: _trialEnabled,
                onChanged: (value) {
                  setState(() => _trialEnabled = value);
                  widget.onTrialToggled?.call(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList(
    BuildContext context,
    ThemeData theme,
    dynamic config,
    Tier selectedTier,
  ) {
    final features = config.features as Map<String, String>;
    if (features.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          'No features configured',
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: features.entries.map((entry) {
          final featureId = entry.key;
          final requiredTierId = entry.value;
          final accessible = config.canAccess(selectedTier.id, requiredTierId);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  accessible ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: accessible ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    featureId,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInfoSection(
    ThemeData theme,
    dynamic config,
    Tier selectedTier,
    dynamic trialInfo,
  ) {
    final features = config.features as Map<String, String>;
    final totalFeatures = features.length;
    var accessibleCount = 0;
    for (final requiredTierId in features.values) {
      if (config.canAccess(selectedTier.id, requiredTierId) as bool) {
        accessibleCount++;
      }
    }

    final rows = <_InfoRow>[
      _InfoRow('Total tiers', '${config.tiers.length}'),
      _InfoRow('Total features', '$totalFeatures'),
      _InfoRow('Accessible', '$accessibleCount / $totalFeatures'),
      _InfoRow('Trial active', trialInfo.isActive ? 'Yes' : 'No'),
    ];

    if (trialInfo.isActive == true && trialInfo.daysRemaining != null) {
      rows.add(_InfoRow('Trial days left', '${trialInfo.daysRemaining}'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    Text(
                      '${row.label}: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      row.value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildWarning(ThemeData theme, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.orange.shade700,
          fontSize: 10,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// Simple data holder for info rows in the debug panel.
class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}
