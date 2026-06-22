import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String userType;
  const RegisterScreen({super.key, required this.userType});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();

  // Değişken tanımlarını yukarı taşıdım
  final _emailControllerReal = TextEditingController(); 

  bool _isLoading = false;
  bool _isCodeSent = false;
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _phoneController.text = "+90";
  }

  // 1. ADIM: SMS GÖNDERME
  void _startRegistration() async {
    if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty || 
        _usernameController.text.isEmpty || _emailControllerReal.text.isEmpty || 
        _phoneController.text.length < 13 || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm alanları doğru doldurun."))
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String username = _usernameController.text.trim().toLowerCase();
      var checkUsername = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: username)
          .get();

      if (checkUsername.docs.isNotEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu kullanıcı adı alınmış!")));
        return;
      }

      await FirebaseAuth.instance.setLanguageCode('tr');
      
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Bazı Android cihazlarda SMS otomatik yakalanırsa direkt hesap oluşturur
          await _createAccount(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          print("SİBER HATA: ${e.code} - ${e.message}");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${e.message}")));
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _isCodeSent = true; // EKRANI SMS KODU GİRME MODUNA GEÇİRİR
            _verificationId = verificationId; // KODU BURAYA KAYDEDER
          });
          print("SMS GÖNDERİLDİ!");
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Beklenmedik Hata: $e")));
    }
  }

  // 2. ADIM: HESAP OLUŞTURMA
  Future<void> _createAccount(PhoneAuthCredential phoneCredential) async {
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(phoneCredential);
      User? user = userCredential.user;

      if (user != null) {
        // E-posta ve şifre güncelleme
        await user.updateEmail(_emailControllerReal.text.trim());
        await user.updatePassword(_passwordController.text.trim());

        String uid = user.uid;
        String usernameAsName = _usernameController.text.trim().toLowerCase();

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'name': usernameAsName,
          'fullName': "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}",
          'email': _emailControllerReal.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': widget.userType,
          'isApproved': widget.userType == 'athlete', 
          'createdAt': FieldValue.serverTimestamp(),
          'fcmToken': '', 
        });

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()), (route) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kayıt Hatası: ${e.message}")));
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bilinmeyen Hata: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Sportmen Kayıt"), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            if (!_isCodeSent) ...[
              _buildField(_firstNameController, "Ad", Icons.person),
              _buildField(_lastNameController, "Soyad", Icons.person_outline),
              _buildField(_usernameController, "Kullanıcı Adı", Icons.alternate_email, prefix: "@"),
              _buildField(_emailControllerReal, "E-Posta", Icons.email, type: TextInputType.emailAddress),
              _buildField(_phoneController, "Telefon", Icons.phone, type: TextInputType.phone, 
                onChanged: (value) {
                  if (!value.startsWith('+90')) {
                    _phoneController.text = '+90';
                    _phoneController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _phoneController.text.length),
                    );
                  }
                }
              ),
              _buildField(_passwordController, "Şifre", Icons.lock, obscure: true),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                  onPressed: _isLoading ? null : _startRegistration,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text("DEVAM ET", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              const Icon(Icons.security, size: 80, color: Colors.greenAccent),
              const SizedBox(height: 10),
              const Text("SMS Kodu Gönderildi", style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 20),
              _buildField(_smsController, "6 Haneli SMS Kodu", Icons.lock_clock, type: TextInputType.number),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                  onPressed: _isLoading ? null : () {
                    if (_verificationId != null) {
                      _createAccount(PhoneAuthProvider.credential(
                        verificationId: _verificationId!, 
                        smsCode: _smsController.text.trim()
                      ));
                    }
                  },
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text("KAYDI TAMAMLA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
              TextButton(onPressed: () => setState(() => _isCodeSent = false), child: const Text("Numarayı Değiştir", style: TextStyle(color: Colors.grey)))
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String hint, IconData icon, 
      {bool obscure = false, TextInputType type = TextInputType.text, String? prefix, Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        obscureText: obscure,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixText: prefix,
          prefixStyle: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true, fillColor: Colors.grey[900],
          prefixIcon: Icon(icon, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}