import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class AdminNotificationLink {
  const AdminNotificationLink({
    required this.text,
    required this.url,
  });

  final String text;
  final String url;

  String get actionButtonLabel {
    final clean = text.trim();
    final lower = url.trim().toLowerCase();

    if (lower.startsWith('challenge:')) {
      return clean.isNotEmpty && clean.toLowerCase() != 'open link'
          ? clean
          : 'Join Challenge';
    }
    if (lower == 'pricing') {
      return clean.isNotEmpty && clean.toLowerCase() != 'open link'
          ? clean
          : 'Upgrade to Premium';
    }
    if (lower.contains('t.me/matricetbot') || lower.contains('matricetbot')) {
      return clean.isNotEmpty && clean.toLowerCase() != 'open link'
          ? clean
          : 'Contact Support';
    }
    if (lower.contains('t.me/matricet') ||
        lower.contains('t.me/') ||
        lower.startsWith('tg://')) {
      return clean.isNotEmpty && clean.toLowerCase() != 'open link'
          ? clean
          : 'Join Channel';
    }
    if (lower == 'market' ||
        lower.contains('play.google.com') ||
        lower.contains('com.abopia.matricet')) {
      return clean.isNotEmpty && clean.toLowerCase() != 'open link'
          ? clean
          : 'Update MatricET';
    }
    return clean.isNotEmpty ? clean : 'Open Link';
  }
}

class AdminNotificationSegment {
  const AdminNotificationSegment({
    required this.text,
    this.isLink = false,
    this.link,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
  });

  final String text;
  final bool isLink;
  final AdminNotificationLink? link;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
}

class AdminNotificationLinkParser {
  AdminNotificationLinkParser._();

  static final RegExp _bbcodeLinkRegex = RegExp(
    r'\[a(?:\s+href\s*=\s*["' "'" r']?([^"' "'" r'\]\s>]+)["' "'" r']?|\s+url\s*=\s*["' "'" r']?([^"' "'" r'\]\s>]+)["' "'" r']?|=\s*([^\s\]]+))?\s*\](.*?)\[/a\]',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _htmlLinkRegex = RegExp(
    r'<a(?:\s+[^>]*?)?href\s*=\s*["' "'" r']?([^"' "'" r'\s>]+)["' "'" r']?[^>]*>(.*?)</a>',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _markdownLinkRegex = RegExp(
    r'\[([^\]\r\n]+)\]\(((?:https?://|tg://|t\.me/|challenge:|pricing|market|mailto:|tel:)[^\)\s]+)\)',
    caseSensitive: false,
  );

  static final RegExp _rawUrlRegex = RegExp(
    r'(https?://[^\s<>"' "'" r'\]\)]+|(?<!@)(?:t\.me|telegram\.me)/[a-zA-Z0-9_+/]+|(?<![\w@])www\.[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^\s<>"' "'" r'\]\)]*)',
    caseSensitive: false,
  );

  static final RegExp _inlineFormatRegex = RegExp(
    r'\[([biu])\](.*?)\[/\1\]',
    caseSensitive: false,
    dotAll: true,
  );

  /// Extracts the first prominent action link from notification body text.
  static AdminNotificationLink? extractPrimaryLink(String rawText) {
    final segments = parseSegments(rawText);
    for (final seg in segments) {
      if (seg.isLink && seg.link != null) {
        return seg.link;
      }
    }
    return null;
  }

  /// Parses text into styled and interactive segments.
  static List<AdminNotificationSegment> parseSegments(String rawText) {
    if (rawText.isEmpty) return const [];

    final matches = <_TagMatch>[];

    // 1. BBCode [a]
    for (final m in _bbcodeLinkRegex.allMatches(rawText)) {
      final explicitAttr = m.group(1) ?? m.group(2) ?? m.group(3);
      final innerContent = m.group(4) ?? '';
      final url = (explicitAttr != null && explicitAttr.trim().isNotEmpty)
          ? explicitAttr.trim()
          : innerContent.trim();
      final text = innerContent.trim().isNotEmpty ? innerContent.trim() : url;

      matches.add(
        _TagMatch(
          start: m.start,
          end: m.end,
          displayText: text,
          targetUrl: url,
        ),
      );
    }

    // 2. HTML <a>
    for (final m in _htmlLinkRegex.allMatches(rawText)) {
      final href = m.group(1) ?? '';
      final inner = m.group(2) ?? '';
      matches.add(
        _TagMatch(
          start: m.start,
          end: m.end,
          displayText: inner.trim().isNotEmpty ? inner.trim() : href.trim(),
          targetUrl: href.trim(),
        ),
      );
    }

    // 3. Markdown [text](url)
    for (final m in _markdownLinkRegex.allMatches(rawText)) {
      final text = m.group(1) ?? '';
      final url = m.group(2) ?? '';
      matches.add(
        _TagMatch(
          start: m.start,
          end: m.end,
          displayText: text.trim(),
          targetUrl: url.trim(),
        ),
      );
    }

    // Sort matches by start position and deduplicate overlaps
    matches.sort((a, b) => a.start.compareTo(b.start));
    final nonOverlapping = <_TagMatch>[];
    int lastEnd = 0;
    for (final m in matches) {
      if (m.start >= lastEnd) {
        nonOverlapping.add(m);
        lastEnd = m.end;
      }
    }

    final segments = <AdminNotificationSegment>[];
    int cursor = 0;

    for (final tag in nonOverlapping) {
      if (tag.start > cursor) {
        final chunk = rawText.substring(cursor, tag.start);
        _parseChunkWithRawUrlsAndFormatting(chunk, segments);
      }

      segments.add(
        AdminNotificationSegment(
          text: tag.displayText,
          isLink: true,
          link: AdminNotificationLink(
            text: tag.displayText,
            url: tag.targetUrl,
          ),
        ),
      );
      cursor = tag.end;
    }

    if (cursor < rawText.length) {
      final tail = rawText.substring(cursor);
      _parseChunkWithRawUrlsAndFormatting(tail, segments);
    }

    return segments;
  }

  static void _parseChunkWithRawUrlsAndFormatting(
    String chunk,
    List<AdminNotificationSegment> out,
  ) {
    if (chunk.isEmpty) return;

    final urlMatches = _rawUrlRegex.allMatches(chunk).toList();
    if (urlMatches.isEmpty) {
      _parseInlineFormatting(chunk, out);
      return;
    }

    int cursor = 0;
    for (final m in urlMatches) {
      if (m.start > cursor) {
        final textBefore = chunk.substring(cursor, m.start);
        _parseInlineFormatting(textBefore, out);
      }

      final url = m.group(0)!;
      out.add(
        AdminNotificationSegment(
          text: url,
          isLink: true,
          link: AdminNotificationLink(
            text: url,
            url: url,
          ),
        ),
      );
      cursor = m.end;
    }

    if (cursor < chunk.length) {
      final tail = chunk.substring(cursor);
      _parseInlineFormatting(tail, out);
    }
  }

  static void _parseInlineFormatting(
    String text,
    List<AdminNotificationSegment> out,
  ) {
    if (text.isEmpty) return;

    final formatMatches = _inlineFormatRegex.allMatches(text).toList();
    if (formatMatches.isEmpty) {
      out.add(AdminNotificationSegment(text: text));
      return;
    }

    int cursor = 0;
    for (final m in formatMatches) {
      if (m.start > cursor) {
        out.add(AdminNotificationSegment(text: text.substring(cursor, m.start)));
      }

      final tag = (m.group(1) ?? '').toLowerCase();
      final content = m.group(2) ?? '';
      out.add(
        AdminNotificationSegment(
          text: content,
          isBold: tag == 'b',
          isItalic: tag == 'i',
          isUnderline: tag == 'u',
        ),
      );
      cursor = m.end;
    }

    if (cursor < text.length) {
      out.add(AdminNotificationSegment(text: text.substring(cursor)));
    }
  }

  /// Converts parsed segments into a list of [InlineSpan] with gesture recognizers.
  static List<InlineSpan> buildSpans({
    required String rawText,
    required TextStyle baseStyle,
    required TextStyle linkStyle,
    required List<TapGestureRecognizer> recognizers,
    required void Function(String url) onLinkTap,
  }) {
    final segments = parseSegments(rawText);
    if (segments.isEmpty) {
      return [TextSpan(text: rawText, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    for (final seg in segments) {
      if (seg.isLink && seg.link != null) {
        final target = seg.link!.url;
        final recognizer = TapGestureRecognizer()..onTap = () => onLinkTap(target);
        recognizers.add(recognizer);

        spans.add(
          TextSpan(
            text: seg.text,
            style: linkStyle,
            recognizer: recognizer,
            mouseCursor: SystemMouseCursors.click,
          ),
        );
      } else {
        var style = baseStyle;
        if (seg.isBold) style = style.copyWith(fontWeight: FontWeight.w700);
        if (seg.isItalic) style = style.copyWith(fontStyle: FontStyle.italic);
        if (seg.isUnderline) {
          style = style.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: style.color?.withValues(alpha: 0.6),
          );
        }
        spans.add(TextSpan(text: seg.text, style: style));
      }
    }
    return spans;
  }
}

class _TagMatch {
  final int start;
  final int end;
  final String displayText;
  final String targetUrl;

  const _TagMatch({
    required this.start,
    required this.end,
    required this.displayText,
    required this.targetUrl,
  });
}
