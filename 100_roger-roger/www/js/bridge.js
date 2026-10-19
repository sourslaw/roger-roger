// Communication layer between JavaScript and Swift WKWebView
function sendToNative(action, payload = {}) {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.iOSBridge) {
    window.webkit.messageHandlers.iOSBridge.postMessage({
      action: action,
      ...payload
    });
  } else {
    console.log(`[Browser Mode] Native action triggered: ${action}`, payload);
  }
}