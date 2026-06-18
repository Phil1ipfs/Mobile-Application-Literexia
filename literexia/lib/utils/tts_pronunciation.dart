/// Normalizes short assessment tokens (single letters, "/sound/" notation)
/// into phonetically-spelled, word-like text that ElevenLabs pronounces
/// clearly and at consistent volume.
///
/// A bare single letter like "e" or "c" is read inconsistently (and often
/// silently) by TTS because there's no word context. Mapping it to its
/// Filipino-alphabet letter NAME, spelled phonetically ("si", "key", "ti", ...),
/// makes the voice say the letter name clearly and loudly.
class TtsPronunciation {
  // Filipino alphabet letter names, spelled phonetically for ElevenLabs.
  static const Map<String, String> _letterNames = {
    'a': 'ey',
    'b': 'bi',
    'c': 'si',
    'd': 'di',
    'e': 'ee',
    'f': 'ef',
    'g': 'ji',
    'h': 'etch',
    'i': 'ay',
    'j': 'jey',
    'k': 'key',
    'l': 'el',
    'm': 'em',
    'n': 'en',
    'ñ': 'enye',
    'o': 'oh',
    'p': 'pi',
    'q': 'kyu',
    'r': 'ar',
    's': 'es',
    't': 'ti',
    'u': 'yu',
    'v': 'vi',
    'w': 'dobolyu',
    'x': 'eks',
    'y': 'way',
    'z': 'zi',
  };

  /// Returns a TTS-friendly version of [text]. Leaves normal words/sentences
  /// untouched; only rewrites single letters, doubled-letter cards, all-caps
  /// syllables/words, and "/sound/" notation.
  static String forSpeech(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;

    // Phonetic notation: "/ar/" -> "ar" so TTS reads it as a syllable.
    if (trimmed.length >= 2 &&
        trimmed.startsWith('/') &&
        trimmed.endsWith('/')) {
      return trimmed.substring(1, trimmed.length - 1);
    }

    // Doubled same letter card like "Hh" / "TT" -> that single letter.
    var token = trimmed;
    if (token.length == 2 &&
        _isLetter(token[0]) &&
        token[0].toLowerCase() == token[1].toLowerCase()) {
      token = token[0];
    }

    // Single letter -> Filipino letter name.
    if (token.length == 1) {
      return _letterNames[token.toLowerCase()] ?? token;
    }

    // A single all-caps word/syllable (no spaces) -> lowercase so TTS reads it
    // as a word instead of spelling out the letters (e.g. "DAGA" -> "daga",
    // "NGA" -> "nga").
    if (!token.contains(' ') && RegExp(r'^[A-Z]+$').hasMatch(token)) {
      return token.toLowerCase();
    }

    return token;
  }

  static bool _isLetter(String c) => RegExp(r'[A-Za-zñÑ]').hasMatch(c);
}
