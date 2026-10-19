import SwiftUI
import UIKit
import WebKit

struct ContentView: View {
    var body: some View {
        HybridWebView()
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}

struct HybridWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "iOSBridge")
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear

        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "www"),
              let wwwURL = Bundle.main.url(forResource: "www", withExtension: nil) else {
            assertionFailure("Missing bundled web app files in www/")
            return webView
        }

        webView.loadFileURL(indexURL, allowingReadAccessTo: wwwURL)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        private let notificationGenerator = UINotificationFeedbackGenerator()
        private let impactGenerator = UIImpactFeedbackGenerator(style: .light)

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "iOSBridge",
                  let payload = message.body as? [String: Any],
                  let action = payload["action"] as? String else {
                return
            }

            switch action {
            case "triggerHaptic":
                let style = payload["style"] as? String ?? "light"
                triggerHaptic(style: style)
            default:
                break
            }
        }

        private func triggerHaptic(style: String) {
            switch style {
            case "light":
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case "medium":
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case "heavy":
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            case "success":
                notificationGenerator.notificationOccurred(.success)
            case "warning":
                notificationGenerator.notificationOccurred(.warning)
            case "error":
                notificationGenerator.notificationOccurred(.error)
            default:
                impactGenerator.impactOccurred()
            }
        }
    }
}
