part of jasn;

/// Instead of `StatefulWidget`, and consumes a [StateController].
abstract class StateWidget<T extends State> extends StatefulWidget {
  const StateWidget({Key? key}) : super(key: key);

  Widget build(BuildContext context);

  T get state => StateElement._elements[this] as T;

  @override
  StateElement createElement() => StateElement(this);

  @override
  StateController createState();
}

class StateElement extends StatefulElement with ExposedElementMixin {
  static final _elements = Expando('State Controllers');

  bool _justMounted = true;

  StateElement(StateWidget widget) : super(widget) {
    _elements[widget] = state;
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    _justMounted = true;
    super.mount(parent, newSlot);
  }

  @override
  void unmount() {
    _justMounted = false;
    super.unmount();
  }

  @override
  void update(StatefulWidget newWidget) {
    _elements[newWidget] = state;
    super.update(newWidget);
  }

  @override
  void rebuild() {
    if (_justMounted) {
      _justMounted = false;
      (state as StateController).readyState();
    }
    super.rebuild();
  }

  @override
  StateWidget get widget => super.widget as StateWidget;

  @override
  Widget build() => widget.build(this);
}

/// use [StateController] instead of `State` for [StateWidget].
class StateController<T extends StateWidget> extends State<T> {
  @alwaysThrows
  @override
  Widget build(BuildContext context) {
    throw "$runtimeType.build() is invalid. Use <StateWidget.build()> instead.";
  }

  /// Use this instead of didChangeDependencies() / initState()
  /// context is "safe"
  @visibleForOverriding
  @protected
  void readyState() {}

  @override
  StatefulElement get context => super.context as StatefulElement;

  NavigatorState get navigator => Navigator.of(context);

  Object? get navigatorArguments => ModalRoute.of(context)?.settings.arguments;

  /// useless for now.
  void addDependant(BuildContext other) {}

  void removeDependant(BuildContext other) {}
}

mixin ParentStateMixin<T extends StateController> on StatelessWidget {
  T get state =>
      (StateElement._elements[this] as ParentStateElement)._otherState as T;

  @override
  ParentStateElement createElement() {
    assert(const Object() is! T, """
          You have to provide a subclass of StateController:
          $runtimeType extends ParentStateWidget<StateController>
       """);
    return ParentStateElement<T>(this);
  }
}

/// Use instead of `StatelessWidget` to consume parent [StateControllers].
abstract class ParentStateWidget<T extends StateController>
    extends StatelessWidget with ParentStateMixin<T> {
  const ParentStateWidget({Key? key}) : super(key: key);

// T get state =>
//     (StateElement._elements[this] as ParentStateElement)._otherState as T;
//
// @override
// ParentStateElement createElement() {
//   assert(const Object() is! T, """
//         You have to provide a subclass of StateController:
//         $runtimeType extends ParentStateWidget<StateController>
//      """);
//   return ParentStateElement<T>(this);
// }
}

mixin ExposedElementMixin on ComponentElement {
  bool mounted = false;

  @override
  void mount(Element? parent, Object? newSlot) {
    mounted = true;
    super.mount(parent, newSlot);
  }

  @override
  void unmount() {
    mounted = false;
    _clearNotifiers();
    super.unmount();
  }

  void _clearNotifiers() {
    for (final notifier in _notifiers) {
      notifier.removeListener(_onNotification);
    }
    _notifiers.clear();
  }

  final _notifiers = <NotifierValue>{};

  // void _removeNotifier(NotifierValue notifier) {
  //   if (_notifiers.remove(notifier)) {
  //     notifier.removeListener(_onNotification);
  //   }
  // }
  // void _addNotifier(NotifierValue notifier) {
  //   _notifiers.add(notifier);
  //   notifier.addListener(_onNotification);
  // }

  void _onNotification() {
    markNeedsBuild();
  }
}

class ParentStateElement<T extends StateController> extends StatelessElement
    with ExposedElementMixin {
  late T _otherState;

  ParentStateElement(StatelessWidget widget) : super(widget) {
    StateElement._elements[widget] = this;
  }

  bool _justMounted = true;

  @override
  void mount(Element? parent, Object? newSlot) {
    _justMounted = true;
    super.mount(parent, newSlot);
  }

  @override
  Widget build() {
    if (_justMounted) {
      // TODO: any other methods where the State changes it's position in the
      // todo: tree?
      final _state = findStateControllerProvider();
      if (_state == null) {
        throw """
        [ParentStateWidget] can't find a parent StateController <$T> dependency in the Widget tree.
        Make sure you have a StateWidget<$T> somewhere up the tree.
        """;
      }
      _otherState = _state;
      _justMounted = false;
    }
    return super.build();
  }

  @override
  void unmount() {
    _justMounted = false;
    _otherState.removeDependant(this);
    super.unmount();
  }

  @override
  void update(StatelessWidget newWidget) {
    StateElement._elements[newWidget] = this;
    super.update(newWidget);
  }

  T? findStateControllerProvider() {
    T? _state;
    visitAncestorElements((element) {
      if (element is StateElement && element.state is T) {
        _state = element.state as T;
        return false;
      }
      return true;
    });
    return _state;
  }

// @override
// ParentStateWidget get widget => super.widget as ParentStateWidget;
}
