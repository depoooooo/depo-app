import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import 'admin.dart';
import 'courier.dart';
import 'partner.dart';
import 'supervisor.dart';

/// يفتح الواجهة حسب دور الحساب
class RoleHome extends StatelessWidget {
  const RoleHome({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        switch (app.me?.role) {
          case Role.restaurant:
          case Role.merchant:
            return PartnerHome(); // ignore: prefer_const_constructors
          case Role.courier:
            return CourierHome(); // ignore: prefer_const_constructors
          case Role.supervisor:
            return SupervisorHome(); // ignore: prefer_const_constructors
          case Role.admin:
            return AdminHome(); // ignore: prefer_const_constructors
          default:
            return Scaffold(appBar: AppBar(), body: const Center(child: Text('هذا الحساب زبون')));
        }
      },
    );
  }
}
