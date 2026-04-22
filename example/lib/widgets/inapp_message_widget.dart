import 'package:flutter/material.dart';
import 'package:rivium_push/rivium_push.dart';

/// A widget that displays an in-app message based on its type.
/// This demonstrates how to render different message types (modal, banner, fullscreen, card).
class InAppMessageWidget extends StatelessWidget {
  final InAppMessage message;
  final Function(InAppButton) onButtonClick;
  final VoidCallback onDismiss;

  const InAppMessageWidget({
    super.key,
    required this.message,
    required this.onButtonClick,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case InAppMessageType.modal:
        return _buildModal(context);
      case InAppMessageType.banner:
        return _buildBanner(context);
      case InAppMessageType.fullscreen:
        return _buildFullscreen(context);
      case InAppMessageType.card:
        return _buildCard(context);
    }
  }

  Widget _buildModal(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: _parseColor(message.content.backgroundColor) ?? Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  color: _parseColor(message.content.textColor) ?? Colors.black54,
                ),
                onPressed: onDismiss,
              ),
            ),
            // Image
            if (message.content.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  message.content.imageUrl!,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 180,
                    color: _parseColor(message.content.backgroundColor) ?? Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.image, size: 48, color: Colors.white54)),
                  ),
                ),
              ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    message.content.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _parseColor(message.content.textColor),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message.content.body,
                    style: TextStyle(
                      fontSize: 14,
                      color: _parseColor(message.content.textColor) ?? Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Buttons
                  _buildButtons(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: _parseColor(message.content.backgroundColor) ?? Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Content row
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Image thumbnail
                        if (message.content.imageUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                message.content.imageUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        // Text content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.content.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _parseColor(message.content.textColor),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message.content.body,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _parseColor(message.content.textColor) ?? Colors.grey.shade600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Close button
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: onDismiss,
                        ),
                      ],
                    ),
                  ),
                  // Action buttons
                  if (message.content.buttons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: message.content.buttons.map((button) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _buildButton(context, button, compact: true),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreen(BuildContext context) {
    return Material(
      color: _parseColor(message.content.backgroundColor) ?? Colors.white,
      child: SafeArea(
        child: Stack(
          children: [
            // Background image
            if (message.content.imageUrl != null)
              Positioned.fill(
                child: Image.network(
                  message.content.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                  ),
                ),
              ),
            // Gradient overlay
            if (message.content.imageUrl != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
            // Content
            Positioned(
              left: 24,
              right: 24,
              bottom: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    message.content.title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _parseColor(message.content.textColor) ??
                          (message.content.imageUrl != null ? Colors.white : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message.content.body,
                    style: TextStyle(
                      fontSize: 16,
                      color: _parseColor(message.content.textColor) ??
                          (message.content.imageUrl != null ? Colors.white70 : Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildButtons(context, fullWidth: true),
                ],
              ),
            ),
            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  color: message.content.imageUrl != null ? Colors.white : Colors.black,
                ),
                onPressed: onDismiss,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 350),
            decoration: BoxDecoration(
              color: _parseColor(message.content.backgroundColor) ?? Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image
                if (message.content.imageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(
                      message.content.imageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
                      ),
                    ),
                  ),
                // Close button overlay
                Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            message.content.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _parseColor(message.content.textColor),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message.content.body,
                            style: TextStyle(
                              fontSize: 14,
                              color: _parseColor(message.content.textColor) ?? Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          _buildButtons(context, fullWidth: true),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: onDismiss,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context, {bool fullWidth = false}) {
    if (message.content.buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    final buttons = message.content.buttons.map((button) {
      return _buildButton(context, button);
    }).toList();

    if (fullWidth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buttons.map((button) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: button,
          );
        }).toList(),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: buttons,
    );
  }

  Widget _buildButton(BuildContext context, InAppButton button, {bool compact = false}) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 12);

    switch (button.style) {
      case InAppButtonStyle.primary:
        return ElevatedButton(
          onPressed: () => onButtonClick(button),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: padding,
          ),
          child: Text(button.text),
        );

      case InAppButtonStyle.secondary:
        return OutlinedButton(
          onPressed: () => onButtonClick(button),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).primaryColor,
            side: BorderSide(color: Theme.of(context).primaryColor),
            padding: padding,
          ),
          child: Text(button.text),
        );

      case InAppButtonStyle.text:
        return TextButton(
          onPressed: () => onButtonClick(button),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).primaryColor,
            padding: padding,
          ),
          child: Text(button.text),
        );

      case InAppButtonStyle.destructive:
        return ElevatedButton(
          onPressed: () => onButtonClick(button),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: padding,
          ),
          child: Text(button.text),
        );
    }
  }

  Color? _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return null;
    try {
      final hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return null;
  }
}
