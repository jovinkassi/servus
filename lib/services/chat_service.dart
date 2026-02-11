import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get or create a chat between a customer and worker
  Future<String> getOrCreateChat({
    required String customerId,
    required String customerName,
    required String workerId,
    required String workerName,
  }) async {
    // Check if chat already exists
    final existing = await _db
        .collection('chats')
        .where('customerId', isEqualTo: customerId)
        .where('workerId', isEqualTo: workerId)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    // Create new chat
    final doc = await _db.collection('chats').add({
      'customerId': customerId,
      'customerName': customerName,
      'workerId': workerId,
      'workerName': workerName,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// Send a message in a chat
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderType, // 'customer' or 'worker'
    required String text,
  }) async {
    final batch = _db.batch();

    // Add message to subcollection
    final messageRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    batch.set(messageRef, {
      'senderId': senderId,
      'senderType': senderType,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update last message on chat document
    final chatRef = _db.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderType': senderType,
    });

    await batch.commit();
  }

  /// Get real-time stream of messages for a chat
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Get all chats for a customer (real-time)
  Stream<QuerySnapshot> getChatsForCustomer(String customerId) {
    return _db
        .collection('chats')
        .where('customerId', isEqualTo: customerId)
        .snapshots();
  }

  /// Get all chats for a worker (real-time)
  Stream<QuerySnapshot> getChatsForWorker(String workerId) {
    return _db
        .collection('chats')
        .where('workerId', isEqualTo: workerId)
        .snapshots();
  }
}
