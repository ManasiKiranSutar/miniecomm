import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'notification_service.dart';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';

@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ProductScreen(),
    );
  }
}

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  _ProductScreenState createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  List products = [];
  List visibleProducts = [];
  List favoriteIds = [];

  ScrollController scrollController = ScrollController();

  int page = 0;
  int perPage = 10;
  bool isLoading = false;
  bool isFirstLoading = true;
  bool hasInternet = true;
  bool isRetrying = false;

  @override
  void initState() {
    super.initState();
    
    _initializeNotificationService();
    checkInternetAndLoad();
    loadFavorites();

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200) {
        loadMore();
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void _initializeNotificationService() {
    try {
      NotificationService notificationService = NotificationService();
      notificationService.requestNotificationPermission();
      notificationService.getFcmToken();
    } catch (e) {
      print('Notification service error: $e');
    }
  }

  Future<void> checkInternetAndLoad() async {
    if (isRetrying) return;
    
    if (!mounted) return;
    
    setState(() {
      isRetrying = true;
    });

    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        if (!mounted) return;
        setState(() {
          hasInternet = false;
          isFirstLoading = false;
          isRetrying = false;
        });
        return;
      }

      try {
        final response = await http.get(
          Uri.parse("https://fakestoreapi.com/products"),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          products = jsonDecode(response.body);
          if (!mounted) return;
          setState(() {
            hasInternet = true;
            isFirstLoading = false;
            isRetrying = false;
          });
          loadMore();
        } else {
          throw Exception('Failed to load products');
        }
      } on TimeoutException catch (_) {
        if (!mounted) return;
        setState(() {
          hasInternet = false;
          isFirstLoading = false;
          isRetrying = false;
        });
      } catch (e) {
        print('Connection error: $e');
        if (!mounted) return;
        setState(() {
          hasInternet = false;
          isFirstLoading = false;
          isRetrying = false;
        });
      }
    } catch (e) {
      print('Internet check error: $e');
      if (!mounted) return;
      setState(() {
        hasInternet = false;
        isFirstLoading = false;
        isRetrying = false;
      });
    }
  }

  void loadMore() {
    if (isLoading || products.isEmpty) return;

    isLoading = true;

    int start = page * perPage;
    int end = start + perPage;

    if (start < products.length) {
      visibleProducts.addAll(
        products.sublist(
          start,
          end > products.length ? products.length : end,
        ),
      );
      page++;
    }

    isLoading = false;
    if (mounted) {
      setState(() {});
    }
  }

  void searchProduct(String text) {
    if (text.isEmpty) {
      // Reset to show all products
      page = 0;
      visibleProducts.clear();
      loadMore();
      return;
    }

    page = 0;
    visibleProducts.clear();

    var filtered = products
        .where((item) =>
            item["title"].toString().toLowerCase().contains(text.toLowerCase()))
        .toList();

    visibleProducts = filtered.take(perPage).toList();

    if (mounted) {
      setState(() {});
    }
  }

  void filterPrice() {
    page = 0;
    visibleProducts.clear();

    var filtered =
        products.where((item) => item["price"] <= 100).toList();

    visibleProducts = filtered.take(perPage).toList();

    if (mounted) {
      setState(() {});
    }
  }

  void toggleFavorite(int id) async {
    try {
      if (favoriteIds.contains(id)) {
        favoriteIds.remove(id);
      } else {
        favoriteIds.add(id);
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        "fav",
        favoriteIds.map((e) => e.toString()).toList(),
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error saving favorites: $e');
    }
  }

  Future loadFavorites() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? saved = prefs.getStringList("fav");

      if (saved != null) {
        favoriteIds = saved.map((e) => int.parse(e)).toList();
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isFirstLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Loading products...'),
              if (isRetrying) ...[
                const SizedBox(height: 10),
                const Text('Retrying...', style: TextStyle(color: Colors.blue)),
              ],
            ],
          ),
        ),
      );
    }

    if (!hasInternet) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Check if Lottie asset exists, otherwise use icon
                Container(
                  height: 200,
                  child: Lottie.asset(
                    'assets/animations/no_internet.json',
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.wifi_off_rounded,
                        size: 100,
                        color: Colors.grey[400],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "No Internet Connection",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Please check your internet connection and try again",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: isRetrying ? null : () {
                    setState(() {
                      isFirstLoading = true;
                      hasInternet = true;
                    });
                    checkInternetAndLoad();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: isRetrying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Retry",
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mini E-Commerce"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: products.isNotEmpty ? filterPrice : null,
            tooltip: 'Filter products under ₹100',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search products...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: searchProduct,
              enabled: products.isNotEmpty,
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const Center(
                    child: Text('No products available'),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      page = 0;
                      visibleProducts.clear();
                      await checkInternetAndLoad();
                    },
                    child: GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: visibleProducts.length + (isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == visibleProducts.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        var item = visibleProducts[index];

                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(10),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: item["image"] ?? '',
                                    fit: BoxFit.contain,
                                    placeholder: (context, url) =>
                                        const Center(child: CircularProgressIndicator()),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error, size: 40),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item["title"] ?? 'No title',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "₹${item["price"]?.toString() ?? '0'}",
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "⭐ ${item["rating"]?["rate"]?.toString() ?? '0'}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: Icon(
                                    favoriteIds.contains(item["id"])
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => toggleFavorite(item["id"]),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
