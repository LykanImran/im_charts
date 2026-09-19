import 'dart:js_interop';

@JS('eval')
external void _eval(String code);

@JS('window._imChartsLastWheelCtrl')
external bool? get _lastWheelCtrl;

bool _hasInjectedWebZoomPrevent = false;

void preventWebBrowserPinchZoom() {
  if (_hasInjectedWebZoomPrevent) return;
  _hasInjectedWebZoomPrevent = true;
  try {
    _eval('''
      if (typeof window !== 'undefined' && !window._imChartsWheelPreventInstalled) {
        window._imChartsWheelPreventInstalled = true;
        window._imChartsLastWheelCtrl = false;
        window.addEventListener('wheel', function(e) {
          window._imChartsLastWheelCtrl = !!e.ctrlKey;
          if (e.ctrlKey) {
            e.preventDefault();
          }
        }, { capture: true, passive: false });
      }
    ''');
  } catch (_) {}
}

/// Returns true if the most recent browser wheel event had ctrlKey=true.
/// On macOS, browser converts trackpad pinch to wheel+ctrlKey. Flutter's
/// HardwareKeyboard does NOT see this synthetic ctrlKey, so we track it in JS.
bool isWebWheelCtrlKey() {
  try {
    return _lastWheelCtrl ?? false;
  } catch (_) {
    return false;
  }
}
