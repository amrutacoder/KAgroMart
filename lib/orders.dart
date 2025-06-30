import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserOrdersPage extends StatefulWidget {
  @override
  _UserOrdersPageState createState() => _UserOrdersPageState();
}

class _UserOrdersPageState extends State<UserOrdersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Your Orders'),
          backgroundColor: Colors.green,
        ),
        body: Center(
          child: Text(
            'Please log in to view your orders.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Your Orders'),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(user.uid)
            .collection('orders')
            .orderBy('orderDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'You have no orders yet.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index].data() as Map<String, dynamic>;
              final orderId = orders[index].id;

              // Format dates
              final orderDate = (order['orderDate'] as Timestamp).toDate();
              final expectedDelivery = (order['expectedDelivery'] as Timestamp).toDate();
              final formattedOrderDate = DateFormat('yyyy-MM-dd').format(orderDate);
              final formattedDeliveryDate = DateFormat('yyyy-MM-dd').format(expectedDelivery);
              final totalPrice = order['totalPrice'] ?? 0.0;

              return Card(
                margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${orderId}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Order Date: $formattedOrderDate',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Expected Delivery: $formattedDeliveryDate',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Total Price: ₹$totalPrice',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Divider(thickness: 1, color: Colors.grey[300]),
                      FutureBuilder<List<Widget>>(
                        future: _fetchOrderItems(order['orderItems'] as List),
                        builder: (context, itemSnapshot) {
                          if (itemSnapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          if (itemSnapshot.hasError) {
                            return Text(
                              'Error loading items.',
                              style: TextStyle(color: Colors.red),
                            );
                          }
                          return Column(children: itemSnapshot.data ?? []);
                        },
                      ),
                      SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            deleteOrder(orderId);
                          },
                          icon: Icon(Icons.delete, color: Colors.white),
                          label: Text('Cancel Order'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Widget>> _fetchOrderItems(List<dynamic> orderItems) async {
    final List<Widget> itemWidgets = [];

    for (var item in orderItems) {
      final productId = item['productId'] ?? '';
      final quantity = item['quantity'] ?? 0;
      final price = item['price'] ?? 0.0;
      final variant = item['variant'] ?? 'N/A';

      String productName = 'sunflower';
      try {
        if (productId.isNotEmpty) {
          final productDoc = await _firestore.collection('products').doc(productId).get();
          if (productDoc.exists) {
            productName = productDoc.data()?['productId'] ?? 'sunflower';
          }
        }
      } catch (e) {
        print('Error fetching product name for $productId: $e');
      }

      itemWidgets.add(
        ListTile(
          contentPadding: EdgeInsets.symmetric(vertical: 4.0),
          title: Text(
            '$productName ($variant)',
            style: TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'Quantity: $quantity | ₹$price',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          leading: Icon(
            Icons.shopping_cart,
            color: Colors.green,
            size: 30,
          ),
        ),
      );
    }

    return itemWidgets;
  }

  Future<void> deleteOrder(String orderId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Delete the order
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .doc(orderId)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order has been deleted.')),
    );
  }
}
