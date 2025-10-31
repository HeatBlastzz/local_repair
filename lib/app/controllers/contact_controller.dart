import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/data/models/contact_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:flutter_application_test/utils/logger.dart';

class ContactController with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ContactController() {
    // Not automatically fetching on init to avoid unnecessary loads
  }

  Stream<List<Contact>> getContactsStream() {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestoreService.getContacts(user.uid);
    }
    // Return an empty stream if user is not logged in
    return Stream.value([]);
  }


  Future<String?> addContact(Contact contact) async {
    try {
      final currentContacts = await _firestoreService
          .getContacts(contact.customerId)
          .first; 

      final isExisting = currentContacts.any(
        (existingContact) => existingContact.locksmithId == contact.locksmithId,
      );

      if (isExisting) {
        return 'Thợ này đã có trong danh bạ của bạn.';
      }

      await _firestoreService.addContact(contact);
      return null; // Success
    } catch (e) {
      AppLogger.firestore("Error adding contact: $e");
      return 'Đã xảy ra lỗi khi thêm liên hệ.';
    }
  }

  Future<void> deleteContact(String contactId) {
    return _firestoreService.deleteContact(contactId);
  }
}
