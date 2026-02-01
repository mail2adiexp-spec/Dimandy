import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AboutScreen extends StatelessWidget {
  static const routeName = '/about';

  const AboutScreen({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 50), // Added bottom padding
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.deepPurple.shade50,
                  Colors.purple.shade50,
                  Colors.pink.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Dimandy',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.deepPurple,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Dimandy में आपका स्वागत है—एक ऐसा नाम जिसके पीछे केवल व्यापार नहीं, बल्कि एक दिल का गहरा रिश्ता जो बादो पर खरा उतरने से और उनका पूरा करने से बनता है। हमारा सफर उस गाँव की मिट्टी से शुरू होता है जहाँ हमने भोजन की शुद्धता और अपनों की देखभाल का मूल्य सीखा। शहर आकर हमने देखा कि जीवन कितना जटिल है—परिवारों को ताज़गी नहीं मिलती और ज़रूरी काम के लिए भरोसेमंद मदद ढूँढ़ना कितना मुश्किल है। सबसे ज़्यादा हमारा ध्यान उन लोगों पर गया जो अपने परिवार की खातिर घर से दूर रहते हैं या काम में व्यस्त हैं, और हमारे बुज़ुर्गों पर जिन्हें उम्र या स्वास्थ्य के कारण बाज़ार तक जाना कठिन लगता है।',
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.7,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Dimandy का जन्म इसी जिम्मेदारी से हुआ है। यह सिर्फ़ एक प्लेटफॉर्म नहीं है; यह एक भरोसेमंद साथी है जो गाँव की शुद्धता को आपकी व्यस्त ज़िंदगी को सुविधा से जोड़ता है। हमारा लक्ष्य केवल डिलीवरी देना नहीं है, बल्कि आपको यह आश्वासन देना है कि जब आप काम में व्यस्त हों या घर पर आराम कर रहे हों या फिर आप अपने परिवार से दूर हो तो आपके परिवार को बेहतरीन पोषण और घर की देखभाल के साथ। और आपके घर तक हर सुविधा पहुंचना है हमारा पहला वादा है ग्रॉसरी में अटूट विश्वास। हम सीधे किसानों से ताज़ी और शुद्ध उपज लाते हैं। आपको Dimandy ऐप पर हर फल, हर सब्ज़ी में गाँव की शुद्धता मिलेगी। और हाँ, हम यह सब आपके अपनों तक पहुँचाने के लिए कोई डिलीवरी शुल्क नहीं लेते हैं।',
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.7,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 16),
                const Text(
                  'हमारा दूसरा वादा है घर की देखभाल में राहत। हमने समझा कि घर के अचानक बिगड़े हुए काम बुज़ुर्गों और व्यस्त लोगों के लिए बड़ी चिंता बन जाते हैं। इसलिए, हमने सत्यापित और अनुभवी पेशेवरों की एक टीम बनाई है जो ऐप बुकिंग पर तुरंत उपलब्ध होते हैं। चाहे वह इलेक्ट्रीशियन, प्लंबर, कारपेंटर की तकनीकी सेवाएँ हों, बाथरूम की सफ़ाई हो, या स्थानीय गाड़ी बुकिंग—हम हर ज़रूरत का समाधान हैं और यह सब सुविधा आपको कम से कम कीमत यानी जितना कम उतनी ही कीमत में उपलब्ध होगी।',
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.7,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Dimandy में हम व्यक्तिगत रूप से इस बात की गारंटी देते हैं कि आपको हमेशा सर्वोत्तम ही मिले। आपका विश्वास ही हमारी सबसे बड़ी कमाई है। आप हमारे Dimandy ऐप के माध्यम से आसानी से ऑर्डर या बुकिंग कर सकते हैं, या किसी भी ज़रूरत के लिए हमें सीधे 7479223366 पर कॉल कर सकते हैं। हमें आपकी सेवा करने और आपके अपनों की देखभाल में मदद करने का अवसर दें।',
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.7,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepPurple.shade200, width: 2),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        '❤️ आपका विश्वास, हमारा सबसे गहरा रिश्ता है।',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          color: Colors.deepPurple,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Dimandy',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContactScreen extends StatefulWidget {
  static const routeName = '/contact';

  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final message = _messageController.text.trim();

    if (name.isEmpty || email.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('contact_messages').add({
        'name': name,
        'email': email,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unread',
        'platform': kIsWeb ? 'web' : 'app',
      });

      if (!mounted) return;

      // Clear fields after success
      _nameController.clear();
      _emailController.clear();
      _messageController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent successfully! We will contact you soon.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 50),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Get in Touch',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const ListTile(
                leading: Icon(Icons.email, color: Colors.purple),
                title: Text('Email'),
                subtitle: Text('support@dimandy.in'),
              ),
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.purple),
                title: const Text('Phone'),
                subtitle: const Text('+91 7479223366'),
                onTap: () async {
                  final Uri launchUri = Uri(
                    scheme: 'tel',
                    path: '+917479223366',
                  );
                  if (await canLaunchUrl(launchUri)) {
                    await launchUrl(launchUri);
                  }
                },
              ),
              const ListTile(
                leading: Icon(Icons.location_on, color: Colors.purple),
                title: Text('Headquarters'),
                subtitle: Text('Farakka, Murshidabad, West Bengal, 742212'),
              ),
              const SizedBox(height: 32),
              const Text(
                'Send us a message',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sendMessage,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Send Message'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
