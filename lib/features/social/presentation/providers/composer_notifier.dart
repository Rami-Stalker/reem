import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/features/social/domain/entities/content.dart';
import 'package:reem/features/social/domain/entities/content_draft.dart';
import 'package:reem/features/social/domain/repositories/social_repository.dart';
import 'package:reem/l10n/app_localizations.dart';

/// What the composer has to say, as meaning rather than copy.
///
/// A notifier has no `BuildContext`, so it cannot localise — the pattern this
/// project settled on is an enum the screen resolves. `AuthMessage` and
/// `CreateMessage` are the same shape.
enum ComposerMessage {
  published,
  publishedForReview,
  needsMedia,
  needsVideo,
  needsCaption,
  videoTooLong,
  waitForUploads;

  String resolve(AppLocalizations l10n) => switch (this) {
    ComposerMessage.published => l10n.composerPublished,
    ComposerMessage.publishedForReview => l10n.composerPublishedForReview,
    ComposerMessage.needsMedia => l10n.composerNeedsMedia,
    ComposerMessage.needsVideo => l10n.composerNeedsVideo,
    ComposerMessage.needsCaption => l10n.composerNeedsCaption,
    ComposerMessage.videoTooLong => l10n.composerVideoTooLong,
    ComposerMessage.waitForUploads => l10n.mediaWaitForUploads,
  };
}

class ComposerState {
  const ComposerState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.types = const [],
    this.taggable = const [],
    this.draft,
    this.error,
    this.errorMessage,
    this.successMessage,
    this.published,
  });

  final bool isLoading;
  final bool isSubmitting;
  final List<ContentTypeOption> types;
  final List<TaggableProduct> taggable;
  final ContentDraft? draft;

  /// Server-supplied text, already localised. Kept beside the typed message
  /// because a refusal the server explains is better than one we guess at.
  final String? error;
  final ComposerMessage? errorMessage;
  final ComposerMessage? successMessage;
  final Content? published;

  ContentTypeOption? get selectedType {
    final key = draft?.contentType;
    if (key == null) return null;
    for (final type in types) {
      if (type.key == key) return type;
    }
    return null;
  }

  ComposerState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<ContentTypeOption>? types,
    List<TaggableProduct>? taggable,
    ContentDraft? draft,
    String? error,
    ComposerMessage? errorMessage,
    ComposerMessage? successMessage,
    Content? published,
    bool clearMessages = false,
  }) {
    return ComposerState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      types: types ?? this.types,
      taggable: taggable ?? this.taggable,
      draft: draft ?? this.draft,
      error: clearMessages ? null : (error ?? this.error),
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages
          ? null
          : (successMessage ?? this.successMessage),
      published: published ?? this.published,
    );
  }
}

/// Writing a post, a reel or a story.
///
/// The formats it offers come from the server's registry, filtered to what
/// this role may publish — not from a list in the client. A hard-coded list
/// is a second answer to a question the server already answers, and the two
/// drift: a woman fills in a form and is refused at the end.
class ComposerNotifier extends StateNotifier<ComposerState> {
  ComposerNotifier(this._repository, {required this.isSeller})
    : super(const ComposerState());

  final SocialRepository _repository;
  final bool isSeller;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearMessages: true);

    final results = await Future.wait([
      _repository.contentTypes(),
      _repository.taggableProducts(),
    ]);

    final typesResult = results[0] as Result<List<ContentTypeOption>>;
    final taggableResult = results[1] as Result<List<TaggableProduct>>;

    final types = switch (typesResult) {
      Success(:final data) => data,
      Error() => const <ContentTypeOption>[],
    };
    final taggable = switch (taggableResult) {
      Success(:final data) => data,
      // A picker that fails to load is not a reason to refuse her a post with
      // no product in it.
      Error() => const <TaggableProduct>[],
    };

    state = state.copyWith(
      isLoading: false,
      types: types,
      taggable: taggable,
      draft:
          state.draft ??
          (types.isEmpty
              ? null
              : ContentDraft(contentType: types.first.key)),
      error: typesResult is Error<List<ContentTypeOption>>
          ? typesResult.failure.message
          : null,
    );
  }

  void selectType(String contentType) {
    final draft = state.draft;
    if (draft == null) return;
    // Media does not survive a format change: a reel needs a clip and a post
    // takes photographs, so carrying the wrong kind across would produce a
    // draft the server refuses for a reason she cannot see.
    state = state.copyWith(
      draft: draft.copyWith(
        contentType: contentType,
        media: const [],
      ),
      clearMessages: true,
    );
  }

  void setCaption(String caption) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(draft: draft.copyWith(caption: caption));
  }

  void setMedia(List<MediaItem> media) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(draft: draft.copyWith(media: media));
  }

  void toggleProduct(String productId) {
    final draft = state.draft;
    if (draft == null) return;
    final tags = [...draft.productTags];
    tags.contains(productId) ? tags.remove(productId) : tags.add(productId);
    state = state.copyWith(draft: draft.copyWith(productTags: tags));
  }

  void setVisibility(ContentVisibility visibility) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(draft: draft.copyWith(visibility: visibility));
  }

  /// Checked here as well as on the server, because a refusal after the upload
  /// has already cost her the bytes and the wait.
  ComposerMessage? _validate(ContentDraft draft, ContentTypeOption? type) {
    if (type == null) return ComposerMessage.needsMedia;
    if (draft.caption.trim().isEmpty && draft.media.isEmpty) {
      return ComposerMessage.needsCaption;
    }
    if (type.videoRequired) {
      final hasVideo = draft.media.any((item) => item.isVideo);
      if (!hasVideo) return ComposerMessage.needsVideo;
    }
    if (type.supportsMedia && type.format == ContentFormat.story &&
        draft.media.isEmpty) {
      return ComposerMessage.needsMedia;
    }
    return null;
  }

  Future<void> publish() async {
    final draft = state.draft;
    if (draft == null || state.isSubmitting) return;

    final problem = _validate(draft, state.selectedType);
    if (problem != null) {
      state = state.copyWith(clearMessages: true, errorMessage: problem);
      return;
    }

    state = state.copyWith(isSubmitting: true, clearMessages: true);
    final result = await _repository.publish(draft);
    state = switch (result) {
      Success(:final data) => state.copyWith(
        isSubmitting: false,
        published: data,
        // Her first pieces go to review. Saying so is the difference between
        // "it worked" and "why can nobody see my post".
        successMessage: data.isUnderReview
            ? ComposerMessage.publishedForReview
            : ComposerMessage.published,
      ),
      Error(:final failure) => state.copyWith(
        isSubmitting: false,
        error: failure.message,
      ),
    };
  }

  void clearMessages() => state = state.copyWith(clearMessages: true);
}
