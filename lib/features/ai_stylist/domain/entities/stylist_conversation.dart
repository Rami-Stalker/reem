import 'package:equatable/equatable.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/ai_stylist/domain/entities/style_brief.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_message.dart';

class StylistConversation extends Equatable {
  final String id;
  final String? title;
  final String status;

  /// Everything the thread has established so far, merged across its turns.
  final StyleBrief? brief;

  final int messagesCount;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  /// Populated only when a single conversation is fetched.
  final List<StylistMessage> messages;

  const StylistConversation({
    required this.id,
    required this.createdAt,
    this.title,
    this.status = 'ACTIVE',
    this.brief,
    this.messagesCount = 0,
    this.lastMessageAt,
    this.messages = const [],
  });

  bool get isEmpty => messagesCount == 0;

  @override
  List<Object?> get props => [id, title, status, messagesCount, lastMessageAt];
}

/// One completed exchange: her message, the reply, and the updated brief.
class StylistTurn extends Equatable {
  final StylistConversation conversation;
  final StylistMessage userMessage;
  final StylistMessage assistantMessage;
  final StyleBrief brief;

  const StylistTurn({
    required this.conversation,
    required this.userMessage,
    required this.assistantMessage,
    required this.brief,
  });

  @override
  List<Object?> get props => [conversation, userMessage, assistantMessage, brief];
}

/// Her stated taste, plus what her behaviour says about it.
///
/// The two halves are kept apart because they answer different questions and
/// because the stated half wins on conflict — she knows her own size better
/// than her clickstream does.
class StylePreferences extends Equatable {
  final String modesty;
  final String modestyLabel;
  final List<StyleTerm> personas;
  final List<StyleTerm> favouriteColours;
  final List<StyleTerm> avoidedColours;
  final List<String> preferredCategorySlugs;
  final List<String> avoidedCategorySlugs;

  final String? clothingSize;
  final String? shoeSize;

  final Money? budgetMin;
  final Money? budgetMax;

  /// The band she actually buys in, from her own orders.
  final Money? typicalMin;
  final Money? typicalMax;

  /// What her behaviour says — shown back to her so the personalization is
  /// inspectable rather than mysterious.
  final DerivedTaste? derived;
  final DateTime? computedAt;

  const StylePreferences({
    this.modesty = 'UNSPECIFIED',
    this.modestyLabel = '',
    this.personas = const [],
    this.favouriteColours = const [],
    this.avoidedColours = const [],
    this.preferredCategorySlugs = const [],
    this.avoidedCategorySlugs = const [],
    this.clothingSize,
    this.shoeSize,
    this.budgetMin,
    this.budgetMax,
    this.typicalMin,
    this.typicalMax,
    this.derived,
    this.computedAt,
  });

  static const empty = StylePreferences();

  bool get hasStatedAnything =>
      modesty != 'UNSPECIFIED' ||
      personas.isNotEmpty ||
      favouriteColours.isNotEmpty ||
      clothingSize != null ||
      shoeSize != null ||
      budgetMax != null;

  @override
  List<Object?> get props => [
        modesty,
        personas,
        favouriteColours,
        avoidedColours,
        clothingSize,
        shoeSize,
        budgetMin,
        budgetMax,
        derived,
      ];
}

/// The behaviour-derived half of the profile.
class DerivedTaste extends Equatable {
  final List<StyleTerm> topCategories;
  final List<StyleTerm> topColours;
  final int viewedCount;
  final int savedCount;
  final int purchasedCount;
  final int dismissedCount;

  /// `new` / `browsing` / `engaged` / `loyal` — how much evidence there is,
  /// which is what scales how far personalization may move a ranking.
  final String maturity;

  const DerivedTaste({
    this.topCategories = const [],
    this.topColours = const [],
    this.viewedCount = 0,
    this.savedCount = 0,
    this.purchasedCount = 0,
    this.dismissedCount = 0,
    this.maturity = 'new',
  });

  bool get hasSignal =>
      viewedCount > 0 || savedCount > 0 || purchasedCount > 0;

  @override
  List<Object?> get props => [
        topCategories,
        topColours,
        viewedCount,
        savedCount,
        purchasedCount,
        dismissedCount,
        maturity,
      ];
}

/// Everything an empty stylist screen needs in one request.
class StylistBootstrap extends Equatable {
  /// Opening prompts, tuned by what we already know of her.
  final List<String> prompts;
  final List<StylistConversation> conversations;
  final StylePreferences preferences;

  /// The server's closed vocabularies, so a chip in the app can never offer a
  /// value the server would refuse.
  final List<StyleTerm> occasions;
  final List<StyleTerm> colours;
  final List<StyleTerm> slots;

  /// Where a fresh conversation would start from.
  final StyleBrief seedBrief;

  const StylistBootstrap({
    this.prompts = const [],
    this.conversations = const [],
    this.preferences = StylePreferences.empty,
    this.occasions = const [],
    this.colours = const [],
    this.slots = const [],
    this.seedBrief = StyleBrief.empty,
  });

  static const empty = StylistBootstrap();

  @override
  List<Object?> get props => [prompts, conversations, preferences, occasions, colours];
}
