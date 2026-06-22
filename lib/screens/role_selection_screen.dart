import 'package:flutter/material.dart';
import 'register_screen.dart'; 

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _goToRegister(BuildContext context, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterScreen(userType: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Hesap Türü"), 
        backgroundColor: Colors.transparent, 
        iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Nasıl kayıt olmak istiyorsun?", 
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 40),
              
              _RoleButton(
                label: "SPORCU", 
                icon: Icons.directions_run, 
                color: Colors.greenAccent, 
                onTap: () => _goToRegister(context, 'athlete')
              ),
              const SizedBox(height: 20),
              
              _RoleButton(
                label: "ANTRENÖR", 
                // HATA VEREN İKONU DEĞİŞTİRDİK:
                icon: Icons.timer, // sports_whistle yerine timer (kronometre) koyduk
                color: Colors.blueAccent, 
                onTap: () => _goToRegister(context, 'coach')
              ),
              const SizedBox(height: 20),
              
              _RoleButton(
                label: "SPOR KULÜBÜ", 
                icon: Icons.shield, 
                color: Colors.orangeAccent, 
                onTap: () => _goToRegister(context, 'club')
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _RoleButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900], 
          borderRadius: BorderRadius.circular(15), 
          border: Border.all(color: color, width: 2)
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 40), 
            const SizedBox(width: 20), 
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), 
            const Spacer(), 
            Icon(Icons.arrow_forward_ios, color: color)
          ]
        ),
      ),
    );
  }
}