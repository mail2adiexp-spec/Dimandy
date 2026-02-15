import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that displays error text with clickable URLs.
/// Useful for Firestore index creation links in error messages.
class ClickableErrorText extends StatelessWidget {
  final String errorText;
  final TextStyle? style;
  final TextAlign? textAlign;

  const ClickableErrorText({
    super.key,
    required this.errorText,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final urlPattern = RegExp(r'https?://[^\s\]]+');
    final matches = urlPattern.allMatches(errorText).toList();

    if (matches.isEmpty) {
      return SelectableText(
        errorText,
        style: style ?? const TextStyle(color: Colors.red),
        textAlign: textAlign,
      );
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add text before URL
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: errorText.substring(lastEnd, match.start),
          style: style ?? const TextStyle(color: Colors.red),
        ));
      }

      // Add clickable URL
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
          decorationColor: Colors.blue,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ));

      lastEnd = match.end;
    }

    // Add remaining text after last URL
    if (lastEnd < errorText.length) {
      spans.add(TextSpan(
        text: errorText.substring(lastEnd),
        style: style ?? const TextStyle(color: Colors.red),
      ));
    }

    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(children: spans),
    );
  }
}

/// A centered error widget with clickable URLs and a copy button.
class ClickableErrorWidget extends StatelessWidget {
  final String errorText;
  final String prefix;

  const ClickableErrorWidget({
    super.key,
    required this.errorText,
    this.prefix = 'Error: ',
  });

  @override
  Widget build(BuildContext context) {
    final fullText = '$prefix$errorText';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            ClickableErrorText(
              errorText: fullText,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (fullText.contains('https://'))
              ElevatedButton.icon(
                onPressed: () async {
                  // Extract the URL and open it
                  final urlMatch = RegExp(r'https?://[^\s\]]+').firstMatch(fullText);
                  if (urlMatch != null) {
                    final uri = Uri.parse(urlMatch.group(0)!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Create Index'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
