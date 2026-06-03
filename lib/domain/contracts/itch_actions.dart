enum ItchAction {
  attemptLogin,
  loginWithPassword,
  loginSucceeded,
  loginFailed,
  queueGameDownload,
  gameDownloadQueued,
  gameDownloadProgress,
  gameDownloadFinished,
  libraryFetchRequested,
  libraryFetchSucceeded,
  libraryFetchFailed,
}

enum ItchUseCase {
  authLogin,
  authLogout,
  fetchLibrary,
  enqueueDownload,
  trackDownload,
}

const Map<ItchAction, ItchUseCase> actionToUseCaseMap = {
  ItchAction.attemptLogin: ItchUseCase.authLogin,
  ItchAction.loginWithPassword: ItchUseCase.authLogin,
  ItchAction.loginSucceeded: ItchUseCase.authLogin,
  ItchAction.loginFailed: ItchUseCase.authLogin,
  ItchAction.libraryFetchRequested: ItchUseCase.fetchLibrary,
  ItchAction.libraryFetchSucceeded: ItchUseCase.fetchLibrary,
  ItchAction.libraryFetchFailed: ItchUseCase.fetchLibrary,
  ItchAction.queueGameDownload: ItchUseCase.enqueueDownload,
  ItchAction.gameDownloadQueued: ItchUseCase.enqueueDownload,
  ItchAction.gameDownloadProgress: ItchUseCase.trackDownload,
  ItchAction.gameDownloadFinished: ItchUseCase.trackDownload,
};
