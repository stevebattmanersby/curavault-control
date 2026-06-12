import 'package:curavault_admin/admin/pages/widgets/admin_sidebar.dart';
import 'package:curavault_admin/admin/pages/widgets/admin_top_bar.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.currentLocation, required this.child});

  final String currentLocation;
  final Widget child;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= AdminBreakpoints.desktop;
        final sidebar = AdminSidebar(
          currentLocation: widget.currentLocation,
          onNavigate: () {
            if (!isDesktop) _scaffoldKey.currentState?.closeDrawer();
          },
        );

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.transparent,
          drawer: isDesktop ? null : Drawer(child: sidebar),
          body: Container(
            decoration: BoxDecoration(
              color: context.tokens.background,
              gradient: context.tokens.backgroundGradient,
            ),
            child: Row(
              children: [
                if (isDesktop) SizedBox(width: 280, child: sidebar),
                Expanded(
                  child: Column(
                    children: [
                      AdminTopBar(
                        isDesktop: isDesktop,
                        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
