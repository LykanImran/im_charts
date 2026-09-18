import 'dart:js_interop';

@JS('eval')
external void _eval(String code);

bool _hasInjectedWebZoomPrevent = false;

void preventWebBrowserPinchZoom() {
  if (_hasInjectedWebZoomPrevent) return;
  _hasInjectedWebZoomPrevent = true;
  try {
    _eval('''
      if (typeof window !== 'undefined' && !window._imChartsWheelPreventInstalled) {
        window._imChartsWheelPreventInstalled = true;
        window.addEventListener('wheel', function(e) {
          if (e.ctrlKey) {
            e.preventDefault();
          }
        }, { capture: true, passive: false });
      }
    ''');
  } catch (_) {}
}
