/// One row of the home feed: a post, or a shop module set between posts.
sealed class FeedSlot<P, M> {
  const FeedSlot();
}

final class FeedPost<P, M> extends FeedSlot<P, M> {
  const FeedPost(this.post);

  final P post;
}

final class FeedModule<P, M> extends FeedSlot<P, M> {
  const FeedModule(this.module);

  final M module;
}

/// Sets [modules] between [posts]: the first after [firstAfter] posts, then
/// one every [every] posts, and whatever the posts run out before at the end.
///
/// This is what replaced the home page's stack of shelves. The deals, the
/// drops, the bundles and the collection rails all still exist; they arrive
/// as guests in the feed instead of standing in front of it, so she meets a
/// person before she meets a shelf. Nothing is dropped — a short feed simply
/// ends in the modules it had no room for.
///
/// Two modules are never adjacent while posts remain, and none comes before
/// the first post. When there are no posts at all the modules are returned on
/// their own, so an empty feed still leaves a page to shop.
///
/// The spacing is a client-side stand-in. The ordering belongs on the server,
/// which knows which module has anything to say today; until it sends a feed
/// that is already interleaved, this keeps the rhythm fixed and predictable.
List<FeedSlot<P, M>> interleaveFeed<P, M>(
  List<P> posts,
  List<M> modules, {
  int firstAfter = 2,
  int every = 3,
}) {
  assert(firstAfter >= 1 && every >= 1);

  final slots = <FeedSlot<P, M>>[];
  var next = 0;

  for (var i = 0; i < posts.length; i++) {
    slots.add(FeedPost(posts[i]));
    final shown = i + 1;
    final due = shown == firstAfter ||
        (shown > firstAfter && (shown - firstAfter) % every == 0);
    // Never after the last post: whatever is left is appended below in one
    // run, and a module wedged in just before that run would read as part
    // of it anyway.
    if (due && next < modules.length && shown < posts.length) {
      slots.add(FeedModule(modules[next++]));
    }
  }

  for (; next < modules.length; next++) {
    slots.add(FeedModule(modules[next]));
  }
  return slots;
}
