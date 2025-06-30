import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductDetailsPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const ProductDetailsPage({
    required this.productId,
    required this.productData,
  });

  @override
  _ProductDetailsPageState createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  String? selectedVariant;
  double currentPrice = 0.0, oldPrice = 0.0;
  int _currentImageIndex = 0;
  int quantity = 1;
  int stock = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    // Initialize price and variant
    final variants = widget.productData['variants'] as Map<String, dynamic>? ?? {};
    if (variants.isNotEmpty) {
      final firstVariantKey = variants.keys.first;
      selectedVariant = firstVariantKey;
      currentPrice = (variants[firstVariantKey]['price'] as num).toDouble();
      stock = variants[firstVariantKey]['stock'] ?? 0;
    } else {
      final price = widget.productData['price'];
      currentPrice = (price is int) ? price.toDouble() : price ?? 0.0;
      stock = widget.productData['stock'] ?? 0;
    }

    final op = widget.productData['oldprice'];
    oldPrice = (op is int) ? op.toDouble() : op ?? 0.0;
  }

  Future<void> addToCart() async {
    try {
      // Get the currently logged-in user
      final user = _auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to add items to the cart.')),
        );
        return;
      }

      // Check stock
      if (quantity > stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not enough stock available.')),
        );
        return;
      }

      // Add to Firestore
      final cartItem = {
        'productId': widget.productId,
        'productName': widget.productData['name'],
        'variant': selectedVariant,
        'price': currentPrice,
        'quantity': quantity,
        'image': widget.productData['images']?[0] ?? '',
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc(widget.productId)
          .set(cartItem);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $quantity to Cart')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to cart: $e')),
      );
    }
  }

  void updatePrice(String variantKey) {
    final variant = widget.productData['variants'][variantKey];
    if (variant != null) {
      final price = variant['price'];
      setState(() {
        currentPrice = (price is int) ? price.toDouble() : price ?? 0.0;
        stock = variant['stock'] ?? 0;
        selectedVariant = variantKey;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.productData['details'] as Map<String, dynamic>? ?? {};
    final variants = widget.productData['variants'] as Map<String, dynamic>? ?? {};
    final images = widget.productData['images'] as List<String>? ?? ['assets/images/silder1.jpg'];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productData['name'] ?? 'Product Details'),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 80),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Slider
                  Center(
                    child: Column(
                      children: [
                        CarouselSlider(
                          items: images.map((imagePath) {
                            return Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 200,
                            );
                          }).toList(),
                          options: CarouselOptions(
                            height: 200,
                            autoPlay: true,
                            viewportFraction: 1.0,
                            onPageChanged: (index, reason) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                          ),
                        ),
                        // Dots Indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: images.asMap().entries.map((entry) {
                            return GestureDetector(
                              onTap: () => setState(() {
                                _currentImageIndex = entry.key;
                              }),
                              child: Container(
                                width: 8.0,
                                height: 8.0,
                                margin: EdgeInsets.symmetric(horizontal: 4.0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImageIndex == entry.key
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Product Name and Price
                  Text(
                    widget.productData['name'] ?? '',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),

                  // Old Price and Current Price
                  Row(
                    children: [
                      if (oldPrice > 0)
                        Text(
                          '₹$oldPrice',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      SizedBox(width: 8),
                      Text(
                        '₹$currentPrice',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Discount
                  Text(
                    'Discount: ${widget.productData['discount'] ?? 'N/A'}%',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                  SizedBox(height: 16),

                  // Variant Selector
                  if (variants.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Variant and Quantity:', style: TextStyle(fontSize: 18)),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: variants.entries.map((entry) {
                            final variantKey = entry.key;
                            return ChoiceChip(
                              label: Text(variantKey),
                              selected: selectedVariant == variantKey,
                              selectedColor: Colors.green.shade100,
                              onSelected: (selected) {
                                if (selected) {
                                  updatePrice(variantKey);
                                }
                              },
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 8),
                      ],
                    ),

                  // Stock Availability
                  if (stock > 0)
                    Text(
                      stock <= 10 ? 'Only $stock Left!' : 'In Stock: $stock',
                      style: TextStyle(
                        color: stock <= 10 ? Colors.red : Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  SizedBox(height: 16),

                  // Quantity Selector
                  Row(
                    children: [
                      Text('Quantity:', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 16),
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: quantity > 1
                            ? () => setState(() {
                          quantity--;
                        })
                            : null,
                      ),
                      Text(
                        '$quantity',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: quantity < stock
                            ? () => setState(() {
                          quantity++;
                        })
                            : null,
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Product Details
                  Text('Product Details:', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  ...details.entries.map((entry) => ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text(entry.key, style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(entry.value),
                  )),
                ],
              ),
            ),
          ),

          // Fixed Bottom Buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: addToCart,
                    icon: Icon(Icons.shopping_cart),
                    label: Text('Add to Cart'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(160, 50),
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Proceeding to Buy $quantity')),
                      );
                    },
                    icon: Icon(Icons.shopping_bag),
                    label: Text('Buy Now'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(160, 50),
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
