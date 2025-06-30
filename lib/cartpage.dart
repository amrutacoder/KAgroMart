import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartPage extends StatefulWidget {
  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double totalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    calculateTotalPrice();
  }

  Future<void> calculateTotalPrice() async {
    final user = _auth.currentUser;
    if (user == null) return;

    double price = 0.0;
    final cartSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .get();

    for (var doc in cartSnapshot.docs) {
      final data = doc.data();
      final itemPrice = (data['price'] ?? 0) as num;
      final itemQuantity = (data['quantity'] ?? 1) as num;
      price += itemPrice * itemQuantity;
    }

    setState(() {
      totalPrice = price;
    });
  }

  Future<void> updateQuantity(String productId, int newQuantity) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final cartDoc = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .doc(productId);

    if (newQuantity <= 0) {
      await cartDoc.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item removed from cart.')),
      );
    } else {
      await cartDoc.update({'quantity': newQuantity});
    }

    calculateTotalPrice();
  }

  Future<void> placeOrder() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final cartSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .get();

    if (cartSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cart is empty.')),
      );
      return;
    }

    final orderData = {
      'orderItems': cartSnapshot.docs.map((doc) => doc.data()).toList(),
      'totalPrice': totalPrice,
      'orderDate': DateTime.now(),
      'expectedDelivery': DateTime.now().add(Duration(days: 7)),
      'status': 'Pending',
    };

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .add(orderData);

    // Clear the cart
    for (var doc in cartSnapshot.docs) {
      await doc.reference.delete();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order placed successfully!')),
    );

    setState(() {
      totalPrice = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Your Cart'),
          backgroundColor: Colors.green,
        ),
        body: Center(
          child: Text(
            'Please log in to view your cart.',
            style: TextStyle(fontSize: 16, color: Colors.green),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Your Cart'),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Your cart is empty.',
                style: TextStyle(fontSize: 16, color: Colors.green),
              ),
            );
          }

          final cartItems = snapshot.data!.docs;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final cartItem = cartItems[index].data() as Map<String, dynamic>;
                    final productId = cartItems[index].id;

                    return Card(
                      elevation: 5,
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Product Image
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[300],
                                image: cartItem['image'] != null &&
                                    (cartItem['image'] as String).isNotEmpty
                                    ? DecorationImage(
                                  image: NetworkImage(cartItem['image']),
                                  fit: BoxFit.cover,
                                )
                                    : null,
                              ),
                              child: cartItem['image'] == null ||
                                  (cartItem['image'] as String).isEmpty
                                  ? Icon(Icons.agriculture, size: 40, color: Colors.green)
                                  : null,
                            ),
                            SizedBox(width: 12),
                            // Product Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cartItem['productName'] ?? productId,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Variant: ${cartItem['variant'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14, color: Colors.green),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Price: ₹${cartItem['price'] ?? 0}',
                                    style: TextStyle(fontSize: 14, color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                            // Quantity Selector
                            Column(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.add_circle, color: Colors.green),
                                  onPressed: () {
                                    final currentQuantity =
                                    (cartItem['quantity'] ?? 1) as int;
                                    updateQuantity(productId, currentQuantity + 1);
                                  },
                                ),
                                Text(
                                  '${cartItem['quantity'] ?? 1}',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () {
                                    final currentQuantity =
                                    (cartItem['quantity'] ?? 1) as int;
                                    updateQuantity(productId, currentQuantity - 1);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Sticky Footer
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green, Colors.green],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Total Price: ₹$totalPrice',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: placeOrder,
                      child: Text('Place Order'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12), backgroundColor: Colors.white,
                        textStyle: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
