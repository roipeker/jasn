part of jasn;

class NotifierValue<T> extends ValueNotifier<T> {
  static _ObxNotifier? _proxyNotifier;
  final Map<Stream, StreamSubscription> _subscriptions = {};
  DisposerNotifier? _disposer;

  NotifierValue<T> hookDispose(DisposerNotifier? instance) {
    _disposer = instance;
    _disposer?.addListener(_onDispose);
    return this;
  }

  void _onDispose() {
    _disposer?.removeListener(_onDispose);
    dispose();
  }

  /// To prevent potential thrown exceptions.
  bool _disposed = false;

  bool get disposed => _disposed;

  NotifierValue(T value) : super(value);

  final Map<ValueChanged<T>, VoidCallback> _valueListeners = {};

  void addValueListener(ValueChanged<T> listener) {
    if (!_valueListeners.containsKey(listener)) {
      _valueListeners[listener] = () => listener(value);
      addListener(_valueListeners[listener]!);
    }
  }

  bool removeValueListener(ValueChanged<T> listener) {
    if (!_valueListeners.containsKey(listener)) return false;
    removeListener(_valueListeners.remove(listener)!);
    return true;
  }

  FutureOr closeStream(Stream<T> stream) {
    if (_subscriptions.containsKey(stream)) {
      return _subscriptions.remove(stream)!.cancel();
    }
  }

  void bindStream(Stream<T> stream) {
    late StreamSubscription subscription;
    subscription = stream.asBroadcastStream().listen((event) {
      value = event;
    }, onDone: () {
      subscription.cancel();
      _subscriptions.remove(subscription);
    });
    _subscriptions[stream] = subscription;
  }

  @override
  String toString() => '$value';

  T call([T? newValue]) {
    if (newValue != null && newValue != value) {
      value = newValue;
    }
    return value;
  }

  @override
  set value(T newValue) {
    if (newValue != super.value) {
      // if (!_disposed) {
      super.value = newValue;
      // }
    }
  }

  @override
  T get value {
    if (NotifierValue._proxyNotifier != null) {
      NotifierValue._proxyNotifier!.add(this);
    }
    return super.value;
  }

  void update(T Function(T value) fn) {
    value = fn(super.value);
  }

  @override
  void dispose() {
    _disposed = true;
    if (_proxyNotifier != null) {
      _proxyNotifier!.remove(this);
    }
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _subscribedElements.clear();
    super.dispose();
  }

  final _subscribedElements = <ComponentElement, VoidCallback>{};

  T subscribe(BuildContext context) {
    _addContextSubscription(context as ComponentElement);
    return value;
  }

  void _addContextSubscription(ComponentElement context) {
    if (_subscribedElements.keys.contains(context)) return;
    addListener(_subscribedElements[context] = () {
      try {
        context.markNeedsBuild();
      } catch (e) {
        /// Throws cause the Element is dead.
        final selfCallback = _subscribedElements.remove(context)!;
        removeListener(selfCallback);
      }
    });
  }
}

abstract class IValueNotifier<T> {
  /// complies with obs().
}

mixin DisposerMixin<T extends StatefulWidget> on State<T>
    implements DisposerNotifier {
  @override
  final _disposer = _DisposerNotifier();

  @override
  void addListener(VoidCallback fn) => _disposer.addListener(fn);

  @override
  void removeListener(VoidCallback fn) => _disposer.removeListener(fn);

  @override
  void dispose() {
    _disposer.dispose();
    super.dispose();
  }
}

class _DisposerNotifier extends ChangeNotifier {
  @override
  void dispose() {
    notifyListeners();
    super.dispose();
  }
}

abstract class DisposerNotifier {
  final _disposer = _DisposerNotifier();

  void addListener(VoidCallback fn) => _disposer.addListener(fn);

  void removeListener(VoidCallback fn) => _disposer.removeListener(fn);

  void dispose() {
    _disposer.dispose();
  }
}

extension ValueNotifierX<T> on ValueListenable<T> {
  String get string => '$value';

  Widget widget({
    Widget? child,
    required ValueWidgetBuilder<T> builder,
  }) {
    return ValueListenableBuilder<T>(
      valueListenable: this,
      builder: builder,
      child: child,
    );
  }
}

class Observer extends StatelessWidget {
  final Widget Function() builder;

  const Observer(
    this.builder, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ObserverBuilder(
      builder: (_, __) => builder(),
    );
  }
}

class ObserverBuilder extends StatefulWidget {
  final TransitionBuilder builder;
  final Widget? child;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ObjectFlagProperty<Function>.has('builder', builder));
  }

  const ObserverBuilder({
    Key? key,
    required this.builder,
    this.child,
  }) : super(key: key);

  @override
  _ObserverBuilderState createState() => _ObserverBuilderState();
}

class _ObserverBuilderState extends State<ObserverBuilder> {
  late _ObxNotifier notifier = _ObxNotifier(update);

  void update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    notifier.dispose(false);
    super.dispose();
  }

  Widget notifyChild(BuildContext context, Widget? child) {
    final oldNotifier = NotifierValue._proxyNotifier;
    NotifierValue._proxyNotifier = notifier;
    final result = widget.builder(context, child);
    if (!notifier.canUpdate) {
      NotifierValue._proxyNotifier = oldNotifier;
      throw """
      [NotifierValue] improper use of Observer() or ObserverBuilder() detected.
      Use [NotifierValue](s) directly in the scope of the builder().
      If you need to update a parent widget and a child widget, wrap them separately in Observer() or ObserverBuilder().
      """;
    }
    NotifierValue._proxyNotifier = oldNotifier;
    return result;
  }

  @override
  void reassemble() {
    notifier.dispose(true);
    super.reassemble();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: notifier.notifications,
      builder: (_, child) => notifyChild(context, child),
      child: widget.child,
    );
  }
}

class _ObxNotifier {
  static final emptyListener = ChangeNotifier();
  Listenable notifications = emptyListener;
  final VoidCallback stateSetter;
  final _notifications = <NotifierValue>{};
  Set<NotifierValue>? _cachedNotifications;

  final bool _dirtyWidget = false;

  _ObxNotifier(this.stateSetter);

  bool get canUpdate => _notifications.isNotEmpty;

  void add(NotifierValue value) {
    if (!_notifications.contains(value)) {
      if (_cachedNotifications != null &&
          _dirtyWidget &&
          _cachedNotifications!.isNotEmpty) {
        final _cached = _cachedNotifications!;
        for (var m in _cached) {
          m.dispose();
        }
        _notifications.removeAll(_cached);
        _cached.clear();
        _cachedNotifications = null;
      }
      _notifications.add(value);
      _updateCollection();
    }
  }

  void remove(NotifierValue value) {
    if (_notifications.contains(value)) {
      _notifications.remove(value);
      _updateCollection();
    }
  }

  void _updateCollection() {
    if (_notifications.isEmpty) {
      notifications = emptyListener;
    } else {
      notifications = Listenable.merge(_notifications.toList(growable: false));
    }
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) => stateSetter());
  }

  void dispose([bool reassembling = false]) {
    final _buffer = List.of(_notifications);
    // _buffer.forEach((e) {
    //   if (e is _ValueNoti && reassembling) {
    //     e.dispose();
    //   }
    // });
    notifications = emptyListener;
    _notifications.clear();
    _buffer.clear();
    _cachedNotifications?.clear();
    _cachedNotifications = null;
  }
}
