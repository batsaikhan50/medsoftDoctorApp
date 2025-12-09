import 'dart:convert';
import 'dart:typed_data';

import 'package:medsoft_doctor/api/blog_dao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BlogDAO blogDAO = BlogDAO();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: blogDAO.getAllNews(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final response = snapshot.data!;
          debugPrint('News response: ${response.message}');
          if (response.data == null || response.data!.isEmpty) {
            return const Center(child: Text("No news found"));
          }

          final news = response.data!;

          // 🌟 New: Wrap the content in FractionallySizedBox to limit height to 50%
          return FractionallySizedBox(
            heightFactor: 0.5, // Restricts the height to 50% of the available space
            child: Column(
              children: [
                // The PageView.builder is already inside an Expanded, which will
                // make it fill the 50% height provided by the FractionallySizedBox.
                Expanded(
                  child: PageView.builder(
                    itemCount: news.length,
                    controller: PageController(viewportFraction: 0.8),
                    itemBuilder: (context, index) {
                      final item = news[index];

                      return GestureDetector(
                        onTap: () => _openNewsDetail(context, item["_id"]),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // IMAGE
                                Expanded(
                                  flex: 3,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: Image.memory(
                                      _decodeBase64(item["image"]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),

                                // TITLE
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Center(
                                      child: Text(
                                        item["title"] ?? "",
                                        maxLines: 7,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Converts base64 string to Uint8List
  Uint8List _decodeBase64(String img) {
    final base64String = img.split(',').last;
    return base64Decode(base64String);
  }

  // Opens dialog with detail API
  void _openNewsDetail(BuildContext context, String id) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        child: FutureBuilder(
          future: blogDAO.getNewsDetail(id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }

            final response = snapshot.data!;
            final item = response.data; // fixed: single object

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // IMAGE
                  if (item["image"] != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      child: Image.memory(_decodeBase64(item["image"])),
                    ),

                  const SizedBox(height: 12),

                  // TITLE
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      item["title"] ?? "",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // MERGED VALUES (HTML)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Html(data: item["mergedValues"] ?? "<p>No content</p>"),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
