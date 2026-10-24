import 'package:ohara/l10n/app_localizations.dart';

final _arabicLetter = RegExp(r'[ء-ي]');

/// A failure's message, made safe to show in the reader's language.
///
/// Server refusals arrive in whatever language the server wrote them — many
/// in Arabic for her, some still in English («Product not found»,
/// «Unexpected error while running repository operation.»). An English
/// sentence on an Arabic screen tells her nothing except that something is
/// broken, so on an Arabic screen a message with no Arabic in it is replaced
/// by a plain, friendly one. English screens keep the original.
String readableMessage(AppLocalizations? l10n, String message) {
  if (l10n == null || !l10n.localeName.startsWith('ar')) return message;
  if (_arabicLetter.hasMatch(message)) return message;
  return l10n.errorRetryLater;
}
