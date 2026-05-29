import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'core/theme/rx_colors.dart';
import 'core/theme/theme_toggle_button.dart';
import 'features/auth/controller/supabase_service.dart';
import 'features/auth/presentation/sign_in_page.dart';
import 'screen_streaming_page.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'core/streaming/websocket_Input.dart';
import 'core/streaming/pairing_state.dart';
import 'core/streaming/streaming_service.dart';
import 'core/streaming/remote_control_service.dart'; // NEW
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'shared_folder_page.dart';
import 'core/theme/app_theme.dart';

import 'core/theme/theme_provider.dart';


Future<void> _showPairingQrDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _PairingQrContent(),
  );
}

class _PairingQrContent extends StatefulWidget {
  @override
  State<_PairingQrContent> createState() => _PairingQrContentState();
}

class _PairingQrContentState extends State<_PairingQrContent> {
  late final Future<String> _payloadFuture;

  @override
  void initState() {
    super.initState();
    // Start the future once and cache it
    _payloadFuture = _buildPairingPayload();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: FutureBuilder<String>(
          future: _payloadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return _buildErrorState(context);
            }

            final payload = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Pairing Code",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // QR Container
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 200,
                      gapless: false,
                    ),
                  ),
                  const SizedBox(height: 16),
                 TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          const Text("Generation Failed", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Please try again later.", textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ),
        ],
      ),
    );
  }
}
/// Separating logic keeps UI clean and testable
Future<String> _buildPairingPayload() async {
  final ip = await PairingService.instance.getLocalIp();
  final udpPort = PairingService.instance.udpPort;
  final wsPort = PairingService.instance.wsPort;

  if (ip.isEmpty) {
    throw Exception("Invalid IP");
  }

  return '$ip:$udpPort:$wsPort';
}

// ─────────────────────────────────────────────────────────────
//  Dashboard Page
// ─────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  final String userName;
  final String userEmail;

  const DashboardPage({
    super.key,
    this.userName  = '',
    this.userEmail = '',
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined,  label: 'Dashboard'),
    _NavItem(icon: Icons.tv_outlined,          label: 'Screen Streaming'),
    _NavItem(icon: Icons.folder_outlined,      label: 'Shared Folder'),
     ];

  Future<void> _logout() async {
    try {
      await SupabaseService.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInPage()),
      (_) => false,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RXColors.of(context).contentBg,

      body: Row(
        children: [
          _Sidebar(
            items: _navItems,
            selectedIndex: _selectedIndex,
            onItemTap: (i) => setState(() => _selectedIndex = i),
          ),
          Expanded(
            child: Column(
              children: [
                // _TopNavBar is fully self-contained — manages its own dropdown
                _TopNavBar(
                  pageTitle:  _navItems[_selectedIndex].label,
                  userName:   widget.userName,
                  userEmail:  widget.userEmail,
                  onLogout:   _logout,
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _DashboardBody(
          userName: widget.userName,
          userEmail: widget.userEmail,
          onOpenSharedFolder: () => setState(() => _selectedIndex = 2),
        );
      case 1:
        return const ScreenStreamingPage();
      case 2:
        return const SharedFolderPage();
      default:
        return const SizedBox();
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Sidebar
// ─────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemTap;

  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: c.sidebarBg,
        border: Border(right: BorderSide(color: c.sidebarBorder)),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.sidebarBorder)),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: c.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.desktop_windows,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RemoteX',
                      style: TextStyle(
                          color: c.textPrimary, fontSize: 16,
                          fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  Text('PC Controller',
                      style: TextStyle(color: c.textMuted, fontSize: 12)),
                ],
              ),
            ]),
          ),

          // Nav items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                children: items.asMap().entries.map((e) {
                  return _SidebarItem(
                    icon:     e.value.icon,
                    label:    e.value.label,
                    isActive: e.key == selectedIndex,
                    onTap:    () => onItemTap(e.key),
                  );
                }).toList(),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Version 1.0.0',
                style: TextStyle(color: c.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isActive ? c.sidebarActive : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, size: 20,
              color: isActive ? Colors.white : c.sidebarInactiveTxt),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: isActive ? Colors.white : c.sidebarInactiveTxt,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }
}

Widget _modernMenuTile({
  required dynamic c,
  required IconData icon,
  required String label,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
  bool isDestructive = false,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 2,
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDestructive
                          ? Colors.red
                          : c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    subtitle,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: c.textSecondary.withOpacity(0.7),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  Top Navigation Bar  (self-contained dropdown state)
// ─────────────────────────────────────────────────────────────
class _TopNavBar extends StatefulWidget {
  final String pageTitle;
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;

  const _TopNavBar({
    required this.pageTitle,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
  });

  @override
  State<_TopNavBar> createState() => _TopNavBarState();
}

class _TopNavBarState extends State<_TopNavBar> {
  // Key used to locate the avatar widget for accurate menu positioning
  final GlobalKey _avatarKey = GlobalKey();

  // Add MenuController for the MenuAnchor
  final MenuController _menuController = MenuController();

   @override
   Widget build(BuildContext context) {
     final c = RXColors.of(context);
     return Container(
      height: 64,
      decoration: BoxDecoration(
        color: c.navbarBg,
        border: Border(bottom: BorderSide(color: c.navbarBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(children: [
        Text(widget.pageTitle,
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        const ThemeToggleButton(),
        const SizedBox(width: 16),
        MenuAnchor(
          controller: _menuController,
          alignmentOffset: const Offset(0, 12),
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(
              c.isDark ? const Color(0xFF111827) : Colors.white,
            ),
           
            shadowColor:
            WidgetStatePropertyAll(Colors.black.withOpacity(0.18)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 10),
            ),

          ),

          menuChildren: [
            // TOP PROFILE CARD
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: c.isDark
                      ? [
                    const Color(0xFF1E293B),
                    const Color(0xFF0F172A),
                  ]
                      : [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE2E8F0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      _UserAvatar(
                        name: widget.userName,
                        size: 52,
                      ),

                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c.isDark
                                  ? const Color(0xFF111827)
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.userName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          widget.userEmail,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),


                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(
                height: 1,
                color: c.dashCardBorder.withOpacity(0.5),
              ),
            ),



            // MENU ITEMS


            _modernMenuTile(
              c:c,
              icon: Icons.logout_rounded,
              label: "Logout",
              subtitle: "Sign out from this device",
              color: Colors.red,
              isDestructive: true,
              onTap: () => _handleAction('logout'),
            ),

            const SizedBox(height: 4),
          ],

          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              _menuController.isOpen
                  ? _menuController.close()
                  : _menuController.open();
            },

            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),

                gradient: LinearGradient(
                  colors: c.isDark
                      ? [
                    const Color(0xFF1E293B),
                    const Color(0xFF0F172A),
                  ]
                      : [
                    Colors.white,
                    const Color(0xFFF8FAFC),
                  ],
                ),

                border: Border.all(
                  color: c.dashCardBorder.withOpacity(0.6),
                ),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      c.isDark ? 0.25 : 0.06,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),

              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: "profile_avatar",
                    child: _UserAvatar(
                      name: widget.userName,
                      size: 38,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        "Account",
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 14),

                  AnimatedRotation(
                    turns: _menuController.isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: c.textSecondary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
       ]),
     );
   }

   // Handle menu actions
   Future<void> _handleAction(String action) async {
     // close the menu first
     _menuController.close();
     if (!mounted) return;
     final c = RXColors.of(context);

     if (action == 'reset') {
       showDialog(
         context: context,
         builder: (ctx) => AlertDialog(
           title: const Text('Reset Password'),
           content: const Text('Reset password flow not implemented.'),
           actions: [
             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
           ],
         ),
       );
     } else if (action == 'settings') {
       // placeholder for settings
     } else if (action == 'logout') {
       widget.onLogout();
     }
   }

   // Helper to build menu items
   Widget _buildMenuItem(BuildContext context, {
     required String label,
     required IconData icon,
     required VoidCallback onTap,
     bool isDestructive = false,
   }) {
     final c = RXColors.of(context);
     final color = isDestructive ? const Color(0xFFEF4444) : c.textPrimary;
     return MenuItemButton(
       onPressed: onTap,
       leadingIcon: Icon(icon, size: 18, color: isDestructive ? color : c.textSecondary),
       child: Padding(
         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
         child: Text(
           label,
           style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
         ),
       ),
     );
   }
}

// ─────────────────────────────────────────────────────────────
//  User Avatar
// ─────────────────────────────────────────────────────────────
class _UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _UserAvatar({required this.name, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
//  User Dropdown
// ─────────────────────────────────────────────────────────────
class _UserDropdown extends StatelessWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onLogout;
  final VoidCallback onClose;

  const _UserDropdown({
    required this.userName,
    required this.userEmail,
    required this.onLogout,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: c.dropdownBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.dropdownBorder),
        boxShadow: [
          BoxShadow(
              color: c.dropdownShadow,
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header — real name + email
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(userEmail,
                    style: TextStyle(color: c.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Divider(height: 1, color: c.dropdownBorder),

          _DropdownItem(
            icon: Icons.lock_reset_outlined,
            label: 'Reset Password',
            color: c.textSecondary,
            onTap: onClose,
          ),

          Divider(height: 1, color: c.dropdownBorder),

          _DropdownItem(
            icon: Icons.logout,
            label: 'Logout',
            color: const Color(0xFFEF4444),
            onTap: onLogout,   // ← calls _closeDropdown then _logout()
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _DropdownItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DropdownItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Dashboard Body
// ─────────────────────────────────────────────────────────────
class _DashboardBody extends StatelessWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onOpenSharedFolder;
  const _DashboardBody({
    required this.userName,
    required this.userEmail,
    required this.onOpenSharedFolder,
  });

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard',
              style: TextStyle(
                  color: c.textPrimary, fontSize: 28,
                  fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Text('Manage your remote PC connection and control settings',
              style: TextStyle(color: c.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),

          _DeviceStatusCard(),
          const SizedBox(height: 28),

          Text('Quick Actions',
              style: TextStyle(
                  color: c.textPrimary, fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          _QuickActionsGrid(onOpenSharedFolder: onOpenSharedFolder),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Device Status Card
// ─────────────────────────────────────────────────────────────
class _DeviceStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    final pairing = context.watch<PairingState>();
    final connected = pairing.isConnected;
    final clientIp = pairing.clientIp;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: c.dashCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.dashCardBorder),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: c.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.smartphone_outlined, size: 28, color: c.textMuted),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                  connected ? 'Device Connected' : 'No Device Connected',
                  style: TextStyle(
                      color: c.textPrimary, fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                    color: connected ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                    shape: BoxShape.circle),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              connected
                  ? 'Paired with ${clientIp ?? 'unknown'}'
                  : 'Scan QR code to pair a device',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ],
        ),
       ]),
     );
   }
 }

// ─────────────────────────────────────────────────────────────
//  Quick Actions 2×2 Grid
// ─────────────────────────────────────────────────────────────
class _QuickActionsGrid extends StatefulWidget {
  final VoidCallback onOpenSharedFolder;

  const _QuickActionsGrid({required this.onOpenSharedFolder});

  @override
  State<_QuickActionsGrid> createState() => _QuickActionsGridState();
}

class _QuickActionsGridState extends State<_QuickActionsGrid> {
  bool _isStreaming = StreamingService.instance.isRunning;
  bool _isRemoteEnabled = RemoteControlService.instance.isEnabled; // NEW

  StreamSubscription<bool>? _streamSub;
  StreamSubscription<bool>? _remoteSub; // NEW

  @override
  void initState() {
    super.initState();

    // Streaming status
    _streamSub = StreamingService.instance.statusStream.listen((running) {
      if (!mounted) return;
      setState(() => _isStreaming = running);
    });

    // Remote control status
    _remoteSub = RemoteControlService.instance.statusStream.listen((enabled) {
      if (!mounted) return;
      setState(() => _isRemoteEnabled = enabled);
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _remoteSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    final pairing = context.watch<PairingState>();
    final connected = pairing.isConnected;

    final actions = <_QuickActionData>[];

    // ── 1. Start / Stop Screen Streaming ─────────────────────
    actions.add(_QuickActionData(
      iconBg: c.qaScreenBg,
      icon: _isStreaming ? Icons.stop_rounded : Icons.tv_outlined,
      iconColor: c.qaScreenIcon,
      title: _isStreaming ? 'Stop Screen Streaming' : 'Start Screen Streaming',
      titleColor: c.qaScreenTitleColor,
      subtitle: _isStreaming
          ? 'Stop streaming to mobile'
          : 'Share your PC screen with mobile device',
      onTap: () async {
        if (_isStreaming) {
          StreamingService.instance.stop();
        } else {
          // If no device is paired, ask the user whether to continue or cancel
          if (!connected) {
            final proceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('No device connected'),
                content: const Text('No device is currently paired. Do you want to continue and start streaming anyway?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            );

            if (proceed != true) {
              // User cancelled - do not start streaming
              return;
            }
          }

          StreamingService.instance.setTargetFps(60);
          final ok = await StreamingService.instance.start();
          if (!ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to start streaming')));
          }
        }
      },
    ));

    // ── 2. Enable / Disable Remote Control ───────────────────
    actions.add(_QuickActionData(
      // When enabled: green tint background; when disabled: default remote bg
      iconBg: _isRemoteEnabled
          ? const Color(0xFF22C55E).withOpacity(0.15)
          : c.qaRemoteBg,
      icon: _isRemoteEnabled
          ? Icons.radio_button_checked
          : Icons.radio_button_off,
      iconColor: _isRemoteEnabled
          ? Colors.red
          : const Color(0xFF22C55E),
      title: _isRemoteEnabled
          ? 'Disable Remote Control'
          : 'Enable Remote Control',
      titleColor: _isRemoteEnabled
          ? Colors.red
          : const Color(0xFF22C55E),
      subtitle: _isRemoteEnabled
          ? 'Mobile device can control mouse & keyboard — tap to disable'
          : 'Allow mobile device to control mouse/keyboard',
      onTap: () => RemoteControlService.instance.toggle(),
    ));

    // ── 3. Open Shared Folder ─────────────────────────────────
    actions.add(_QuickActionData(
      iconBg: c.qaFolderBg,
      icon: Icons.folder_outlined,
      iconColor: c.qaFolderIcon,
      title: 'Open Shared Folder',
      titleColor: c.qaFolderTitleColor,
      subtitle: 'Access files shared between PC and mobile',
      onTap: widget.onOpenSharedFolder,
    ));

    // ── 4. Connect / Disconnect Device ────────────────────────
    actions.add(_QuickActionData(
      iconBg: c.qaConnectBg,
      icon: connected ? Icons.link_off : Icons.smartphone_outlined,
      iconColor: c.qaConnectIcon,
      title: connected ? 'Disconnect Device' : 'Connect Device',
      titleColor: c.qaConnectTitleColor,
      subtitle: connected
          ? 'Disconnect paired mobile device'
          : 'Scan QR code to pair your mobile device',
      onTap: () async {
        if (connected) {
          // Auto-disable remote control when device disconnects
          if (_isRemoteEnabled) RemoteControlService.instance.disable();
          try {
            await PairingService.instance.disconnectClient();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Device disconnected')));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to disconnect device')));
            }
          }
        } else {
          _showPairingQrDialog(context);
        }
      },
    ));

    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 700 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 3.8,
        ),
        itemCount: actions.length,
        itemBuilder: (_, i) => _QuickActionCard(data: actions[i]),
      );
    });
  }
}

class _QuickActionData {
  final Color iconBg, iconColor, titleColor;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  const _QuickActionData({
    required this.iconBg, required this.icon, required this.iconColor,
    required this.title,  required this.titleColor, required this.subtitle,
    this.onTap,
  });
}

class _QuickActionCard extends StatefulWidget {
  final _QuickActionData data;
  const _QuickActionCard({required this.data});
  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.data.onTap ?? () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: _hovered
                ? (c.isDark ? const Color(0xFF243044) : const Color(0xFFF1F5F9))
                : c.dashCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.dashCardBorder),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: widget.data.iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.data.icon,
                  color: widget.data.iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.data.title,
                      style: TextStyle(
                          color: widget.data.titleColor,
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(widget.data.subtitle,
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Placeholder for other nav pages
// ─────────────────────────────────────────────────────────────
class _PlaceholderBody extends StatelessWidget {
  final IconData icon;
  final String title;
  const _PlaceholderBody({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: c.textMuted),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  color: c.textPrimary, fontSize: 22,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Coming soon',
              style: TextStyle(color: c.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}
