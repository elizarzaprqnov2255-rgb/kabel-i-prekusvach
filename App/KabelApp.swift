import SwiftUI
import WebKit
import UIKit

@main
struct KabelApp: App {
    var body: some Scene {
        WindowGroup {
            WebView()
                .ignoresSafeArea()
                .background(Color.black)
        }
    }
}

struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "pdf")
        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        context.coordinator.web = web
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var web: WKWebView?
        var printer: WKWebView?

        // Страницата изпраща готовия HTML на справката; тук се прави PDF.
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "pdf", let html = message.body as? String else { return }
            let w = WKWebView(frame: CGRect(x: 0, y: 0, width: 842, height: 595))
            w.navigationDelegate = self
            w.alpha = 0.01
            web?.addSubview(w)
            printer = w
            w.loadHTMLString(html, baseURL: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard webView === printer else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.export(webView) }
        }

        private func export(_ wv: WKWebView) {
            let renderer = UIPrintPageRenderer()
            renderer.addPrintFormatter(wv.viewPrintFormatter(), startingAtPageAt: 0)
            let paper = CGRect(x: 0, y: 0, width: 841.89, height: 595.28) // A4 пейзаж
            let printable = paper.insetBy(dx: 28, dy: 28)
            renderer.setValue(NSValue(cgRect: paper), forKey: "paperRect")
            renderer.setValue(NSValue(cgRect: printable), forKey: "printableRect")

            let data = NSMutableData()
            UIGraphicsBeginPDFContextToData(data, paper, nil)
            let pages = renderer.numberOfPages
            renderer.prepare(forDrawingPages: NSRange(location: 0, length: max(pages, 1)))
            let bounds = UIGraphicsGetPDFContextBounds()
            for i in 0..<max(pages, 1) {
                UIGraphicsBeginPDFPage()
                renderer.drawPage(at: i, in: bounds)
            }
            UIGraphicsEndPDFContext()
            wv.removeFromSuperview()
            printer = nil

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("razchet-kabeli.pdf")
            do { try (data as Data).write(to: url) } catch { return }
            guard let root = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController else { return }
            let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            vc.popoverPresentationController?.sourceView = root.view
            vc.popoverPresentationController?.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 1, height: 1)
            root.present(vc, animated: true)
        }
    }
}
