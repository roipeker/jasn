### jasn

My take on bringing the Widget to the Stateful.

## Features

- Basically uses StatefulWidgets as `Controller` to store your logic, moving the `build(BuildContext)` to 
the Widget part.

`StateWidget`: Widget to use instead of **StatefulWidget**.
`StateController`: "stateful" class to use instead of **State**

`ParentStateWidget<StateController>` (or the mixin on StatelessWidget `ParentStateMixin<StateController>`)
to inherit a "state" from a parent StateController.

- Provides a basic dependency injection with `Bucket`.

- Has a `NotifierValue<T>`, a glorified reactive ValueNotifier. That works with `Observer()` and `ObserverBuilder()` widgets.

- Makes heavy usage of extensions on `BuildContext`.
To dispatch notifications, you can use `context.notifyData()` and capture it up in the tree with `NotificationListener()`

## Getting started

Install with:

```yaml
dependencies:
  jasn:
    git: https://github.com/roipeker/jasn.git
```


## Usage


### Buckets

Create Bucket:
`final bucket = Bucket();`
or use the singleton `Bucket.instance`


Inject an instance:
```dart
bucket.put(MyService());
```

Lazy initialization (creates instance when its retrieved).
```dart
bucket.lazyPut(()=>MyService());
```

Factory instance generation (creates a new instance each time is retrieved)
```dart
bucket.factory(()=>MyService());
```

Retrieve an Instance:
```dart
final MyService service = bucket.get();

// or callable version 
bucket<MyService>();
``` 

Remove an instance:
```dart
bucket.delete<MyService>();
```

Reset all instances:
```dart
bucket.reset();
```

Check if it exists:
```dart
bucket.exists<MyService>()
```

---

### StateController and Widget

```dart

class HomePage extends StateWidget<HomePageState> {
  const HomePage({Key? key}) : super(key: key);
  
  @override
  createState() => HomePageState();
 
  /// Like an StatefulWidget but `build()` comes here.  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(),
       body: HomeMenu(),
    );
  }
}

/// The State is a `StateController`
class HomePageState extends StateController<HomePage> {
  late final name = 'Nick'.obs();
  late final switcher = false.obs(onChange: onSwitchChange);
  
  String get someUserName => bucket<SomeService>().username;

  @override
  void dispose() {
    name.dispose();
    switcher.dispose();
    super.dispose();
  }

  void onChangeNamePress() {
    name.value += 'o';
  }
}


/// A Stateless widget... that searches for a parent StateController
class HomeMenu extends ParentStateWidget<HomePageState> {
  const HomeMenu({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    
    /// you can "subscribe" to `NotifierValue` (.obs) as if it where InheritedWidgets.
    /// This Stateless will rebuild when `switcher` changes.
    final value = context.listen(state.switcher);
    return Column(
        children:[
        Observer(() => Text(state.name)),
        Observer(() => Text("switch is: $value")),
    ]);
   }
}

```

## Additional information

Is just a playful idea to stay purist on Flutter.