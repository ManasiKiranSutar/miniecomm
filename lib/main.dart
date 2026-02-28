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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ProductScreen(),
    );
  }
}

class ProductScreen extends StatefulWidget {
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
  bool isFirstLoading = false;
  bool hasInternet = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize notification service with error handling
    try {
      NotificationService notificationService = NotificationService();
      notificationService.requestNotificationPermission();
      notificationService.getFcmToken();
    } catch (e) {
      print('Notification service error: $e');
    }
    
    checkInternetAndLoad();
    loadFavorites();

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200) {
        loadMore();
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground message: ${message.notification?.title}");

      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.notification?.title ?? "New Notification",
            ),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification clicked!");
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> checkInternetAndLoad() async {
    setState(() {
      isFirstLoading = true;
    });

    try {
      final connectivityResult =
      await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        print("inside no internet\n");
        setState(() {
          hasInternet = false;
          isFirstLoading = false;
        });
        return;
      }

      // Instead of InternetAddress.lookup
      final response = await http
          .get(Uri.parse("https://fakestoreapi.com/products"))
          .timeout(const Duration(seconds: 5));

      print("response ${response.body}");

      if (response.statusCode == 200) {
        setState(() {
          hasInternet = true;
          products = jsonDecode(response.body);
          isFirstLoading = false;
        });

        loadMore();
      } else {
        throw Exception("API failed");
      }
    } catch (e) {
      print("Internet check error: $e");
      setState(() {
        hasInternet = false;
        isFirstLoading = false;
      });
    }
  }
  Future getProducts() async {
    try {
      var response = await http.get(
        Uri.parse("https://fakestoreapi.com/products"),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        products = jsonDecode(response.body);
        loadMore();
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      print('Error loading products: $e');
      // Show error in UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load products. Please try again.')),
      );
    } finally {
      setState(() {
        isFirstLoading = false;
      });
    }
  }

  void loadMore() {
    if (isLoading) return;

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
    page = 0;
    visibleProducts.clear();

    var filtered = products
        .where((item) =>
            item["title"].toLowerCase().contains(text.toLowerCase()))
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
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Loading products...'),
            ],
          ),
        ),
      );
    }

    if (!hasInternet) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Temporarily comment out Lottie until you add the asset
              // Lottie.asset(
              //   'assets/animations/no_internet.json',
              //   height: 200,
              // ),
              Icon(Icons.wifi_off, size: 100, color: Colors.grey),
              SizedBox(height: 20),
              Text(
                "You are offline",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isFirstLoading = true;
                    hasInternet = true;
                  });
                  checkInternetAndLoad();
                },
                child: Text("Retry"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Mini E-Commerce"),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt),
            onPressed: filterPrice,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search product",
                border: OutlineInputBorder(),
              ),
              onChanged: searchProduct,
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag, size: 100, color: Colors.grey),
                        SizedBox(height: 20),
                        Text('No products found'),
                      ],
                    ),
                  )
                : GridView.builder(
                    controller: scrollController,
                    padding: EdgeInsets.all(8),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: visibleProducts.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == visibleProducts.length) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      var item = visibleProducts[index];

                      return Card(
                        elevation: 3,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: CachedNetworkImage(
                                imageUrl: item["image"] ?? '',
                                fit: BoxFit.contain,
                                fadeInDuration: const Duration(milliseconds: 300),
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                errorWidget: (context, url, error) => const Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(6),
                              child: Text(
                                item["title"] ?? 'No title',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                "₹ ${item["price"]?.toString() ?? '0'}",
                                style: TextStyle(
                                    color: Colors.green),
                              ),
                            ),
                            Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                  "⭐ ${item["rating"]?["rate"]?.toString() ?? '0'}"),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: Icon(
                                  favoriteIds.contains(
                                          item["id"])
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    toggleFavorite(item["id"]),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}