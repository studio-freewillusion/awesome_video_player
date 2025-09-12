import 'package:awesome_video_player/src/core/better_player_utils.dart';

class BetterPlayerSubtitle {
  static const String timerSeparator = ' --> ';
  final int? index;
  final Duration? start;
  final Duration? end;
  final List<String>? texts;

  BetterPlayerSubtitle._({
    this.index,
    this.start,
    this.end,
    this.texts,
  });

  factory BetterPlayerSubtitle(String value, bool isWebVTT) {
    try {
      // If this is WebVTT content, check if it should be rejected
      if (isWebVTT && shouldRejectWebVTTBlock(value)) {
        return BetterPlayerSubtitle._();
      }

      final scanner = value.split('\n');
      if (scanner.length == 2) {
        return _handle2LinesSubtitles(scanner);
      }
      if (scanner.length > 2) {
        return _handle3LinesAndMoreSubtitles(scanner, isWebVTT);
      }
      return BetterPlayerSubtitle._();
    } on Exception catch (_) {
      BetterPlayerUtils.log("Failed to parse subtitle line: $value");
      return BetterPlayerSubtitle._();
    }
  }

  /// Determines if a WebVTT block should be rejected during individual parsing
  static bool shouldRejectWebVTTBlock(String value) {
    final trimmed = value.trim();

    // Reject WEBVTT header
    if (trimmed == "WEBVTT" || trimmed.startsWith("WEBVTT")) {
      return true;
    }

    // Reject NOTE sections
    if (trimmed.startsWith("NOTE")) {
      return true;
    }

    // Check if the block contains timing information (essential for subtitles)
    if (!trimmed.contains('-->')) {
      // This block doesn't contain timing info, reject it
      return true;
    }

    // Reject metadata lines that don't contain timing information
    final lines = trimmed.split('\n');
    if (lines.length <= 2) {
      // Check if it's a metadata line (contains : but no -->)
      for (final line in lines) {
        if (line.contains(':') &&
            !line.contains('-->') &&
            !RegExp(r'^\d+$').hasMatch(line.trim())) {
          return true;
        }
      }
    }

    return false;
  }

  static BetterPlayerSubtitle _handle2LinesSubtitles(List<String> scanner) {
    try {
      final timeSplit = scanner[0].split(timerSeparator);
      final start = _stringToDuration(timeSplit[0]);
      final end = _stringToDuration(timeSplit[1]);
      final texts = scanner.sublist(1, scanner.length);

      return BetterPlayerSubtitle._(
        index: -1,
        start: start,
        end: end,
        texts: texts,
      );
    } on Exception catch (_) {
      BetterPlayerUtils.log("Failed to parse subtitle line: $scanner");
      return BetterPlayerSubtitle._();
    }
  }

  static BetterPlayerSubtitle _handle3LinesAndMoreSubtitles(
      List<String> scanner, bool isWebVTT) {
    try {
      // int? index = -1;
      // List<String> timeSplit = [];
      // int firstLineOfText = 0;
      // if (scanner[0].contains(timerSeparator)) {
      //   timeSplit = scanner[0].split(timerSeparator);
      //   firstLineOfText = 1;
      // } else {
      //   index = int.tryParse(scanner[0]);
      //   timeSplit = scanner[1].split(timerSeparator);
      //   firstLineOfText = 2;
      // }

      // final start = _stringToDuration(timeSplit[0]);
      // final end = _stringToDuration(timeSplit[1]);
      // final texts = scanner.sublist(firstLineOfText, scanner.length);
      // return BetterPlayerSubtitle._(
      //     index: index, start: start, end: end, texts: texts);
      if (scanner.isEmpty) return BetterPlayerSubtitle._();

      final lines = <String>[];
      for (final l in scanner) {
        final t = l.trim();
        if (t.isEmpty && lines.isEmpty) continue;
        lines.add(t);
      }
      while (lines.isNotEmpty && lines.last.isEmpty) {
        lines.removeLast();
      }
      if (lines.length < 2) return BetterPlayerSubtitle._();

      int? index = -1;
      int timeLineIdx = -1;

      bool looksTime(String s) => s.contains('-->');

      if (looksTime(lines[0])) {
        timeLineIdx = 0;
      } else if (lines.length >= 2 && looksTime(lines[1])) {
        timeLineIdx = 1;
        final idxStr = lines[0];
        if (RegExp(r'^\d+$').hasMatch(idxStr)) {
          index = int.tryParse(idxStr) ?? -1;
        } else {
          index = -1;
        }
      } else {
        return BetterPlayerSubtitle._();
      }

      final timeParts = lines[timeLineIdx].split(RegExp(r'\s*-->\s*'));
      if (timeParts.length != 2) return BetterPlayerSubtitle._();

      String _onlyTime(String s) {
        final tok = s.trim().split(RegExp(r'\s+'));
        return tok.isNotEmpty ? tok.first : '';
      }

      final startStr = _onlyTime(timeParts[0]);
      final endStr = _onlyTime(timeParts[1]);
      if (startStr.isEmpty || endStr.isEmpty) return BetterPlayerSubtitle._();

      final start = _stringToDuration(startStr);
      final end = _stringToDuration(endStr);
      if (start == Duration.zero && end == Duration.zero) {
        return BetterPlayerSubtitle._();
      }

      final firstLineOfText = timeLineIdx + 1;
      if (firstLineOfText >= lines.length) return BetterPlayerSubtitle._();

      String _stripTags(String s) {
        var t = s
            .replaceAll(RegExp(r'<\s*v[^>]*>'), '')
            .replaceAll(RegExp(r'</\s*v\s*>'), '');
        t = t.replaceAll(RegExp(r'</?(c|i|b|u|ruby|rt|rb|rp|lang)[^>]*>'), '');
        t = t.replaceAll(RegExp(r'</?[^>]+>'), '');
        return t;
      }

      final texts = <String>[];
      for (var i = firstLineOfText; i < lines.length; i++) {
        final cleaned = _stripTags(lines[i]).trimRight();
        if (cleaned.isEmpty) continue;
        texts.add(cleaned);
      }
      if (texts.isEmpty) return BetterPlayerSubtitle._();

      return BetterPlayerSubtitle._(
        index: index,
        start: start,
        end: end,
        texts: texts,
      );
    } on Exception catch (_) {
      BetterPlayerUtils.log("Failed to parse subtitle line: $scanner");
      return BetterPlayerSubtitle._();
    }
  }

  static Duration _stringToDuration(String value) {
    try {
      final valueSplit = value.split(" ");
      String componentValue;

      if (valueSplit.length > 1) {
        componentValue = valueSplit[0];
      } else {
        componentValue = value;
      }

      final component = componentValue.split(':');
      // Interpret a missing hour component to mean 00 hours
      if (component.length == 2) {
        component.insert(0, "00");
      } else if (component.length != 3) {
        return const Duration();
      }

      final secsAndMillisSplitChar = component[2].contains(',') ? ',' : '.';
      final secsAndMillsSplit = component[2].split(secsAndMillisSplitChar);
      if (secsAndMillsSplit.length != 2) {
        return const Duration();
      }

      final result = Duration(
        hours: int.tryParse(component[0])!,
        minutes: int.tryParse(component[1])!,
        seconds: int.tryParse(secsAndMillsSplit[0])!,
        milliseconds: int.tryParse(secsAndMillsSplit[1])!,
      );
      return result;
    } on Exception catch (_) {
      BetterPlayerUtils.log("Failed to process value: $value");
      return const Duration();
    }
  }

  @override
  String toString() {
    return 'BetterPlayerSubtitle{index: $index, start: $start, end: $end, texts: $texts}';
  }
}
