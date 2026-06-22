import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();
  
  bool _isLoading = false;
  bool _isCodeSent = false;
  String? _verificationId;
  String? _targetEmail; 

  // 1. ADIM: TELEFONU BUL VE SMS GÖNDER
  Future<void> _findUserAndSendSms() async {
    String phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Geçerli bir numara girin.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Firestore'dan e-postayı bul
      var query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu numara kayıtlı değil.")));
        return;
      }

      _targetEmail = query.docs.first.data()['email'];

      // SMS Gönder
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          _sendResetLink();
        },
        verificationFailed: (e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${e.message}")));
        },
        codeSent: (verificationId, token) {
          setState(() {
            _verificationId = verificationId;
            _isCodeSent = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Doğrulama kodu gönderildi.")));
        },
        codeAutoRetrievalTimeout: (id) { _verificationId = id; },
      );

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata oluştu.")));
    }
  }

  // 2. ADIM: KODU ONAYLA VE LİNKİ GÖNDER
  Future<void> _verifyAndSendEmail() async {
    String smsCode = _smsController.text.trim();
    if (smsCode.length < 6) return;

    setState(() => _isLoading = true);

    try {
      // Kod Doğrula
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      
      // Sadece doğrulama amaçlı sign-in
      await FirebaseAuth.instance.signInWithCredential(credential);
      
      // Başarılıysa linki at
      _sendResetLink();

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hatalı kod.")));
    }
  }

  void _sendResetLink() async {
    try {
      if (_targetEmail != null) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: _targetEmail!);
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("Başarılı", style: TextStyle(color: Colors.white)),
              content: Text(
                "Kimliğiniz doğrulandı.\n\n$_targetEmail adresine şifre sıfırlama bağlantısı gönderildi.",
                style: const TextStyle(color: Colors.white70)
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.pop(context);
                  },
                  child: const Text("Tamam", style: TextStyle(color: Colors.greenAccent)),
                )
              ],
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("E-posta gönderilemedi.")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Şifremi Unuttum"), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.password, size: 80, color: Colors.greenAccent),
            const SizedBox(height: 20),
            
            if (!_isCodeSent) ...[
              const Text("Telefon numaranızı girin. Doğrulama sonrası e-posta adresinize sıfırlama linki göndereceğiz.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "+90 555...",
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.phone, color: Colors.greenAccent),
                  filled: true, fillColor: Colors.grey[900],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _findUserAndSendSms,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text("DEVAM ET", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              Text("${_phoneController.text} numarasına gelen kodu girin.", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              TextField(
                controller: _smsController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 5),
                decoration: InputDecoration(
                  hintText: "SMS Kodu",
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true, fillColor: Colors.grey[900],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyAndSendEmail,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text("ONAYLA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}