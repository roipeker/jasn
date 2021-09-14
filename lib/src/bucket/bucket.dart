part of jasn;

class Bucket {
  static final Bucket _instance = Bucket();

  static Bucket get instance => _instance;
  final _byName = <String?, Map<Type, _InstanceFactory>>{};
  bool allowOverload = false;

  _InstanceFactory<T>? _findFactoryMaybeNull<T extends Object>(
    String? name, [
    Type? type,
  ]) {
    assert(
      type != null || const Object() is! T,
      '[Bucket] compiler could not infer the type. You have to provide a <Type> '
      'and optionally a `name`.',
    );
    return _byName[name]?[type ?? T] as _InstanceFactory<T>?;
  }

  _InstanceFactory _findFactoryByInstance(Object i) {
    final factory = _findFactoryByInstanceMaybeNull(i);
    assert(factory != null, 'Instance of ${i.runtimeType} isn\'t registered.');
    return factory!;
  }

  _InstanceFactory? _findFactoryByInstanceMaybeNull(Object instance) {
    final _list = allFactories;
    final _factories = _list.where(
      (factory) => identical(factory.instance, instance),
    );
    return _factories.isNotEmpty ? _factories.first : null;
  }

  _InstanceFactory<T> _findFactory<T extends Object>(
    String? name, [
    Type? type,
  ]) {
    final factory = _findFactoryMaybeNull<T>(name, type);
    assert(
        factory != null,
        '[Bucket] Dependency not registered: <${type ?? T}> ${name != null ? 'name: "$name"' : ''} '
        'Maybe you used a "name" or forgot to register your dependency.');
    return factory!;
  }

  T call<T extends Object>({String? name}) => get<T>(name: name);

  void factory<T extends Object>(T Function() callback, {String? name}) {
    _register<T>(
      type: _FactoryType.factory,
      name: name,
      factoryCallback: callback,
    );
  }

  void _register<T extends Object>({
    required _FactoryType type,
    required String? name,
    FactoryCall<T>? factoryCallback,
    DisposeCall<T>? disposeCallback,
    T? instance,
  }) {
    assert(const Object() is! T,
        '[Bucket] You have to provide a Type != (dynamic || Object)');
    if (_byName[name]?.containsKey(T) == true && !allowOverload) {
      throw '[Bucket] Dependency already registered: <$T> ${name != null ? 'name: "$name"' : ''}';
    }
    final factory = _InstanceFactory<T>(
      factoryType: type,
      owner: this,
      name: name,
      instance: instance,
      disposeCallback: disposeCallback,
      factoryCallback: factoryCallback,
    );
    _byName.putIfAbsent(name, () => <Type, _InstanceFactory<Object>>{});
    _byName[name]![T] = factory;
  }

  T get<T extends Object>({String? name}) {
    final entry = _findFactory<T>(name);
    Object instance = entry.getInstance();
    assert(instance is T,
        "Object with name $name has different type ${entry.keyType} than the call type $T");
    return instance as T;
  }

  bool exists<T extends Object>({
    Object? instance,
    String? name,
  }) {
    if (instance != null) {
      return _findFactoryByInstanceMaybeNull(instance) != null;
    } else {
      return _findFactoryMaybeNull<T>(name) != null;
    }
  }

  void lazyPut<T extends Object>(
    FactoryCall<T> createCall, {
    String? name,
    DisposeCall<T>? disposeCall,
  }) {
    _register(
      type: _FactoryType.lazy,
      name: name,
      factoryCallback: createCall,
      disposeCallback: disposeCall,
    );
  }

  void put<T extends Object>(
    T instance, {
    String? name,
    DisposeCall<T>? disposeCall,
  }) {
    _register(
      type: _FactoryType.singleton,
      name: name,
      instance: instance,
      disposeCallback: disposeCall,
    );
  }

  List<_InstanceFactory> get allFactories =>
      _byName.values.fold([], (prev, x) => prev..addAll(x.values));

  void reset({bool dispose = true}) {
    if (dispose) {
      final _list = allFactories;
      for (final factory in _list) {
        factory.dispose();
      }
    }
    _byName.clear();
  }

  void delete<T extends Object>({
    Object? instance,
    String? name,
    DisposeCall<T>? disposeCall,
  }) {
    late _InstanceFactory factory;
    if (instance != null) {
      factory = _findFactoryByInstance(instance);
    } else {
      factory = _findFactory<T>(name);
    }
    final _map = _byName[factory.name]!;
    if (_map.containsKey(factory.keyType)) {
      _map.remove(factory.keyType)!;
    }
    if (factory.instance != null) {
      if (disposeCall != null) {
        disposeCall.call(factory.instance as T);
      } else {
        factory.dispose();
      }
    }
  }
}

enum _FactoryType {
  singleton,
  lazy,
  factory,
}

typedef FactoryCall<T> = T Function();
typedef DisposeCall<T> = FutureOr Function(T instance);

abstract class IDisposable {
  FutureOr dispose();
}
