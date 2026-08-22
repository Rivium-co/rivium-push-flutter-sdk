import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../inapp_message.dart';
import '../rivium_push.dart';

/// Optional hook fired after the overlay records the button-click impression.
/// Use this for deep-link routing that needs BuildContext.
typedef RiviumPushInAppButtonTap = void Function(
  BuildContext context,
  InAppMessage message,
  InAppButton button,
);

/// Callback wired into every button/dismiss action passed to a custom builder.
class RiviumPushInAppActions {
  RiviumPushInAppActions({
    required this.onButtonTap,
    required this.onDismiss,
  });

  /// Records the button-click impression, fires [RiviumPushInAppOverlay.onButtonTap],
  /// then removes the overlay. Call this from custom buttons in [RiviumPushInAppBuilders].
  final void Function(InAppButton button) onButtonTap;

  /// Records the dismiss impression and removes the overlay.
  /// Call from custom close buttons or backdrop taps.
  final VoidCallback onDismiss;
}

/// Signature for a custom renderer. Return any widget — the overlay takes care
/// of insertion, animation, and impression bookkeeping via [actions].
typedef RiviumPushInAppRendererBuilder = Widget Function(
  BuildContext context,
  InAppMessage message,
  InAppMessageContent content,
  RiviumPushInAppActions actions,
);

/// Per-type overrides. Any null builder falls back to the default renderer.
class RiviumPushInAppBuilders {
  const RiviumPushInAppBuilders({
    this.modal,
    this.banner,
    this.fullscreen,
    this.card,
  });

  final RiviumPushInAppRendererBuilder? modal;
  final RiviumPushInAppRendererBuilder? banner;
  final RiviumPushInAppRendererBuilder? fullscreen;
  final RiviumPushInAppRendererBuilder? card;

  RiviumPushInAppRendererBuilder? forType(InAppMessageType type) {
    switch (type) {
      case InAppMessageType.modal:
        return modal;
      case InAppMessageType.banner:
        return banner;
      case InAppMessageType.fullscreen:
        return fullscreen;
      case InAppMessageType.card:
        return card;
    }
  }
}

/// Styling knobs for the built-in renderers. Anything null uses the default.
/// For deeper changes, pass [RiviumPushInAppBuilders] instead.
class RiviumPushInAppTheme {
  const RiviumPushInAppTheme({
    this.backdropColor,
    this.modalBackgroundColor,
    this.modalTextColor,
    this.modalBorderRadius,
    this.modalElevation,
    this.modalMaxWidth,
    this.bannerBackgroundColor,
    this.bannerTextColor,
    this.bannerBorderRadius,
    this.bannerElevation,
    this.fullscreenBackgroundColor,
    this.fullscreenTextColor,
    this.cardBackgroundColor,
    this.cardTextColor,
    this.cardBorderRadius,
    this.cardElevation,
    this.cardMaxWidth,
    this.animationDuration,
  });

  final Color? backdropColor;

  final Color? modalBackgroundColor;
  final Color? modalTextColor;
  final double? modalBorderRadius;
  final double? modalElevation;
  final double? modalMaxWidth;

  final Color? bannerBackgroundColor;
  final Color? bannerTextColor;
  final double? bannerBorderRadius;
  final double? bannerElevation;

  final Color? fullscreenBackgroundColor;
  final Color? fullscreenTextColor;

  final Color? cardBackgroundColor;
  final Color? cardTextColor;
  final double? cardBorderRadius;
  final double? cardElevation;
  final double? cardMaxWidth;

  final Duration? animationDuration;

  static const RiviumPushInAppTheme defaults = RiviumPushInAppTheme();
}

/// Wrap your app with this widget to render Rivium Push in-app messages.
///
/// The native SDKs skip their own UI once a callback is set, and the Flutter
/// plugin always sets that callback. Without this overlay, messages fetch,
/// match, and get silently dropped. Drop this widget above your MaterialApp
/// and messages render for free.
///
/// ```dart
/// RiviumPushInAppOverlay(
///   onButtonTap: (context, message, button) {
///     if (button.action == InAppButtonAction.deepLink && button.value != null) {
///       context.go(button.value!);
///     }
///   },
///   child: MaterialApp.router(...),
/// )
/// ```
class RiviumPushInAppOverlay extends StatefulWidget {
  const RiviumPushInAppOverlay({
    super.key,
    required this.child,
    this.onButtonTap,
    this.theme = RiviumPushInAppTheme.defaults,
    this.builders = const RiviumPushInAppBuilders(),
  });

  final Widget child;
  final RiviumPushInAppButtonTap? onButtonTap;

  /// Style overrides for the built-in renderers.
  final RiviumPushInAppTheme theme;

  /// Per-type builder overrides. Use to fully replace any renderer.
  final RiviumPushInAppBuilders builders;

  @override
  State<RiviumPushInAppOverlay> createState() => _RiviumPushInAppOverlayState();
}

class _RiviumPushInAppOverlayState extends State<RiviumPushInAppOverlay> {
  final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();
  OverlayEntry? _currentEntry;
  InAppMessage? _currentMessage;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    RiviumPush.onInAppMessageReady(_handleMessageReady);
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _removeCurrent();
    super.dispose();
  }

  void _handleMessageReady(InAppMessage message) {
    // Coalesce duplicates and let the newest message win.
    if (_currentMessage?.id == message.id) return;
    _delayTimer?.cancel();

    final delay = Duration(seconds: message.delaySeconds);
    if (delay > Duration.zero) {
      _delayTimer = Timer(delay, () => _present(message));
    } else {
      _present(message);
    }
  }

  void _present(InAppMessage message) {
    final overlay = _overlayKey.currentState;
    if (overlay == null) return;

    _removeCurrent();
    _currentMessage = message;

    final entry = OverlayEntry(
      builder: (context) => _RiviumInAppRoot(
        message: message,
        theme: widget.theme,
        builders: widget.builders,
        onButtonTap: (button) => _onButtonTap(context, message, button),
        onDismiss: () => _onDismiss(message),
      ),
    );
    _currentEntry = entry;
    overlay.insert(entry);
  }

  void _removeCurrent() {
    _currentEntry?.remove();
    _currentEntry = null;
    _currentMessage = null;
  }

  void _onButtonTap(BuildContext context, InAppMessage message, InAppButton button) {
    RiviumPush.recordInAppButtonClick(message.id, button.id);
    widget.onButtonTap?.call(context, message, button);
    _removeCurrent();
  }

  void _onDismiss(InAppMessage message) {
    RiviumPush.recordInAppDismissed(message.id);
    _removeCurrent();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      key: _overlayKey,
      initialEntries: [
        OverlayEntry(builder: (_) => widget.child),
      ],
    );
  }
}

class _RiviumInAppRoot extends StatelessWidget {
  const _RiviumInAppRoot({
    required this.message,
    required this.theme,
    required this.builders,
    required this.onButtonTap,
    required this.onDismiss,
  });

  final InAppMessage message;
  final RiviumPushInAppTheme theme;
  final RiviumPushInAppBuilders builders;
  final ValueChanged<InAppButton> onButtonTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final locale = _resolveLocale(context);
    final content = message.getLocalizedContent(locale);
    final direction = _resolveDirection(context, locale);

    final custom = builders.forType(message.type);
    final Widget renderer;
    if (custom != null) {
      renderer = custom(
        context,
        message,
        content,
        RiviumPushInAppActions(
          onButtonTap: onButtonTap,
          onDismiss: onDismiss,
        ),
      );
    } else {
      switch (message.type) {
        case InAppMessageType.banner:
          renderer = _BannerRenderer(
            content: content,
            theme: theme,
            onButtonTap: onButtonTap,
            onDismiss: onDismiss,
          );
          break;
        case InAppMessageType.fullscreen:
          renderer = _FullscreenRenderer(
            content: content,
            theme: theme,
            onButtonTap: onButtonTap,
            onDismiss: onDismiss,
          );
          break;
        case InAppMessageType.card:
          renderer = _CardRenderer(
            content: content,
            theme: theme,
            onButtonTap: onButtonTap,
            onDismiss: onDismiss,
          );
          break;
        case InAppMessageType.modal:
          renderer = _ModalRenderer(
            content: content,
            theme: theme,
            onButtonTap: onButtonTap,
            onDismiss: onDismiss,
          );
          break;
      }
    }

    return Directionality(
      textDirection: direction,
      child: renderer,
    );
  }

  static String _resolveLocale(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context) ??
        PlatformDispatcher.instance.locale;
    return locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}-${locale.countryCode}';
  }

  static TextDirection _resolveDirection(BuildContext context, String locale) {
    final direction = Directionality.maybeOf(context);
    if (direction != null) return direction;
    const rtl = {'fa', 'ar', 'he', 'ur', 'ps', 'sd', 'ku'};
    return rtl.contains(locale.split('-').first.toLowerCase())
        ? TextDirection.rtl
        : TextDirection.ltr;
  }
}

// ==================== Shared helpers ====================

Color? _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var normalized = hex.replaceFirst('#', '');
  if (normalized.length == 6) normalized = 'FF$normalized';
  final value = int.tryParse(normalized, radix: 16);
  return value == null ? null : Color(value);
}

Widget _buildImage(String url) {
  return Image.network(
    url,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    loadingBuilder: (_, child, progress) =>
        progress == null ? child : const SizedBox(height: 120),
  );
}

Widget _buildButton(
  BuildContext context,
  InAppButton button,
  ValueChanged<InAppButton> onTap,
  Color? textColor,
) {
  final onPressed = () => onTap(button);
  switch (button.style) {
    case InAppButtonStyle.primary:
      return FilledButton(onPressed: onPressed, child: Text(button.text));
    case InAppButtonStyle.secondary:
      return OutlinedButton(onPressed: onPressed, child: Text(button.text));
    case InAppButtonStyle.destructive:
      return FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Colors.red),
        onPressed: onPressed,
        child: Text(button.text),
      );
    case InAppButtonStyle.text:
      return TextButton(
        onPressed: onPressed,
        style: textColor == null
            ? null
            : TextButton.styleFrom(foregroundColor: textColor),
        child: Text(button.text),
      );
  }
}

// ==================== Renderers ====================

class _ModalRenderer extends StatelessWidget {
  const _ModalRenderer({
    required this.content,
    required this.theme,
    required this.onButtonTap,
    required this.onDismiss,
  });

  final InAppMessageContent content;
  final RiviumPushInAppTheme theme;
  final ValueChanged<InAppButton> onButtonTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bg = _parseColor(content.backgroundColor) ??
        theme.modalBackgroundColor ??
        Theme.of(context).dialogTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface;
    final fg = _parseColor(content.textColor) ??
        theme.modalTextColor ??
        Theme.of(context).colorScheme.onSurface;
    final radius = theme.modalBorderRadius ?? 16;
    final elevation = theme.modalElevation ?? 8;
    final maxWidth = theme.modalMaxWidth ?? 400;
    final backdrop = theme.backdropColor ?? Colors.black.withValues(alpha: 0.5);

    return _FadeIn(
      duration: theme.animationDuration,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              child: Container(color: backdrop),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Material(
                color: bg,
                borderRadius: BorderRadius.circular(radius),
                clipBehavior: Clip.antiAlias,
                elevation: elevation,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (content.imageUrl != null)
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: _buildImage(content.imageUrl!),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              content.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: fg),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              content.body,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: fg),
                            ),
                            if (content.buttons.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 8,
                                children: content.buttons
                                    .map((b) => _buildButton(
                                        context, b, onButtonTap, fg))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerRenderer extends StatelessWidget {
  const _BannerRenderer({
    required this.content,
    required this.theme,
    required this.onButtonTap,
    required this.onDismiss,
  });

  final InAppMessageContent content;
  final RiviumPushInAppTheme theme;
  final ValueChanged<InAppButton> onButtonTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bg = _parseColor(content.backgroundColor) ??
        theme.bannerBackgroundColor ??
        Theme.of(context).colorScheme.surface;
    final fg = _parseColor(content.textColor) ??
        theme.bannerTextColor ??
        Theme.of(context).colorScheme.onSurface;
    final radius = theme.bannerBorderRadius ?? 12;
    final elevation = theme.bannerElevation ?? 4;
    final safe = MediaQuery.of(context).padding;

    return Align(
      alignment: Alignment.topCenter,
      child: _SlideDownFade(
        duration: theme.animationDuration,
        child: SafeArea(
          minimum: EdgeInsets.only(top: safe.top),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Material(
              color: bg,
              elevation: elevation,
              borderRadius: BorderRadius.circular(radius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: content.buttons.isEmpty ? onDismiss : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (content.imageUrl != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: _buildImage(content.imageUrl!),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              content.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: fg),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              content.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: fg),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: fg),
                        onPressed: onDismiss,
                        tooltip: 'Dismiss',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenRenderer extends StatelessWidget {
  const _FullscreenRenderer({
    required this.content,
    required this.theme,
    required this.onButtonTap,
    required this.onDismiss,
  });

  final InAppMessageContent content;
  final RiviumPushInAppTheme theme;
  final ValueChanged<InAppButton> onButtonTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bg = _parseColor(content.backgroundColor) ??
        theme.fullscreenBackgroundColor ??
        Theme.of(context).colorScheme.surface;
    final fg = _parseColor(content.textColor) ??
        theme.fullscreenTextColor ??
        Theme.of(context).colorScheme.onSurface;

    return _FadeIn(
      duration: theme.animationDuration,
      child: Material(
        color: bg,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: IconButton(
                  icon: Icon(Icons.close, color: fg),
                  onPressed: onDismiss,
                  tooltip: 'Dismiss',
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (content.imageUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _buildImage(content.imageUrl!),
                          ),
                        ),
                      Text(
                        content.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: fg),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        content.body,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: fg),
                      ),
                    ],
                  ),
                ),
              ),
              if (content.buttons.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: content.buttons
                        .map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildButton(context, b, onButtonTap, fg),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardRenderer extends StatelessWidget {
  const _CardRenderer({
    required this.content,
    required this.theme,
    required this.onButtonTap,
    required this.onDismiss,
  });

  final InAppMessageContent content;
  final RiviumPushInAppTheme theme;
  final ValueChanged<InAppButton> onButtonTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bg = _parseColor(content.backgroundColor) ??
        theme.cardBackgroundColor ??
        Theme.of(context).colorScheme.surface;
    final fg = _parseColor(content.textColor) ??
        theme.cardTextColor ??
        Theme.of(context).colorScheme.onSurface;
    final radius = theme.cardBorderRadius ?? 16;
    final elevation = theme.cardElevation ?? 6;
    final maxWidth = theme.cardMaxWidth ?? 480;

    return Align(
      alignment: Alignment.bottomCenter,
      child: _SlideUpFade(
        duration: theme.animationDuration,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Material(
              color: bg,
              elevation: elevation,
              borderRadius: BorderRadius.circular(radius),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (content.imageUrl != null)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _buildImage(content.imageUrl!),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  content.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: fg),
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(Icons.close, size: 20, color: fg),
                                onPressed: onDismiss,
                                tooltip: 'Dismiss',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            content.body,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: fg),
                          ),
                          if (content.buttons.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: content.buttons
                                  .map((b) => _buildButton(
                                      context, b, onButtonTap, fg))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== Animations ====================

class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child, this.duration});
  final Widget child;
  final Duration? duration;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration ?? const Duration(milliseconds: 180),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return FadeTransition(opacity: _c, child: widget.child);
  }
}

class _SlideDownFade extends StatefulWidget {
  const _SlideDownFade({required this.child, this.duration});
  final Widget child;
  final Duration? duration;

  @override
  State<_SlideDownFade> createState() => _SlideDownFadeState();
}

class _SlideDownFadeState extends State<_SlideDownFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration ?? const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
      child: FadeTransition(opacity: _c, child: widget.child),
    );
  }
}

class _SlideUpFade extends StatefulWidget {
  const _SlideUpFade({required this.child, this.duration});
  final Widget child;
  final Duration? duration;

  @override
  State<_SlideUpFade> createState() => _SlideUpFadeState();
}

class _SlideUpFadeState extends State<_SlideUpFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration ?? const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
      child: FadeTransition(opacity: _c, child: widget.child),
    );
  }
}
