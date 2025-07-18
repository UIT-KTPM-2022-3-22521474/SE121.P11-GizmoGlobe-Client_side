import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/database/database.dart';
import 'package:gizmoglobe_client/objects/product_related/cpu.dart';
import 'package:gizmoglobe_client/objects/product_related/drive.dart';
import 'package:gizmoglobe_client/objects/product_related/gpu.dart';
import 'package:gizmoglobe_client/objects/product_related/mainboard.dart';
import 'package:gizmoglobe_client/objects/product_related/psu.dart';
import 'package:gizmoglobe_client/objects/product_related/ram.dart';

import '../../enums/invoice_related/sales_status.dart';
import '../../enums/manufacturer/manufacturer_status.dart';
import '../../enums/product_related/category_enum.dart';
import '../../enums/product_related/cpu_enums/cpu_family.dart';
import '../../enums/product_related/drive_enums/drive_capacity.dart';
import '../../enums/product_related/drive_enums/drive_type.dart';
import '../../enums/product_related/gpu_enums/gpu_bus.dart';
import '../../enums/product_related/gpu_enums/gpu_capacity.dart';
import '../../enums/product_related/gpu_enums/gpu_series.dart';
import '../../enums/product_related/mainboard_enums/mainboard_compatibility.dart';
import '../../enums/product_related/mainboard_enums/mainboard_form_factor.dart';
import '../../enums/product_related/mainboard_enums/mainboard_series.dart';
import '../../enums/product_related/product_status_enum.dart';
import '../../enums/product_related/psu_enums/psu_efficiency.dart';
import '../../enums/product_related/psu_enums/psu_modular.dart';
import '../../enums/product_related/ram_enums/ram_bus.dart';
import '../../enums/product_related/ram_enums/ram_capacity_enum.dart';
import '../../enums/product_related/ram_enums/ram_type.dart';
import '../../objects/address_related/address.dart';
import '../../objects/invoice_related/sales_invoice.dart';
import '../../objects/invoice_related/sales_invoice_detail.dart';
import '../../objects/manufacturer.dart';
import '../../objects/product_related/product.dart';
import '../../objects/product_related/product_factory.dart';
import '../../objects/voucher_related/owned_voucher.dart';
import '../../objects/voucher_related/voucher.dart';
import '../../objects/voucher_related/voucher_factory.dart';

Future<void> pushProductSamplesToFirebase() async {
  try {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Database().generateSampleData();
    for (var manufacturer in Database().manufacturerList) {
      await firestore
          .collection('manufacturers')
          .doc(manufacturer.manufacturerID)
          .set({
        'manufacturerID': manufacturer.manufacturerID,
        'manufacturerName': manufacturer.manufacturerName,
      });
    }

    // Push products to Firestore
    for (var product in Database().productList) {
      Map<String, dynamic> productData = {
        'productName': product.productName,
        'price': product.price,
        'manufacturerID': product.manufacturer.manufacturerID,
        'category': product.category.getName(),
      };

      // Thêm các thuộc tính đặc thù cho từng loại sản phẩm
      switch (product.runtimeType) {
        case const (RAM):
          final ram = product as RAM;
          productData.addAll({
            'bus': ram.bus.getName(),
            'capacity': ram.capacity.getName(),
            'ramType': ram.ramType.getName(),
          });
          break;

        case const (CPU):
          final cpu = product as CPU;
          productData.addAll({
            'family': cpu.family.getName(),
            'core': cpu.core,
            'thread': cpu.thread,
            'clockSpeed': cpu.clockSpeed,
          });
          break;

        case const (GPU):
          final gpu = product as GPU;
          productData.addAll({
            'series': gpu.series.getName(),
            'capacity': gpu.capacity.getName(),
            'busWidth': gpu.bus.getName(),
            'clockSpeed': gpu.clockSpeed,
          });
          break;

        case const (Mainboard):
          final mainboard = product as Mainboard;
          productData.addAll({
            'formFactor': mainboard.formFactor.getName(),
            'series': mainboard.series.getName(),
            'compatibility': mainboard.compatibility.getName(),
          });
          break;

        case const (Drive):
          final drive = product as Drive;
          productData.addAll({
            'type': drive.type.getName(),
            'capacity': drive.capacity.getName(),
          });
          break;

        case const (PSU):
          final psu = product as PSU;
          productData.addAll({
            'wattage': psu.wattage,
            'efficiency': psu.efficiency.getName(),
            'modular': psu.modular.getName(),
          });
          break;
      }

      // Thêm sản phẩm vào Firestore với tất cả thuộc tính
      await firestore.collection('products').add(productData);
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error pushing product samples to Firebase: $e');
    }
  }
}

class Firebase {
  static final Firebase _firebase = Firebase._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Thêm các constant cho retry
  static const int maxRetries = 3;
  static const int retryDelayMs = 1000;

  // Hàm helper để retry operation
  Future<T> _retryOperation<T>(Future<T> Function() operation) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts == maxRetries) {
          if (kDebugMode) {
            print('Final attempt failed: $e');
          }
          rethrow;
        }
        if (kDebugMode) {
          print('Attempt $attempts failed, retrying in ${retryDelayMs}ms...');
        }
        await Future.delayed(Duration(milliseconds: retryDelayMs * attempts));
      }
    }
    throw Exception('Retry operation failed after $maxRetries attempts');
  }

  factory Firebase() {
    return _firebase;
  }

  Firebase._internal();

  // Thêm getter để truy cập Firestore instance
  FirebaseFirestore get firestore => _firestore;

  // Thêm sản phẩm vào giỏ hàng
  Future<void> addToCart(
      String customerID, String productID, int quantity) async {
    await _retryOperation(() async {
      try {
        if (kDebugMode) {
          print(
              'Adding to cart - UserID: $customerID, ProductID: $productID, Quantity: $quantity');
        }
        // Check if user document exists
        final userDoc =
            await _firestore.collection('customers').doc(customerID).get();
        if (!userDoc.exists) {
          await _firestore.collection('customers').doc(customerID).set({
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // Get product information
        final productDoc =
            await _firestore.collection('products').doc(productID).get();
        if (!productDoc.exists) {
          if (kDebugMode) {
            print('Product not found: $productID');
          }
          throw Exception('Product not found');
        }

        final productData = productDoc.data()!;
        final price = (productData['sellingPrice'] as num).toDouble();
        final discount = (productData['discount'] as num?)?.toDouble() ?? 0.0;
        final discountedPrice = price * (1 - discount / 100);

        // Reference to cart item
        final cartRef = _firestore
            .collection('customers')
            .doc(customerID)
            .collection('carts')
            .doc(productID);

        // Check if item exists in cart
        final cartDoc = await cartRef.get();
        if (kDebugMode) {
          print('Cart document exists: ${cartDoc.exists}');
        }

        if (!cartDoc.exists) {
          final subtotal = (discountedPrice * quantity).toStringAsFixed(2);
          if (kDebugMode) {
            print('Creating new cart item with subtotal: $subtotal');
          }

          await cartRef.set({
            'quantity': quantity,
            'subtotal': double.parse(subtotal),
            'productID': productID, // Add reference to product
            'addedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final currentQuantity =
              (cartDoc.data()?['quantity'] as num?)?.toInt() ?? 0;
          final newQuantity = currentQuantity + quantity;
          final subtotal = (discountedPrice * newQuantity).toStringAsFixed(2);

          if (kDebugMode) {
            print('Updating existing cart item:');
            print('Current quantity: $currentQuantity');
            print('New quantity: $newQuantity');
            print('New subtotal: $subtotal');
          }

          await cartRef.update({
            'quantity': newQuantity,
            'subtotal': double.parse(subtotal),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Verify the operation
        final verifyDoc = await cartRef.get();
        if (kDebugMode) {
          print('Verification - Cart item data:');
        }
        if (kDebugMode) {
          print(verifyDoc.data());
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error in addToCart operation: $e');
        }
        rethrow;
      }
    });
  }

  // Cập nhật số lượng sản phẩm trong giỏ hàng
  Future<void> updateCartItemQuantity(
      String customerID, String productID, int newQuantity) async {
    await _retryOperation(() async {
      try {
        if (kDebugMode) {
          print(
              'Updating quantity - UserID: $customerID, ProductID: $productID, New Quantity: $newQuantity');
        }
        if (newQuantity <= 0) {
          await removeFromCart(customerID, productID);
          return;
        }

        final productDoc =
            await _firestore.collection('products').doc(productID).get();
        if (!productDoc.exists) {
          if (kDebugMode) {
            print('Product not found: $productID');
          }
          throw Exception('Product not found');
        }

        final productData = productDoc.data()!;
        final price = (productData['sellingPrice'] as num).toDouble();
        final discount = (productData['discount'] as num?)?.toDouble() ?? 0.0;
        final discountedPrice = price * (1 - discount / 100);
        final subtotal = (discountedPrice * newQuantity).toStringAsFixed(2);

        final cartRef = _firestore
            .collection('customers')
            .doc(customerID)
            .collection('carts')
            .doc(productID);

        if (kDebugMode) {
          print('Updating cart with:');
          print('New quantity: $newQuantity');
          print('New subtotal: $subtotal');
        }
        // Update the cart item
        await cartRef.update({
          'quantity': newQuantity,
          'subtotal': double.parse(subtotal),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Verify the update
        final verifyDoc = await cartRef.get();
        if (kDebugMode) {
          print('Verification - Updated cart item:');
        }
        if (kDebugMode) {
          print(verifyDoc.data());
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error in updateCartItemQuantity: $e');
        }
        rethrow;
      }
    });
  }

  // Xóa sản phẩm khỏi giỏ hàng
  Future<void> removeFromCart(String customerID, String productID) async {
    try {
      await _firestore
          .collection('customers')
          .doc(customerID)
          .collection('carts')
          .doc(productID)
          .delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error removing from cart: $e');
      }
      rethrow;
    }
  }

  // Lấy tất cả sản phẩm trong giỏ hàng của user
  Future<List<Map<String, dynamic>>> getCartItems(String customerID) async {
    return await _retryOperation(() async {
      try {
        final cartSnapshot = await _firestore
            .collection('customers')
            .doc(customerID)
            .collection('carts')
            .get();

        final List<Map<String, dynamic>> items = [];

        // First, get all inactive manufacturer IDs to filter against
        final manufacturerSnapshot = await FirebaseFirestore.instance
            .collection('manufacturers')
            .where('status', isEqualTo: 'inactive')
            .get();

        final List<String> inactiveManufacturerIDs =
            manufacturerSnapshot.docs.map((doc) => doc.id).toList();

        if (kDebugMode && inactiveManufacturerIDs.isNotEmpty) {
          print('Found ${inactiveManufacturerIDs.length} inactive manufacturers to filter from cart');
        }

        for (var doc in cartSnapshot.docs) {
          final productID = doc.id;
          final cartData = doc.data();

          // Lấy thông tin sản phẩm
          final productDoc =
              await _firestore.collection('products').doc(productID).get();

          if (productDoc.exists) {
            final productData = productDoc.data()!;

            // Check if the product's manufacturer is inactive
            final manufacturerID = productData['manufacturerID'] as String;
            if (inactiveManufacturerIDs.contains(manufacturerID)) {
              if (kDebugMode) {
                print('Skipping cart item for product ${productID} from inactive manufacturer ${manufacturerID}');
              }
              continue; // Skip this cart item
            }

            final quantity = cartData['quantity'] as int;

            // Tính lại subtotal
            final price = (productData['sellingPrice'] as num).toDouble();
            final discount =
                (productData['discount'] as num?)?.toDouble() ?? 0.0;
            final discountedPrice = price * (1 - discount / 100);
            final subtotal = discountedPrice * quantity;

            items.add({
              'productID': productID,
              'quantity': quantity,
              'subtotal': subtotal,
              'product': productData,
            });
          }
        }

        return items;
      } catch (e) {
        if (kDebugMode) {
          print('Error in getCartItems operation: $e');
        }
        rethrow;
      }
    });
  }

  // Xóa toàn bộ giỏ hàng của user
  Future<void> clearCart(String customerID) async {
    try {
      final cartRef = _firestore
          .collection('customers')
          .doc(customerID)
          .collection('carts');

      final cartDocs = await cartRef.get();

      for (var doc in cartDocs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing cart: $e');
      }
      rethrow;
    }
  }

  Future<void> createAddress(Address address) async {
    try {
      // Add address to collection addresses
      DocumentReference addressRef = await FirebaseFirestore.instance
          .collection('addresses')
          .add(address.toMap());

      String addressId = addressRef.id;
      address.addressID = addressId;

      await addressRef.update({'addressID': addressId});
      await FirebaseFirestore.instance
          .collection('addresses')
          .doc(addressId)
          .set({
        'addressID': addressId,
        'customerID': address.customerID,
        'receiverName': address.receiverName,
        'receiverPhone': address.receiverPhone,
        'provinceCode': address.province?.code,
        'districtCode': address.district?.code,
        'wardCode': address.ward?.code,
        'street': address.street ?? '',
        'hidden': false,
      });

      await Database().fetchAddress();
    } catch (e) {
      if (kDebugMode) {
        print('Error creating new address: $e');
      }
      rethrow;
    }
  }

  Future<void> updateAddress(Address address) async {
    try {
      await FirebaseFirestore.instance
          .collection('addresses')
          .doc(address.addressID)
          .update(address.toMap());

      await Database().fetchAddress();
    } catch (e) {
      if (kDebugMode) {
        print('Error updating address: $e');
      }
      rethrow;
    }
  }

  Future<void> addFavorite(String customerID, String productID) async {
    try {
      final favoriteRef = _firestore
          .collection('customers')
          .doc(customerID)
          .collection('favorites')
          .doc(productID);

      await favoriteRef.set({
        'productID': productID,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error adding favorite: $e');
      }
      rethrow;
    }
  }

  Future<void> removeFavorite(String customerID, String productID) async {
    try {
      final favoriteRef = _firestore
          .collection('customers')
          .doc(customerID)
          .collection('favorites')
          .doc(productID);

      await favoriteRef.delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error removing favorite: $e');
      }
      rethrow;
    }
  }

  Future<List<String>> getFavorites(String customerID) async {
    try {
      final favoriteSnapshot = await _firestore
          .collection('customers')
          .doc(customerID)
          .collection('favorites')
          .get();

      return favoriteSnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting favorites: $e');
      }
      rethrow;
    }
  }

  Future<Manufacturer?> getManufacturerById(String manufacturerId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('manufacturers')
          .where('manufacturerID', isEqualTo: manufacturerId)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      final data = querySnapshot.docs.first.data();
      final docStatus = data['status'] as String?;
      return Manufacturer(
        manufacturerID: data['manufacturerID'] ?? '',
        manufacturerName: data['manufacturerName'] ?? '',
        status: ManufacturerStatus.values.firstWhere(
          (e) => e.getName().toLowerCase() == (docStatus?.toLowerCase() ?? ManufacturerStatus.active.getName().toLowerCase()),
          orElse: () => ManufacturerStatus.active,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error finding manufacturer by ID: $e');
      }
      rethrow;
    }
  }

  Future<List<Product>> getProducts() async {
    try {
      // First, get all manufacturers to identify inactive ones
      final manufacturerSnapshot = await FirebaseFirestore.instance
          .collection('manufacturers')
          .where('status', isEqualTo: 'inactive')
          .get();

      final List<Map<String, dynamic>> inactiveManufacturers =
          manufacturerSnapshot.docs.map((doc) => {
                'id': doc.id,
                'status': doc['status'] ?? 'inactive'
              }).toList();

      final List<String> inactiveManufacturerIDs =
          inactiveManufacturers.map((m) => m['id'] as String).toList();

      if (kDebugMode && inactiveManufacturerIDs.isNotEmpty) {
        print('Found ${inactiveManufacturerIDs.length} inactive manufacturers to exclude');
      }

      // Get all products
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('products').get();

      List<Product> products = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Lấy manufacturer từ manufacturerID
        String manufacturerId = data['manufacturerID'];

        // Skip products from inactive manufacturers
        if (inactiveManufacturerIDs.contains(manufacturerId)) {
          if (kDebugMode) {
            print('Skipping product ${doc.id} from inactive manufacturer $manufacturerId');
          }
          continue;
        }

        Manufacturer? manufacturer = await getManufacturerById(manufacturerId);
        if (manufacturer == null) {
          if (kDebugMode) {
            print('Manufacturer not found for product ${doc.id}');
          }
          continue;
        }

        // Get product status first to check if it's active
        ProductStatusEnum productStatus = ProductStatusEnum.values.firstWhere(
          (e) => e.getName() == data['status'],
          orElse: () => ProductStatusEnum.active,
        );

        // Skip products that are not active
        if (productStatus != ProductStatusEnum.active) {
          if (kDebugMode) {
            print('Skipping product ${doc.id} with non-active status: ${productStatus.getName()}');
          }
          continue;
        }

        // Chuyển đổi category string thành enum
        CategoryEnum category = CategoryEnum.values.firstWhere(
          (e) => e.getName() == data['category'],
          orElse: () => CategoryEnum.ram,
        );

        // Tạo product với các thuộc tính cơ bản
        Map<String, dynamic> productProps = {
          'productID': doc.id,
          'productName': data['productName'],
          'manufacturer': manufacturer,
          'importPrice': (data['importPrice'] as num).toDouble(),
          'sellingPrice': (data['sellingPrice'] as num).toDouble(),
          'discount': (data['discount'] as num).toDouble(),
          'release': (data['release'] as Timestamp).toDate(),
          'sales': data['sales'] as int,
          'stock': data['stock'] as int,
          'enDescription': data['enDescription'] as String?,
          'viDescription': data['viDescription'] as String?,
          'imageUrl': data['imageUrl'] as String?,
          'status': productStatus,
        };

        // Thêm các thuộc tính đặc thù theo category
        switch (category) {
          case CategoryEnum.ram:
            productProps.addAll({
              'bus': RAMBus.values.firstWhere(
                (e) => e.getName() == data['bus'],
                orElse: () => RAMBus.mhz3200,
              ),
              'capacity': RAMCapacity.values.firstWhere(
                (e) => e.getName() == data['capacity'],
                orElse: () => RAMCapacity.gb8,
              ),
              'ramType': RAMType.values.firstWhere(
                (e) => e.getName() == data['ramType'],
                orElse: () => RAMType.ddr4,
              ),
            });
            break;
          case CategoryEnum.cpu:
            productProps.addAll({
              'family': CPUFamily.values.firstWhere(
                (e) => e.getName() == data['family'],
                orElse: () => CPUFamily.corei3Ultra3,
              ),
              'core': data['core'] as int,
              'thread': data['thread'] as int,
              'clockSpeed': (data['clockSpeed'] as num).toDouble(),
            });
            break;
          case CategoryEnum.gpu:
            productProps.addAll({
              'series': GPUSeries.values.firstWhere(
                (e) => e.getName() == data['series'],
                orElse: () => GPUSeries.rtx,
              ),
              'capacity': GPUCapacity.values.firstWhere(
                (e) => e.getName() == data['capacity'],
                orElse: () => GPUCapacity.gb8,
              ),
              'busWidth': GPUBus.values.firstWhere(
                (e) => e.getName() == data['busWidth'],
                orElse: () => GPUBus.bit128,
              ),
              'clockSpeed': (data['clockSpeed'] as num).toDouble(),
            });
            break;
          case CategoryEnum.mainboard:
            productProps.addAll({
              'formFactor': MainboardFormFactor.values.firstWhere(
                (e) => e.getName() == data['formFactor'],
                orElse: () => MainboardFormFactor.atx,
              ),
              'series': MainboardSeries.values.firstWhere(
                (e) => e.getName() == data['series'],
                orElse: () => MainboardSeries.h,
              ),
              'compatibility': MainboardCompatibility.values.firstWhere(
                (e) => e.getName() == data['compatibility'],
                orElse: () => MainboardCompatibility.intel,
              ),
            });
            break;
          case CategoryEnum.drive:
            productProps.addAll({
              'type': DriveType.values.firstWhere(
                (e) => e.getName() == data['type'],
                orElse: () => DriveType.sataSSD,
              ),
              'capacity': DriveCapacity.values.firstWhere(
                (e) => e.getName() == data['capacity'],
                orElse: () => DriveCapacity.gb256,
              ),
            });
            break;
          case CategoryEnum.psu:
            productProps.addAll({
              'wattage': data['wattage'] as int,
              'efficiency': PSUEfficiency.values.firstWhere(
                (e) => e.getName() == data['efficiency'],
                orElse: () => PSUEfficiency.gold,
              ),
              'modular': PSUModular.values.firstWhere(
                (e) => e.getName() == data['modular'],
                orElse: () => PSUModular.fullModular,
              ),
            });
            break;
        }

        // Tạo product instance thông qua factory
        Product product = ProductFactory.createProduct(category, productProps);
        products.add(product);
      }

      if (kDebugMode) {
        print('Retrieved ${products.length} active products after filtering');
      }

      return products;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting products: $e');
      }
      rethrow;
    }
  }

  Future<void> changeProductStatus(
      String productId, ProductStatusEnum status) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({'status': status.getName()});

      List<Product> products = await getProducts();
      Database().updateProductList(products);
    } catch (e) {
      if (kDebugMode) {
        print('Error changing product status: $e');
      }
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      Map<String, dynamic> productData = {
        'productName': product.productName,
        'sellingPrice': product.price,
        'discount': product.discount,
        'release': product.release,
        'sales': product.sales,
        'stock': product.stock,
        'status': product.status.getName(),
        'manufacturerID': product.manufacturer.manufacturerID,
        'category': product.category.getName(),
        'enDescription': product.enDescription,
        'viDescription': product.viDescription,
        'imageUrl': product.imageUrl,
      };

      switch (product.runtimeType) {
        case const (RAM):
          final ram = product as RAM;
          productData.addAll({
            'bus': ram.bus.getName(),
            'capacity': ram.capacity.getName(),
            'ramType': ram.ramType.getName(),
          });
          break;

        case const (CPU):
          final cpu = product as CPU;
          productData.addAll({
            'family': cpu.family.getName(),
            'core': cpu.core,
            'thread': cpu.thread,
            'clockSpeed': cpu.clockSpeed,
          });
          break;

        case const (GPU):
          final gpu = product as GPU;
          productData.addAll({
            'series': gpu.series.getName(),
            'capacity': gpu.capacity.getName(),
            'busWidth': gpu.bus.getName(),
            'clockSpeed': gpu.clockSpeed,
          });
          break;

        case const (Mainboard):
          final mainboard = product as Mainboard;
          productData.addAll({
            'formFactor': mainboard.formFactor.getName(),
            'series': mainboard.series.getName(),
            'compatibility': mainboard.compatibility.getName(),
          });
          break;

        case const (Drive):
          final drive = product as Drive;
          productData.addAll({
            'type': drive.type.getName(),
            'capacity': drive.capacity.getName(),
          });
          break;

        case const (PSU):
          final psu = product as PSU;
          productData.addAll({
            'wattage': psu.wattage,
            'efficiency': psu.efficiency.getName(),
            'modular': psu.modular.getName(),
          });
          break;
      }

      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.productID)
          .update(productData);

      List<Product> products = await getProducts();
      Database().updateProductList(products);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating product: $e');
      }
      rethrow;
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      Map<String, dynamic> productData = {
        'productName': product.productName,
        'sellingPrice': product.price,
        'discount': product.discount,
        'release': product.release,
        'sales': product.sales,
        'stock': product.stock,
        'status': product.status.getName(),
        'manufacturerID': product.manufacturer.manufacturerID,
        'category': product.category.getName(),
        'enDescription': product.enDescription,
        'viDescription': product.viDescription,
        'imageUrl': product.imageUrl,
      };

      switch (product.runtimeType) {
        case const (RAM):
          final ram = product as RAM;
          productData.addAll({
            'bus': ram.bus.getName(),
            'capacity': ram.capacity.getName(),
            'ramType': ram.ramType.getName(),
          });
          break;

        case const (CPU):
          final cpu = product as CPU;
          productData.addAll({
            'family': cpu.family.getName(),
            'core': cpu.core,
            'thread': cpu.thread,
            'clockSpeed': cpu.clockSpeed,
          });
          break;

        case const (GPU):
          final gpu = product as GPU;
          productData.addAll({
            'series': gpu.series.getName(),
            'capacity': gpu.capacity.getName(),
            'busWidth': gpu.bus.getName(),
            'clockSpeed': gpu.clockSpeed,
          });
          break;

        case const (Mainboard):
          final mainboard = product as Mainboard;
          productData.addAll({
            'formFactor': mainboard.formFactor.getName(),
            'series': mainboard.series.getName(),
            'compatibility': mainboard.compatibility.getName(),
          });
          break;

        case const (Drive):
          final drive = product as Drive;
          productData.addAll({
            'type': drive.type.getName(),
            'capacity': drive.capacity.getName(),
          });
          break;

        case const (PSU):
          final psu = product as PSU;
          productData.addAll({
            'wattage': psu.wattage,
            'efficiency': psu.efficiency.getName(),
            'modular': psu.modular.getName(),
          });
          break;
      }

      await FirebaseFirestore.instance.collection('products').add(productData);
      List<Product> products = await getProducts();
      Database().updateProductList(products);
    } catch (e) {
      if (kDebugMode) {
        print('Error adding product: $e');
      }
      rethrow;
    }
  }

  Future<void> addSalesInvoice(SalesInvoice salesInvoice) async {
    try {
      final salesInvoiceRef = await _firestore
          .collection('sales_invoices')
          .add(salesInvoice.toMap());

      String salesInvoiceID = salesInvoiceRef.id;
      salesInvoice.salesInvoiceID = salesInvoiceID;

      await salesInvoiceRef.update({'salesInvoiceID': salesInvoiceID});
      await _firestore.collection('sales_invoices').doc(salesInvoiceID).set({
        'salesInvoiceID': salesInvoiceID,
        'customerID': salesInvoice.customerID,
        'customerName': salesInvoice.customerName,
        'address': salesInvoice.address?.addressID,
        'date': salesInvoice.date,
        'paymentStatus': salesInvoice.paymentStatus.getName(),
        'salesStatus': salesInvoice.salesStatus.getName(),
        'totalPrice': salesInvoice.totalPrice,
      });

      for (SalesInvoiceDetail detail in salesInvoice.details) {
        await _firestore
            .collection('sales_invoice_details')
            .add(detail.toMap(salesInvoiceID));
      }

      // Update voucher usage if a voucher was applied
      if (salesInvoice.voucher != null) {
        await _updateVoucherUses(
            salesInvoice.customerID, salesInvoice.voucher!);
      }

      await Database().fetchSalesInvoice();
    } catch (e) {
      if (kDebugMode) {
        print('Error adding sales invoice: $e');
      }
      rethrow;
    }
  }

  Future<List<SalesInvoice>> getSalesInvoices() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('sales_invoices')
          .where('customerID', isEqualTo: Database().userID)
          .get();

      return await Future.wait(snapshot.docs.map((doc) async {
        SalesInvoice salesInvoice =
            SalesInvoice.fromMap(doc.id, doc.data() as Map<String, dynamic>);

        final QuerySnapshot detailsSnapshot = await FirebaseFirestore.instance
            .collection('sales_invoice_details')
            .where('salesInvoiceID', isEqualTo: salesInvoice.salesInvoiceID)
            .get();

        salesInvoice.details = detailsSnapshot.docs.map((detailDoc) {
          final detailData = detailDoc.data() as Map<String, dynamic>;
          final productID = detailData['productID'] as String;

          final product = Database().fullProductList.firstWhere(
                (product) => product.productID == productID,
                orElse: () =>
                    throw Exception('Product not found for ID: $productID'),
              );

          return SalesInvoiceDetail(
            salesInvoiceDetailID: detailDoc.id,
            salesInvoiceID: salesInvoice.salesInvoiceID,
            product: product,
            quantity: detailData['quantity'] as int,
            sellingPrice: (detailData['sellingPrice'] as num).toDouble(),
            subtotal: (detailData['subtotal'] as num).toDouble(),
          );
        }).toList();

        return salesInvoice;
      }).toList());
    } catch (e) {
      if (kDebugMode) {
        print('Error getting sales invoices: $e');
      }
      rethrow;
    }
  }

  Future<void> confirmDelivery(SalesInvoice salesInvoice) async {
    try {
      await _firestore
          .collection('sales_invoices')
          .doc(salesInvoice.salesInvoiceID)
          .update({
        'salesStatus': SalesStatus.completed.getName(),
      });
      await Database().fetchSalesInvoice();
    } catch (e) {
      if (kDebugMode) {
        print('Error confirming delivery: $e');
      }
      // print('Lỗi khi xác nhận giao hàng: $e');
      rethrow;
    }
  }

  Future<List<Voucher>> getVouchers() async {
    try {
      final QuerySnapshot snapshot =
          await _firestore.collection('vouchers').get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['voucherID'] = doc.id;

        // Debug logging
        if (kDebugMode) {
          print('Raw startTime type: ${data['startTime'].runtimeType}');
          print('Raw startTime value: ${data['startTime']}');
          if (data['hasEndTime'] == true) {
            print('Raw endTime type: ${data['endTime'].runtimeType}');
            print('Raw endTime value: ${data['endTime']}');
          }
        }

        // Convert date to DateTime
        if (data['startTime'] is Timestamp) {
          data['startTime'] = (data['startTime'] as Timestamp).toDate();
        } else if (data['startTime'] is String) {
          data['startTime'] = DateTime.parse(data['startTime'] as String);
        }

        if (data['hasEndTime'] == true) {
          if (data['endTime'] is Timestamp) {
            data['endTime'] = (data['endTime'] as Timestamp).toDate();
          } else if (data['endTime'] is String) {
            data['endTime'] = DateTime.parse(data['endTime'] as String);
          }
        }

        // Handle localized descriptions
        if (data['description'] != null) {
          // If there's only one description, use it for both languages
          data['enDescription'] = data['description'];
          data['viDescription'] = data['description'];
        }

        return VoucherFactory.fromMap(doc.id, data);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting vouchers data: $e');
      }
      rethrow;
    }
  }

  Future<List<OwnedVoucher>> getOwnedVouchers() async {
    final QuerySnapshot snapshot = await _firestore
        .collection('owned_vouchers')
        .where('customerID', isEqualTo: Database().userID)
        .where('numberOfUses', isGreaterThan: 0)
        .get();
    return snapshot.docs.map((doc) {
      return OwnedVoucher.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }).toList();
  }

  Future<void> addOwnedVoucher(OwnedVoucher ownedVoucher) async {
    try {
      final collectionRef = _firestore.collection('owned_vouchers');
      final docRef = await collectionRef.add(ownedVoucher.toMap());
      await docRef.update({'ownedVoucherID': docRef.id});
    } catch (e) {
      if (kDebugMode) {
        print('Error adding owned voucher: $e');
      }
      rethrow;
    }
  }

  Future<void> removeOwnedVoucher(String ownedVoucherID) async {
    try {
      await FirebaseFirestore.instance
          .collection('owned_vouchers')
          .doc(ownedVoucherID)
          .delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error removing owned voucher: $e');
      }
      rethrow;
    }
  }

  Future<List<OwnedVoucher>> getOwnedVouchersByCustomerId(
      String customerId) async {
    try {
      // Using a simple where clause without sorting to avoid needing a composite index
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('owned_vouchers')
          .where('customerID', isEqualTo: customerId)
          .get();

      return snapshot.docs
          .map((doc) => OwnedVoucher(
                ownedVoucherID: doc.id,
                voucherID: doc['voucherID'] as String,
                customerID: doc['customerID'] as String,
                numberOfUses: doc['numberOfUses'] as int,
              ))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting owned vouchers: $e');
      }
      return [];
    }
  }

  Future<void> _updateVoucherUses(String customerId, Voucher voucher) async {
    try {
      // 1. Reduce owned voucher usage count
      final ownedVoucherQuery = await _firestore
          .collection('owned_vouchers')
          .where('customerID', isEqualTo: customerId)
          .where('voucherID', isEqualTo: voucher.voucherID)
          .limit(1)
          .get();

      if (ownedVoucherQuery.docs.isNotEmpty) {
        final ownedVoucherDoc = ownedVoucherQuery.docs.first;
        final currentUsage = ownedVoucherDoc.data()['numberOfUses'] as int;
        // Reduce usage by 1
        await ownedVoucherDoc.reference
            .update({'numberOfUses': currentUsage - 1});
        if (kDebugMode) {
          print('Reduced owned voucher usage count to ${currentUsage - 1}');
        }
      } else {
        if (kDebugMode) {
          print(
              'No owned voucher found for customer $customerId and voucher ${voucher.voucherID}');
        }
      }

      // 2. If it's a limited voucher, reduce usageLeft by 1
      if (voucher.isLimited) {
        final voucherDoc = await _firestore
            .collection('vouchers')
            .doc(voucher.voucherID)
            .get();

        if (voucherDoc.exists) {
          final currentUsageLeft = voucherDoc.data()?['usageLeft'] as int? ?? 0;
          if (currentUsageLeft > 0) {
            await voucherDoc.reference
                .update({'usageLeft': currentUsageLeft - 1});
            if (kDebugMode) {
              print('Reduced voucher usageLeft to ${currentUsageLeft - 1}');
            }
          }
        } else {
          if (kDebugMode) {
            print('Voucher document not found for ID: ${voucher.voucherID}');
          }
        }
      }

      // Update local voucher lists to reflect changes
      await Database().updateVoucherLists();
    } catch (e) {
      if (kDebugMode) {
        print('Error updating voucher usage: $e');
        print('Error details: ${e.toString()}');
      }
      // Continue with invoice creation even if voucher update fails
    }
  }
}
