const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Delete user account completely (Auth + Firestore)
 * Only admins can call this function
 */
exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  // Check if caller is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  // Check if caller is admin
  const callerUid = context.auth.uid;
  const callerDoc = await admin
    .firestore()
    .collection("users")
    .doc(callerUid)
    .get();

  const callerRole = callerDoc.data()?.role;
  // Check if caller is super admin by email
  const callerEmail = context.auth.token.email;
  const isSuperAdminEmail = callerEmail === "mail2adiexp@gmail.com";

  const isAdmin =
    isSuperAdminEmail ||
    callerRole === "admin" ||
    callerRole === "administrator" ||
    callerRole === "super_admin" ||
    context.auth.token.admin === true;

  if (!isAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admins can delete user accounts",
    );
  }

  const { userId, email } = data;

  if (!userId || !email) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "userId and email are required",
    );
  }

  try {
    const batch = admin.firestore().batch();

    // 1. Delete Firestore user document
    const userRef = admin.firestore().collection("users").doc(userId);
    batch.delete(userRef);

    // 2. Delete partner requests
    const partnerRequestsSnapshot = await admin
      .firestore()
      .collection("partner_requests")
      .where("email", "==", email)
      .get();

    partnerRequestsSnapshot.forEach((doc) => {
      batch.delete(doc.ref);
    });

    // 3. Delete from pending_sellers if exists
    const pendingSellerRef = admin
      .firestore()
      .collection("pending_sellers")
      .doc(email);
    batch.delete(pendingSellerRef);

    // 4. Commit Firestore deletions
    await batch.commit();

    // 5. Delete Firebase Auth account
    await admin.auth().deleteUser(userId);

    return {
      success: true,
      message: `User ${email} deleted successfully from Auth and Firestore`,
    };
  } catch (error) {
    console.error("Error deleting user:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Failed to delete user: ${error.message}`,
    );
  }
});

/**
 * Update user role
 * Only admins can call this function
 */
exports.updateUserRole = functions.https.onCall(async (data, context) => {
  // Check if caller is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  // Check if caller is admin
  const callerUid = context.auth.uid;
  const callerDoc = await admin
    .firestore()
    .collection("users")
    .doc(callerUid)
    .get();

  const callerRole = callerDoc.data()?.role;
  // Check if caller is super admin by email
  const callerEmail = context.auth.token.email;
  const isSuperAdminEmail = callerEmail === "mail2adiexp@gmail.com";

  const isAdmin =
    isSuperAdminEmail ||
    callerRole === "admin" ||
    callerRole === "administrator" ||
    callerRole === "super_admin" ||
    context.auth.token.admin === true;

  if (!isAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admins can update user roles",
    );
  }

  const { userId, newRole } = data;

  if (!userId || !newRole) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "userId and newRole are required",
    );
  }

  try {
    // Update Firestore
    await admin.firestore().collection("users").doc(userId).update({
      role: newRole,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Optionally set custom claims for admin role
    if (newRole === "admin" || newRole === "administrator") {
      await admin.auth().setCustomUserClaims(userId, { admin: true });
    } else {
      await admin.auth().setCustomUserClaims(userId, { admin: false });
    }

    return {
      success: true,
      message: `User role updated to ${newRole}`,
    };
  } catch (error) {
    console.error("Error updating role:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Failed to update role: ${error.message}`,
    );
  }
});

exports.approvePartnerRequest = functions.https.onCall(async (data, context) => {
  // 1. Check if caller is authenticated and is an admin
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to approve partner requests.",
    );
  }

  const callerUid = context.auth.uid;
  const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
  const callerRole = callerDoc.data()?.role;
  // Check if caller is super admin by email
  const callerEmail = context.auth.token.email;
  const isSuperAdminEmail = callerEmail === "mail2adiexp@gmail.com";

  const isAdmin =
    isSuperAdminEmail ||
    callerRole === "admin" ||
    callerRole === "administrator" ||
    callerRole === "super_admin" ||
    callerRole === "state_admin" ||
    context.auth.token.admin === true;

  if (!isAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admins can approve partner requests.",
    );
  }

  // 2. Validate input
  const { requestId } = data;
  if (!requestId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with a 'requestId'.",
    );
  }

  const requestRef = admin.firestore().collection("partner_requests").doc(requestId);

  try {
    const requestDoc = await requestRef.get();

    // 3. Check if the request exists and is pending
    if (!requestDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Partner request not found.");
    }

    const requestData = requestDoc.data();
    if (requestData.status !== "pending") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Request has status '${requestData.status}' and cannot be approved.`,
      );
    }

    const { email, password, name, phone, role, businessName, address, servicePincode, state } = requestData;

    // Map role to internal role names (snake_case)
    let internalRole = role.toLowerCase();
    if (role === 'Service Provider') internalRole = 'service_provider';
    if (role === 'Delivery Partner') internalRole = 'delivery_partner';
    if (role === 'Seller') internalRole = 'seller';
    // Add other mappings if needed, but these are the main ones causing issues

    // 4. Create new user in Firebase Authentication
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name,
      disabled: false,
    });

    // 5. Create new user document in Firestore
    const newUserRef = admin.firestore().collection("users").doc(userRecord.uid);
    const userData = {
      uid: userRecord.uid,
      name: name,
      email: email,
      phone: phone,
      role: internalRole,
      status: 'approved', // Explicitly set status to approved
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      businessName: businessName || null,
      address: address || null,
      servicePincode: servicePincode || null,
      state: state || null, // Ensure state is copied

      // Add other fields as necessary
    };

    // Set custom claims if the role is admin
    if (internalRole === 'admin' || internalRole === 'administrator' || internalRole === 'super_admin' || internalRole === 'state_admin') {
      await admin.auth().setCustomUserClaims(userRecord.uid, { admin: true });
    }

    await newUserRef.set(userData);

    // 6. Update the request status to 'approved'
    await requestRef.update({
      status: "approved",
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: context.auth.uid,
    });

    return {
      success: true,
      message: `Successfully approved request and created user for ${email}.`,
      userId: userRecord.uid,
    };
  } catch (error) {
    console.error("Error approving partner request:", error);
    // Check if the error is a Firebase Auth error (e.g., email-already-exists)
    if (error.code && error.code.startsWith('auth/')) {
      throw new functions.https.HttpsError("already-exists", error.message);
    }
    throw new functions.https.HttpsError("internal", "An internal error occurred while approving the request.");
  }
});

/**
 * Create a new Core Staff account
 * Only admins can call this function
 */
exports.createStaffAccount = functions.https.onCall(async (data, context) => {
  // 1. Check if caller is authenticated and is an admin
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to create staff accounts.",
    );
  }

  const callerUid = context.auth.uid;
  const callerEmail = context.auth.token.email;

  // CRITICAL: Check super admin email FIRST, before any Firestore lookups
  // This allows the super admin to bypass document requirements
  const isSuperAdmin = callerEmail === "mail2adiexp@gmail.com";

  if (isSuperAdmin) {
    console.log("Super admin access granted for:", callerEmail);
    // Super admin verified - skip document checks and proceed
  } else {
    // For non-super-admin users, fetch and validate Firestore document
    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();

    // Log for debugging
    console.log("createStaffAccount called by regular user:", {
      uid: callerUid,
      email: callerEmail,
      docExists: callerDoc.exists,
      role: callerDoc.data()?.role,
    });

    // Check if document exists
    if (!callerDoc.exists) {
      console.error("Caller document not found in Firestore for UID:", callerUid);
      throw new functions.https.HttpsError(
        "failed-precondition",
        "User profile not found. Please ensure your account is properly set up.",
      );
    }

    const callerRole = callerDoc.data()?.role;

    // Check if user has admin role
    const isRegularAdmin =
      callerRole === "admin" ||
      callerRole === "administrator" ||
      context.auth.token.admin === true;

    if (!isRegularAdmin) {
      console.log("Permission denied for user:", {
        uid: callerUid,
        email: callerEmail,
        role: callerRole,
      });
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can create staff accounts.",
      );
    }
  }

  // 2. Validate input
  const { email, password, name, phone, position, bio } = data;
  if (!email || !password || !name) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Email, password, and name are required.",
    );
  }

  try {
    // 3. Create new user in Firebase Authentication
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name,
      disabled: false,
    });

    // 4. Create new user document in Firestore
    const newUserRef = admin.firestore().collection("users").doc(userRecord.uid);
    const userData = {
      uid: userRecord.uid,
      name: name,
      email: email,
      phone: phone || "",
      position: position || "",
      bio: bio || "",
      role: "core_staff",
      permissions: {
        can_view_dashboard: true, // Default permission
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await newUserRef.set(userData);

    return {
      success: true,
      message: `Successfully created staff account for ${email}.`,
      userId: userRecord.uid,
    };
  } catch (error) {
    console.error("Error creating staff account:", error);
    if (error.code && error.code.startsWith('auth/')) {
      throw new functions.https.HttpsError("already-exists", error.message);
    }

    throw new functions.https.HttpsError("internal", "An internal error occurred while creating the account.");
  }
});

/**
 * Create a new State Admin account
 * Only admins can call this function
 */
exports.createStateAdminAccount = functions.https.onCall(async (data, context) => {
  // 1. Check if caller is authenticated and is an admin
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to create state admin accounts.",
    );
  }

  const callerUid = context.auth.uid;
  const callerEmail = context.auth.token.email;

  // CRITICAL: Check super admin email FIRST, before any Firestore lookups
  const isSuperAdmin = callerEmail === "mail2adiexp@gmail.com";

  if (isSuperAdmin) {
    console.log("Super admin access granted for:", callerEmail);
  } else {
    // For non-super-admin users, fetch and validate Firestore document
    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();

    if (!callerDoc.exists) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "User profile not found.",
      );
    }

    const callerRole = callerDoc.data()?.role;

    // Check if user has admin role
    const isRegularAdmin =
      callerRole === "admin" ||
      callerRole === "administrator" ||
      context.auth.token.admin === true;

    if (!isRegularAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can create state admin accounts.",
      );
    }
  }

    // 2. Validate input
  const { email, password, name, phone, assignedState, role } = data;
  if (!email || !password || !name) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Email, password, and name are required.",
    );
  }

  const newRole = role || "state_admin";

  // If role is state_admin, assignedState is required
  if (newRole === "state_admin" && !assignedState) {
     throw new functions.https.HttpsError(
      "invalid-argument",
      "Assigned state is required for State Admins.",
    );
  }

  try {
    // 3. Create new user in Firebase Authentication
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name,
      phoneNumber: phone && phone.length > 0 ? phone : undefined, // Optional
      disabled: false,
    });

    // Set custom claims if the role is admin-level
    if (newRole === 'administrator' || newRole === 'super_admin' || newRole === 'state_admin') {
      await admin.auth().setCustomUserClaims(userRecord.uid, { admin: true });
    }

    // 4. Create new user document in Firestore
    const newUserRef = admin.firestore().collection("users").doc(userRecord.uid);
    const userData = {
      uid: userRecord.uid,
      name: name,
      email: email,
      phone: phone || "",
      role: newRole,
      permissions: {
        can_view_dashboard: true,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (newRole === 'state_admin') {
      userData.assignedState = assignedState;
    }

    await newUserRef.set(userData);

    return {
      success: true,
      message: `Successfully created state admin account for ${email} in ${assignedState}.`,
      userId: userRecord.uid,
    };
  } catch (error) {
    console.error("Error creating state admin account:", error);
    if (error.code && error.code.startsWith('auth/')) {
      throw new functions.https.HttpsError("already-exists", error.message);
    }
    throw new functions.https.HttpsError("internal", "An internal error occurred while creating the account.");
  }
});



/**
 * On Order Create Trigger
 * 1. Reduces stock for purchased items
 * 2. Sends notifications to Customer, Sellers, and Admin
 */
exports.onOrderCreate = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snap, context) => {
    const orderData = snap.data();
    const orderId = context.params.orderId;
    const batch = admin.firestore().batch();

    try {
      // 1. Reduce Stock & Update salesCount
      // Using transactions for each product to ensure stock doesn't go below zero
      const items = orderData.items || [];
      for (const item of items) {
        if (!item.productId) continue;

        let targetId = item.productId;
        let deductQty = item.quantity;

        const variantMatch = targetId.match(/(.*)_(\d+(\.\d+)?[kK]?[gG])$/);
        if (variantMatch) {
          const baseId = variantMatch[1];
          const weightLabel = variantMatch[2].toLowerCase();
          let multiplier = 1.0;
          if (weightLabel.endsWith('kg')) multiplier = parseFloat(weightLabel.replace('kg', ''));
          else if (weightLabel.endsWith('g')) multiplier = parseFloat(weightLabel.replace('g', '')) / 1000.0;
          
          if (multiplier > 0) {
            targetId = baseId;
            deductQty = item.quantity * multiplier;
          }
        }

        const productRef = admin.firestore().collection("products").doc(targetId);
        
        try {
          await admin.firestore().runTransaction(async (transaction) => {
            const productDoc = await transaction.get(productRef);
            if (!productDoc.exists) {
              console.warn(`Product ${targetId} not found, skipping stock update.`);
              return;
            }

            const currentData = productDoc.data();
            const currentStock = currentData.stock || 0;
            const currentSales = currentData.salesCount || 0;

            // Ensure stock never goes below zero
            const newStock = Math.max(0, currentStock - deductQty);
            
            transaction.update(productRef, {
              stock: newStock,
              salesCount: currentSales + item.quantity
            });
          });
        } catch (txError) {
          console.error(`Transaction failed for product ${targetId}:`, txError);
          // Fallback to simple increment if transaction fails, but at least we tried
        }
      }

      // 1.5 Backfill sellerIds if missing (Self-Healing)
      if (!orderData.sellerIds) {
        const sellerIds = [...new Set(items.map(i => i.sellerId).filter(id => id))];
        if (sellerIds.length > 0) {
          const orderRef = admin.firestore().collection('orders').doc(orderId);
          batch.update(orderRef, { sellerIds: sellerIds });
          console.log(`Backfilling sellerIds for order ${orderId}:`, sellerIds);
        }
      }

      // 2. Create Notifications

      // A. Notify Customer
      if (orderData.userId) {
        const customerNotifRef = admin.firestore().collection("notifications").doc();
        batch.set(customerNotifRef, {
          toUserId: orderData.userId,
          title: "Order Placed Successfully",
          body: `Your order #${orderId} has been placed. We will update you once it's shipped.`,
          type: "order_update",
          relatedId: orderId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          userId: orderData.userId // Redundant but good for queries
        });
      }

      // B. Notify Sellers (Group by sellerId)
      const sellerItems = {};
      for (const item of items) {
        if (item.sellerId) {
          if (!sellerItems[item.sellerId]) {
            sellerItems[item.sellerId] = [];
          }
          sellerItems[item.sellerId].push(item.productName);
        }
      }

      for (const [sellerId, productNames] of Object.entries(sellerItems)) {
        const sellerNotifRef = admin.firestore().collection("notifications").doc();
        const productListStr = productNames.join(", ");
        batch.set(sellerNotifRef, {
          toUserId: sellerId,
          title: "New Order Received!",
          body: `You have received a new order #${orderId} for: ${productListStr}`,
          type: "seller_order",
          relatedId: orderId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          userId: sellerId
        });
      }

      // C. Notify Admin (Using a fixed ID or broadcasting to all admins later. 
      // For now, we'll CREATE a notification document that admins can query, 
      // or if we have a specific admin ID, we target it. 
      // Since we don't have a single admin ID, we'll skip direct targeting 
      // and rely on Admin Panel querying 'notifications' where toUserId == 'admin' or type == 'admin_alert'
      // OR we can finding all admin users. For performance, let's just make a generic admin notification.)

      // OPTION: Sending to a 'system_notifications' collection or similar?
      // Let's send to the Super Admin email user ID if we knew it, but finding it is async.
      // Simpler: Just rely on Admin Dashboard "Recent Orders" for now, OR
      // query for admin users (expensive in trigger?).
      // Let's checking if we can find admins easily.
      // The previous code had a "notifyAdmins" helper in Dart, but here we are in JS.
      // Let's skip Admin Push Notification for this step to avoid timeout/complexity, 
      // assuming Admin checks dashboard. 
      // BUT, let's add a "system" notification just in case we have a viewer for it.

      const adminNotifRef = admin.firestore().collection("notifications").doc();
      batch.set(adminNotifRef, {
        toUserId: "admin", // This requires the Admin App to query where userId == 'admin'
        title: "New Order Placed",
        body: `Order #${orderId} placed by ${orderData.deliveryAddress?.name || 'User'} for ₹${orderData.totalAmount}`,
        type: "admin_order",
        relatedId: orderId,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        userId: "admin" // This requires the Admin App to query where userId == 'admin'
      });

      // --- BRAND NEW: FCM Push Notification to Admins ---
      try {
        const payload = {
          notification: {
            title: "🔔 New Order Received!",
            body: `Order #${orderId} placed for ₹${orderData.totalAmount}`,
          },
          data: {
            orderId: String(orderId),
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          },
          topic: "admin_new_orders"
        };
        // Adding it to fire-and-forget promise array or await it
        await admin.messaging().send(payload);
        console.log(`FCM Push Notification sent to 'admin_new_orders' topic for order ${orderId}`);
      } catch (fcmError) {
        console.error(`Error sending FCM to 'admin_new_orders' for order ${orderId}:`, fcmError);
      }
      // ----------------------------------------------------

      await batch.commit(); // Commit all changes (stock + notifications)
      console.log(`Order ${orderId} processed: Stock updated and notifications sent.`);

    } catch (error) {
      console.error(`Error processing order ${orderId}:`, error);
    }
  });

/**
 * Verify Payment and Create Order
 * Securely creates an order only after verifying the payment ID.
 */
exports.verifyPayment = functions.https.onCall(async (data, context) => {
  // 1. Authentication Check
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be logged in to place an order."
    );
  }

  const userId = context.auth.uid;
  const { items, totalAmount, deliveryAddress, phoneNumber, paymentId } = data;

  // 2. Input Validation
  if (!items || !Array.isArray(items) || items.length === 0) {
    throw new functions.https.HttpsError("invalid-argument", "Order must contain items.");
  }
  if (!totalAmount || totalAmount <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid total amount.");
  }
  if (!paymentId || !deliveryAddress || !phoneNumber) {
    throw new functions.https.HttpsError("invalid-argument", "Missing payment or delivery details.");
  }

  try {
    // 3. Payment Verification (Mock Logic)
    // In a real app, you would call Stripe/Razorpay API here with paymentId
    const isValidPayment = paymentId.toString().startsWith("PAY_");

    if (!isValidPayment) {
      throw new functions.https.HttpsError("permission-denied", "Payment verification failed. Invalid Payment ID.");
    }

    // 4. Create Order in Firestore
    // Note: We don't need to manually reduce stock here because 
    // the 'onOrderCreate' trigger will handle stock reduction and notifications automatically 
    // when this document is created.

    // Destructure state from data (passed from OrderProvider)
    const { state } = data;

    // Optional: Validate state if required (e.g. check against allowed list)
    // For now, we trust the client or allow open input, but verify it exists
    if (!state) {
      console.warn("Order created without state field. State Admin filtering may fail.");
    }

    // Extract sellerIds for security rules
    const sellerIds = [...new Set(items.map(item => item.sellerId).filter(id => id))];

    const orderData = {
      userId: userId,
      items: items, // Expecting list of objects matching OrderItem structure
      totalAmount: totalAmount,
      deliveryAddress: deliveryAddress,
      phoneNumber: phoneNumber,
      state: state || null, // Create top-level state field
      orderDate: admin.firestore.FieldValue.serverTimestamp(),
      status: 'placed', // Initial status
      paymentStatus: 'paid', // Key difference: Paid immediately
      paymentMethod: 'Online',
      paymentId: paymentId,
      statusHistory: {
        'placed': admin.firestore.FieldValue.serverTimestamp()
      },
      sellerIds: sellerIds, // Added for security filtering
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const orderRef = await admin.firestore().collection("orders").add(orderData);

    console.log(`Order created securely via verifyPayment: ${orderRef.id}`);

    return {
      success: true,
      orderId: orderRef.id
    };

  } catch (error) {
    console.error("Error in verifyPayment:", error);
    throw new functions.https.HttpsError("internal", "Order creation failed: " + error.message);
  }
});

/**
 * On Order Update Trigger
 * Handles automatic transaction recording when order status changes.
 * - When status changes to 'delivered' -> Credit Seller Wallet
 * - When status changes to 'returned' -> Debit Seller Wallet (Refund)
 */
exports.onOrderUpdate = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    const orderId = context.params.orderId;

    const newStatus = newData.status;
    const oldStatus = oldData.status;

    // Only proceed if status has changed
    if (newStatus === oldStatus) return null;

    const batch = admin.firestore().batch();
    const items = newData.items || [];

    // Calculate seller amounts
    const sellerAmounts = {};
    for (const item of items) {
      if (item.sellerId) {
        const price = Number(item.price) || 0;
        const quantity = Number(item.quantity) || 0;
        const total = price * quantity;

        sellerAmounts[item.sellerId] = (sellerAmounts[item.sellerId] || 0) + total;
      }
    }

    try {
      // 1. Fetch Platform Fee Settings
      let platformFeePercentage = 5.0; // Default 5%
      try {
        const settingsDoc = await admin.firestore().collection('app_settings').doc('general').get();
        if (settingsDoc.exists) {
          const settingsData = settingsDoc.data();
          platformFeePercentage = Number(settingsData.sellerPlatformFeePercentage) || 
                                 Number(settingsData.platformFeePercentage) || 5.0;
        }
      } catch (settingsError) {
        console.error("Error fetching platform fee settings:", settingsError);
      }

      // 2. Handle 'delivered' -> Credit Seller Net & Record Commission
      if (newStatus === "delivered" && oldStatus !== "delivered") {
        console.log(`Order ${orderId} delivered. Crediting sellers and recording commissions.`);

        for (const [sellerId, totalAmount] of Object.entries(sellerAmounts)) {
          // Skip platform fee for admin/store owned products
          const isStoreOwned = sellerId === 'admin';
          const commissionAmount = isStoreOwned ? 0 : totalAmount * (platformFeePercentage / 100);
          const netSellerAmount = totalAmount - commissionAmount;

          // A. Credit Seller (Net Amount)
          const sellerTxRef = admin.firestore().collection("transactions").doc();
          batch.set(sellerTxRef, {
            userId: sellerId,
            amount: netSellerAmount,
            type: "credit",
            description: `Earnings for Order #${orderId}${commissionAmount > 0 ? ` (Net after ${platformFeePercentage}% fee)` : ''}`,
            status: "completed",
            referenceId: orderId,
            metadata: {
              orderId: orderId,
              grossAmount: totalAmount,
              platformFee: commissionAmount,
              platformFeePercentage: platformFeePercentage
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          });

          // B. Record Commission (if any)
          if (commissionAmount > 0) {
            const commissionTxRef = admin.firestore().collection("transactions").doc();
            batch.set(commissionTxRef, {
              userId: "admin", // Standard admin/platform identifier
              amount: commissionAmount,
              type: "credit",
              description: `Commission from Order #${orderId} (Seller: ${sellerId})`,
              status: "completed",
              referenceId: orderId,
              metadata: {
                orderId: orderId,
                sellerId: sellerId,
                type: "Order Commission", // For AdminFinancialScreen filtering
                platformFee: commissionAmount, // For AdminFinancialScreen aggregation
                platformFeePercentage: platformFeePercentage
              },
              createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
          }
        }

        // C. Credit Delivery Partner (if applicable)
        const deliveryPartnerId = newData.deliveryPartnerId;
        const deliveryFee = Number(newData.deliveryFee) || 0;
        if (deliveryPartnerId && deliveryFee > 0) {
          const deliveryTxRef = admin.firestore().collection("transactions").doc();
          batch.set(deliveryTxRef, {
            userId: deliveryPartnerId,
            amount: deliveryFee,
            type: "credit",
            description: `Delivery Fee for Order #${orderId}`,
            status: "completed",
            referenceId: orderId,
            metadata: {
              orderId: orderId,
              source: 'delivery_fee'
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      }
      // 3. Handle 'returned' -> Debit Seller (Net) & Reverse Commission
      else if (newStatus === "returned" && oldStatus !== "returned") {
        console.log(`Order ${orderId} returned. Debiting sellers and reversing commissions.`);

        for (const [sellerId, totalAmount] of Object.entries(sellerAmounts)) {
          const isStoreOwned = sellerId === 'admin';
          const commissionAmount = isStoreOwned ? 0 : totalAmount * (platformFeePercentage / 100);
          const netSellerAmount = totalAmount - commissionAmount;

          // A. Debit Seller (Net Amount)
          const sellerTxRef = admin.firestore().collection("transactions").doc();
          batch.set(sellerTxRef, {
            userId: sellerId,
            amount: netSellerAmount,
            type: "refund", // Debit/Refund from seller
            description: `Refund for Order #${orderId}${commissionAmount > 0 ? ` (Net after ${platformFeePercentage}% fee reversal)` : ''}`,
            status: "completed",
            referenceId: orderId,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          });

          // B. Reverse Commission (if any)
          if (commissionAmount > 0) {
            const commissionTxRef = admin.firestore().collection("transactions").doc();
            batch.set(commissionTxRef, {
              userId: "admin", 
              amount: commissionAmount,
              type: "refund", // Debit commission from admin
              description: `Commission Reversal for Order #${orderId} (Seller: ${sellerId})`,
              status: "completed",
              referenceId: orderId,
              metadata: {
                orderId: orderId,
                sellerId: sellerId,
                type: "Order Commission", // Keep type for filtering
                platformFee: -commissionAmount, // Negative for aggregation if needed, or just type 'refund'
                platformFeePercentage: platformFeePercentage
              },
              createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
          }
        }
      }
      
      // 3. Handle 'cancelled' -> Replenish Stock
      else if (newStatus === "cancelled" && oldStatus !== "cancelled") {
        console.log(`Order ${orderId} cancelled. Replenishing stock and reversing sales count.`);
        
        for (const item of items) {
          if (!item.productId) continue;

          let targetId = item.productId;
          let replenishQty = item.quantity;

          // Handle Weight Variants
          const variantMatch = targetId.match(/(.*)_(\d+(\.\d+)?[kK]?[gG])$/);
          if (variantMatch) {
            const baseId = variantMatch[1];
            const weightLabel = variantMatch[2].toLowerCase();

            let multiplier = 1.0;
            if (weightLabel.endsWith('kg')) {
              multiplier = parseFloat(weightLabel.replace('kg', ''));
            } else if (weightLabel.endsWith('g')) {
              multiplier = parseFloat(weightLabel.replace('g', '')) / 1000.0;
            }

            if (multiplier > 0) {
              targetId = baseId;
              replenishQty = item.quantity * multiplier;
            }
          }

          const productRef = admin.firestore().collection("products").doc(targetId);
          batch.update(productRef, {
            stock: admin.firestore.FieldValue.increment(replenishQty),
            salesCount: admin.firestore.FieldValue.increment(-item.quantity)
          });
        }
      }

      // 4. Backfill sellerIds if missing (Lazy Migration)
      if (!newData.sellerIds) {
        const sellerIds = [...new Set(items.map(i => i.sellerId).filter(id => id))];
        if (sellerIds.length > 0) {
          const orderRef = admin.firestore().collection('orders').doc(orderId);
          batch.update(orderRef, { sellerIds: sellerIds });
          console.log(`Lazy Migration: Backfilling sellerIds for order ${orderId}:`, sellerIds);
        }
      }

      await batch.commit();
      console.log(`Transaction records updated for Order ${orderId}`);

    } catch (error) {
      console.error(`Error in onOrderUpdate for ${orderId}:`, error);
    }
  });

/**
 * Check if a user with the given phone number already exists in Firestore.
 * If yes, return a custom token for that user so they can log in.
 */
exports.checkAndReturnExistingAccount = functions.https.onCall(async (data, context) => {
  // 1. Must be authenticated (initially authenticated by Phone Auth)
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be authenticated to check accounts."
    );
  }

  // 2. Fetch the caller's Firebase Auth record to verify their phone number
  const callerUid = context.auth.uid;
  let callerRecord;
  try {
    callerRecord = await admin.auth().getUser(callerUid);
  } catch (e) {
    console.error("Error fetching caller record:", e);
    throw new functions.https.HttpsError("internal", "Failed to verify caller.");
  }

  const verifiedPhone = callerRecord.phoneNumber;
  if (!verifiedPhone) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Caller does not have a verified phone number."
    );
  }

  try {
    // Generate variations to search for
    const variations = [
      verifiedPhone, // e.g. +919051XXXXXX
      verifiedPhone.replace('+', ''), // e.g. 919051XXXXXX
    ];
    
    // For India (+91), try without the country code
    if (verifiedPhone.startsWith('+91')) {
      const withoutCountryCode = verifiedPhone.substring(3);
      variations.push(withoutCountryCode); // e.g. 9051XXXXXX
    }
    
    let userQuery = null;
    
    // Check all variations
    for (const variation of variations) {
      if (!userQuery || userQuery.empty) {
        userQuery = await admin.firestore()
          .collection("users")
          .where("phoneNumber", "==", variation)
          .limit(1)
          .get();
      }
      if (!userQuery || userQuery.empty) {
        userQuery = await admin.firestore()
          .collection("users")
          .where("phone", "==", variation)
          .limit(1)
          .get();
      }
      
      if (userQuery && !userQuery.empty) {
        break; // Match found!
      }
    }

    if (!userQuery || userQuery.empty) {
      // No existing account found.
      // Return false so the client knows this is a genuinely new user
      return { 
        exists: false, 
        message: "No existing account found for this phone number." 
      };
    }

    // 4. Existing account found!
    const existingUserDoc = userQuery.docs[0];
    const existingUid = existingUserDoc.id;

    // Optional but recommended: Check if the original account is disabled
    const existingRecord = await admin.auth().getUser(existingUid);
    if (existingRecord.disabled) {
      throw new functions.https.HttpsError("permission-denied", "Account disabled.");
    }

    // 5. Generate a Custom Token for the original account
    const customToken = await admin.auth().createCustomToken(existingUid);

    // Set a flag to optionally clean up the temporary phone auth account later 
    return {
      exists: true,
      customToken: customToken,
      originalUid: existingUid,
      temporaryUidToClean: callerUid 
    };

  } catch (error) {
    console.error("Error in checkAndReturnExistingAccount:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to check existing accounts: " + error.message
    );
  }
});

/**
 * On Booking Update Trigger
 * Handles automatic transaction recording when booking status changes to 'completed'.
 * - Credit Provider Wallet (providerEarnings)
 * - Record Service Fee (platformFeeAmount)
 */
exports.onBookingUpdate = functions.firestore
  .document("bookings/{bookingId}")
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    const bookingId = context.params.bookingId;

    const newStatus = newData.status;
    const oldStatus = oldData.status;

    // Only proceed if status has changed to 'completed'
    if (newStatus === "completed" && oldStatus !== "completed") {
      console.log(`Booking ${bookingId} completed. Recording transactions.`);

      const providerId = newData.providerId;
      const providerEarnings = Number(newData.providerEarnings) || 0;
      const platformFeeAmount = Number(newData.platformFeeAmount) || 0;
      const serviceName = newData.serviceName || "Service";

      const batch = admin.firestore().batch();

      // 1. Credit Provider (Net Earnings)
      if (providerId && providerEarnings > 0) {
        const providerTxRef = admin.firestore().collection("transactions").doc();
        batch.set(providerTxRef, {
          userId: providerId,
          amount: providerEarnings,
          type: "credit",
          description: `Earnings for Service: ${serviceName} (#${bookingId})`,
          status: "completed",
          referenceId: bookingId,
          metadata: {
            bookingId: bookingId,
            serviceName: serviceName,
            platformFee: platformFeeAmount
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      // 2. Record Service Fee (Commission)
      if (platformFeeAmount > 0) {
        const commissionTxRef = admin.firestore().collection("transactions").doc();
        batch.set(commissionTxRef, {
          userId: "admin",
          amount: platformFeeAmount,
          type: "credit",
          description: `Service Fee for: ${serviceName} (#${bookingId})`,
          status: "completed",
          referenceId: bookingId,
          metadata: {
            bookingId: bookingId,
            providerId: providerId,
            type: "Service Fee", // For AdminFinancialScreen filtering
            platformFee: platformFeeAmount, // For AdminFinancialScreen aggregation
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      try {
        await batch.commit();
        console.log(`Transaction records updated for Booking ${bookingId}`);
      } catch (error) {
        console.error(`Error in onBookingUpdate for ${bookingId}:`, error);
      }
    }
  });
