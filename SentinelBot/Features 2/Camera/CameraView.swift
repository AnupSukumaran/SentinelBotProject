import SwiftUI
import WebKit

struct CameraView: View {
    let streamURL = URL(string: "http://192.168.1.180:8080/stream")!

    var body: some View {
        MJPEGStreamView(url: streamURL)
            .ignoresSafeArea()
            .navigationTitle("Camera")
    }
}

struct MJPEGStreamView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.contentMode = .scaleAspectFit
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
