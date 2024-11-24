import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_commerce/widget/custom_appbar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:flutter_bkash/flutter_bkash.dart';

import '../../main.dart';
import '../../utils/colors.dart';
import 'success_payment.dart';

enum Intent { sale, authorization }

class PaymentGetewayScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cardData;
  final double totalAmount;

  PaymentGetewayScreen({required this.cardData, required this.totalAmount});

  @override
  State<PaymentGetewayScreen> createState() => _PaymentGetewayScreenState();
}

class _PaymentGetewayScreenState extends State<PaymentGetewayScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Intent _intent = Intent.sale;
  FocusNode? focusNode;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
  }

  @override
  void dispose() {
    focusNode!.dispose();
    super.dispose();
  }

  Future<void> paymentCheckout(double amount) async {
    final flutterBkash = FlutterBkash();

    try {
      final result = await flutterBkash.pay(
        context: context,
        amount: amount,
        merchantInvoiceNumber: "tranId",
      );

      dev.log(result.toString());
      _showSnackBar("(Success) tranId: ${result.trxId}");
    } on BkashFailure catch (e, st) {
      dev.log(e.message, error: e, stackTrace: st);
      _showSnackBar(e.message, isError: true);
    } catch (e, st) {
      dev.log("Something went wrong", error: e, stackTrace: st);
      _showSnackBar("Something went wrong", isError: true);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _processPayment(String intent) async {
    setState(() {
      isLoading = true;
    });

    await paymentCheckout(widget.totalAmount);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    showTopSnackBar(
      Overlay.of(context),
      isError
          ? CustomSnackBar.error(message: message)
          : CustomSnackBar.success(message: message),
    );
  }

  Widget _buildPaymentOptionCard(
      String title, String amount, VoidCallback onTap) {
    final color =
        themeManager.themeMode == ThemeMode.light ? Colors.black : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Card(
        color: themeManager.themeMode == ThemeMode.light
            ? AppColor.fieldBackgroundColor
            : Colors.grey[900],
        child: ListTile(
          title: Text(
            title,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18.sp, color: color),
          ),
          trailing: Text(
            "৳$amount",
            style: TextStyle(fontSize: 16.sp, color: color),
          ),
        ),
      ),
    );
  }

  Future<void> _handleBkashPayment() async {
    String intent = _intent == Intent.sale ? "sale" : "authorization";

    if (widget.totalAmount.toString().isEmpty) {
      _showSnackBar(
          "Amount is empty. Without amount, you can't pay. Try again.",
          isError: true);
      return;
    }

    focusNode!.unfocus();
    await _processPayment(intent);
  }

  Future<void> _handleCODPayment() async {
    final data = FirebaseFirestore.instance
        .collection("orders")
        .doc(user!.email)
        .collection("order")
        .doc();

    await data.set({
      'id': data.id.toString(),
      'email': user!.email,
      'item': widget.cardData,
      'amount': widget.totalAmount,
      'gtName': 'COD',
      'delivery': false
    }).then((value) async {
      final cart = await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.email)
          .collection('cart')
          .get();

      for (var item in cart.docs) {
        await item.reference.delete();
      }
    });

    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const SuccessPaymentScreen()));
    _showSnackBar("Payment Successfully Done");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeManager.themeMode == ThemeMode.light
          ? Colors.white
          : Colors.black,
      appBar: customAppBar(
          context: context,
          title: 'Payment Method',
          backgroundColor: themeManager.themeMode == ThemeMode.light
              ? Colors.white
              : Colors.black),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildPaymentOptionCard("bKash",
                      widget.totalAmount.toString(), _handleBkashPayment),
                  _buildPaymentOptionCard("Cash on Delivery",
                      widget.totalAmount.toString(), _handleCODPayment),
                ],
              ),
            ),
    );
  }
}
