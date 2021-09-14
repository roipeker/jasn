part of jasn;

extension NotifierIntX on int {
  NotifierValue<int> obs({
    DisposerNotifier? disposer,
    ValueChanged<int>? onChange,
  }) {
    final o = NotifierValue<int>(this)..hookDispose(disposer);
    if (onChange != null) {
      o.addValueListener(onChange);
    }
    return o;
  }
}

extension NotifierDoubleX on double {
  NotifierValue<double> obs({
    DisposerNotifier? disposer,
    ValueChanged<double>? onChange,
  }) {
    final o = NotifierValue<double>(this)..hookDispose(disposer);
    if (onChange != null) {
      o.addValueListener(onChange);
    }
    return o;
  }
}

extension NotifierStringX on String {
  NotifierValue<String> obs({
    DisposerNotifier? disposer,
    ValueChanged<String>? onChange,
  }) {
    final o = NotifierValue<String>(this)..hookDispose(disposer);
    if (onChange != null) {
      o.addValueListener(onChange);
    }
    return o;
  }
}

extension NotifierBoolX on bool {
  NotifierValue<bool> obs({
    DisposerNotifier? disposer,
    ValueChanged<bool>? onChange,
  }) {
    final o = NotifierValue<bool>(this);
    o.hookDispose(disposer);
    if (onChange != null) {
      o.addValueListener(onChange);
    }
    return o;
  }
}

extension NotifierValueBoolX on NotifierValue<bool> {
  bool get isTrue => value;

  bool get isFalse => !isTrue;

  bool operator &(bool other) => other && value;

  bool operator |(bool other) => other || value;

  bool operator ^(bool other) => !other == value;

  void toggle() {
    value = !value;
  }
}

extension NotifierValueInterfaseX<T extends IValueNotifier> on T {
  NotifierValue<T> obs({
    DisposerNotifier? disposer,
    ValueChanged<T>? onChange,
  }) {
    final o = NotifierValue<T>(this)..hookDispose(disposer);
    if (onChange != null) {
      o.addValueListener(onChange);
    }
    return o;
  }
}

/// --- notifications.
/// Consume with [NotificationListener<Type>()] Widget.
extension ContextNotificationX on BuildContext {
  EventNotification notifyEvent(String type, {Object? data}) =>
      EventNotification.get(type, data: data)..dispatch(this);

  void notifyData<T>(T event) => DataNotification(event).dispatch(this);
}

extension ContextNotifierValueX on BuildContext {
  T listen<T>(NotifierValue<T> notifier) => notifier.subscribe(this);
}

extension BuildContextX on BuildContext {
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => theme.textTheme;

  Size? get size => this.size;

  /// Get the ui.Image bytes list to export to File, or consume with Image.memory()
  Future<Uint8List> toImageBytes({
    double pixelRatio = 1.0,
    EdgeInsets margin = EdgeInsets.zero,
    ui.ImageByteFormat format = ui.ImageByteFormat.png,
  }) =>
      toImage(pixelRatio: pixelRatio, margin: margin)
          .then((value) => value.bytes(format));

  /// Get an ui.Image capture of this Element's RenderObject.
  Future<ui.Image> toImage({
    double pixelRatio = 1.0,
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    final e = this as Element;
    if (e.dirty) {
      // print('[toImage()] Element is dirty, waiting 1 frame to capture image');
      return Future.microtask(
          () => _captureImageFromElement(e, scale: pixelRatio, margin: margin));
    }
    return _captureImageFromElement(e, scale: pixelRatio, margin: margin);
  }

  static final OffsetLayer _stopRecordingLayer = OffsetLayer();

  Future<ui.Image> _captureImageFromElement(
    Element e, {
    double scale = 1.0,
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    if (e.dirty) {
      return Future.error(
          ErrorHint('[toImage()] BuildContext is in dirty state.'));
    }
    assert(e.renderObject is RenderBox,
        "[context.toImage()] Can only capture capture RenderObject descendants.");
    final ro = e.renderObject as RenderBox;
    final _samplerLayer = OffsetLayer();
    final paintContext = PaintingContext(
        _samplerLayer, margin.inflateRect(Offset.zero & ro.size));
    ro.paint(paintContext, Offset.zero);
    // preferred adding a static Layer than using the protected method to stop
    // recording?
    /// paintContext.stopRecordingIfNeeded();
    paintContext.addLayer(_stopRecordingLayer);
    return _samplerLayer.toImage(
      paintContext.estimatedBounds,
      pixelRatio: scale,
    );
  }
}

extension UiImageX on ui.Image {
  Future<Uint8List> bytes([
    ui.ImageByteFormat format = ui.ImageByteFormat.png,
  ]) async =>
      (await toByteData(format: format))!.buffer.asUint8List();
}
