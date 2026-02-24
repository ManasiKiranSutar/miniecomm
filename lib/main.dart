import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';

void main() {
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
  bool isFirstLoading = true;
  bool hasInternet = true;

  @override
  void initState() {
    super.initState();
    checkInternetAndLoad();
    loadFavorites();

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200) {
        loadMore();
      }
    });
  }

  Future<void> checkInternetAndLoad() async {
    var connectivityResult =
        await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      setState(() {
        hasInternet = false;
        isFirstLoading = false;
      });
      return;
    }

    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty &&
          result[0].rawAddress.isNotEmpty) {
        hasInternet = true;
        await getProducts();
      }
    } catch (_) {
      setState(() {
        hasInternet = false;
        isFirstLoading = false;
      });
    }
  }

  Future getProducts() async {
    var response =
        await http.get(Uri.parse("https://fakestoreapi.com/products"));

    if (response.statusCode == 200) {
      products = jsonDecode(response.body);
      loadMore();
    }

    setState(() {
      isFirstLoading = false;
    });
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
    setState(() {});
  }

  void searchProduct(String text) {
    page = 0;
    visibleProducts.clear();

    var filtered = products
        .where((item) =>
            item["title"].toLowerCase().contains(text.toLowerCase()))
        .toList();

    visibleProducts = filtered.take(perPage).toList();

    setState(() {});
  }

  void filterPrice() {
    page = 0;
    visibleProducts.clear();

    var filtered =
        products.where((item) => item["price"] <= 100).toList();

    visibleProducts = filtered.take(perPage).toList();

    setState(() {});
  }

  void toggleFavorite(int id) async {
    if (favoriteIds.contains(id)) {
      favoriteIds.remove(id);
    } else {
      favoriteIds.add(id);
    }

    SharedPreferences prefs =
        await SharedPreferences.getInstance();

    prefs.setStringList(
      "fav",
      favoriteIds.map((e) => e.toString()).toList(),
    );

    setState(() {});
  }

  Future loadFavorites() async {
    SharedPreferences prefs =
        await SharedPreferences.getInstance();

    List<String>? saved = prefs.getStringList("fav");

    if (saved != null) {
      favoriteIds = saved.map((e) => int.parse(e)).toList();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isFirstLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!hasInternet) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/no_internet.json',
                height: 200,
              ),
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
            child: GridView.builder(
              controller: scrollController,
              padding: EdgeInsets.all(8),
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.7,
              ),
              itemCount: visibleProducts.length + 1,
              itemBuilder: (context, index) {
                if (index == visibleProducts.length) {
                  return isLoading
                      ? Center(
                          child: CircularProgressIndicator(),
                        )
                      : SizedBox();
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
                          imageUrl: item["image"],
                          fit: BoxFit.contain,
                          placeholder: (context, url) =>
                              Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              Icon(Icons.error),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(6),
                        child: Text(
                          item["title"],
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
                          "₹ ${item["price"]}",
                          style: TextStyle(
                              color: Colors.green),
                        ),
                      ),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                            "⭐ ${item["rating"]["rate"]}"),
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