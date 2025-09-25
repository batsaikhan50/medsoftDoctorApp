import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({super.key, required this.url, this.title = "Login"});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));

    _controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) {
          if (request.url.startsWith('medsoftdoctor://callback')) {
            Navigator.of(context).pop();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 140,
      height: 40,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.black),
        label: Text(label, style: const TextStyle(color: Colors.black)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false, // let WebView manage keyboard itself
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF009688),
        title: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 16,
                  top: 1,
                  bottom: 2,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back, color: Colors.black),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        bottom: false, // allow full height, no extra space
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: const Color(0xFFE2E4ED), // background for padding area
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      12,
                    ), // optional rounded edges
                    child: WebViewWidget(controller: _controller),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 16,
              right: 16,
              child: _buildActionButton(
                icon: Icons.refresh,
                label: 'Refresh',
                onPressed: () => _controller.reload(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
