part of jasn;

class _InstanceFactory<T> {
  final _FactoryType factoryType;
  final Bucket owner;
  final String? name;
  Object? instance;
  late final Type keyType;

  bool get isNamed => name != null;

  final FactoryCall<T>? factoryCallback;
  final DisposeCall<T>? disposeCallback;

  _InstanceFactory({
    required this.factoryType,
    required this.owner,
    this.name,
    this.instance,
    this.factoryCallback,
    this.disposeCallback,
  })  : assert(
            !(disposeCallback != null &&
                instance != null &&
                instance is IDisposable),
            ' You can\'t provide `disposeCallback` if registered instance <${instance.runtimeType}> implements "IDisposable"'),
        keyType = T {
    debugPrint('${factoryCallback.runtimeType} /// $T');
  }

  FutureOr dispose() {
    if (instance != null) {
      if (instance is IDisposable) {
        return (instance as IDisposable).dispose();
      } else {
        return disposeCallback?.call(instance as T);
      }
    }
  }

  T getInstance() {
    try {
      switch (factoryType) {
        case _FactoryType.factory:
          final i = factoryCallback!();
          assert(!(disposeCallback != null && i is IDisposable),
              ' You can\'t provide `disposeCallback` if registered create() <${instance.runtimeType}> implements "IDisposable"');
          return i;
        case _FactoryType.singleton:
          return instance as T;
        case _FactoryType.lazy:
          final i = (instance ??= factoryCallback!()) as T;
          assert(!(disposeCallback != null && i is IDisposable),
              ' You can\'t provide `disposeCallback` if lazyPut() <${instance.runtimeType}> implements "IDisposable"');
          return i;
        default:
          throw StateError('[Bucket] Non-existent type $factoryType');
      }
    } catch (e) {
      debugPrint('[Bucket] error creating $T');
      rethrow;
    }
  }
}
