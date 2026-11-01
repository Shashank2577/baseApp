/// The hand-drawn minimal design system shared by every app on the platform.
///
/// Rules: design/THEME.md. Tokens: design/tokens.json (generated into
/// src/generated/). Ported from Burrow (Android-Showcase, ui/hand/HandUi.kt).
library;

export 'src/components.dart';
export 'src/doodle.dart' show DoodleIcon, doodlePath, parseSvgPath;
export 'src/generated/doodles.g.dart';
export 'src/generated/tokens.g.dart';
export 'src/hand.dart';
export 'src/theme.dart';
