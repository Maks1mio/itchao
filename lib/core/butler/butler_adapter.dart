abstract interface class ButlerAdapter {
  Future<void> queueInstall({
    required int gameId,
    required String gameTitle,
  });
}

class AndroidButlerAdapter implements ButlerAdapter {
  @override
  Future<void> queueInstall({
    required int gameId,
    required String gameTitle,
  }) async {}
}
