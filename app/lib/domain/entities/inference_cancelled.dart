/// Cooperative cancellation, observed only outside active native operations.
class InferenceCancelled extends StateError {
  InferenceCancelled() : super('Local inference superseded.');
}

void checkInferenceCancelled(bool Function()? isCancelled) {
  if (isCancelled?.call() == true) throw InferenceCancelled();
}
