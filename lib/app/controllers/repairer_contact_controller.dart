import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/data/models/repairer_contact_model.dart';
import 'package:flutter_application_test/data/services/firestore_service.dart';
import 'package:flutter_application_test/utils/logger.dart';

class RepairerContactController with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  RepairerContactController() {}

  Stream<List<RepairerContactModel>> getContactsStream() {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestoreService.getRepairerContacts(user.uid);
    }

    return Stream.value([]);
  }

  Future<String?> addContact(RepairerContactModel contact) async {
    try {
      final currentContacts = await _firestoreService
          .getRepairerContacts(contact.repairerId)
          .first;

      final isExisting = currentContacts.any(
        (existingContact) => existingContact.customerId == contact.customerId,
      );

      if (isExisting) {
        return 'Khách hàng này đã có trong danh bạ của bạn.';
      }

      await _firestoreService.addRepairerContact(contact);
      return null;
    } catch (e) {
      AppLogger.firestore("Error adding repairer contact: $e");
      return 'Đã xảy ra lỗi khi thêm liên hệ.';
    }
  }

  Future<void> deleteContact(String contactId) {
    return _firestoreService.deleteRepairerContact(contactId);
  }
}
