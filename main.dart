import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const SmsOrganizerApp());

class SmsOrganizerApp extends StatelessWidget {
  const SmsOrganizerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const SmsHomeScreen(),
    );
  }
}

class SmsHomeScreen extends StatefulWidget {
  const SmsHomeScreen({super.key});
  @override
  State<SmsHomeScreen> createState() => _SmsHomeScreenState();
}

class _SmsHomeScreenState extends State<SmsHomeScreen> {
  final SmsQuery _query = SmsQuery();
  List<SmsMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSms();
  }

  Future<void> _loadSms() async {
    setState(() => _loading = true);
    var status = await Permission.sms.request();
    if (status.isGranted) {
      final msgs = await _query.getAllSms;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  String _classify(String body) {
    final otpKey = RegExp(r'\b(otp|verification code|one time password|auth code|pin is)\b', caseSensitive: false);
    final otpDigits = RegExp(r'\b(\d{4,8})\b');
    if (otpKey.hasMatch(body) && otpDigits.hasMatch(body)) return 'OTP';

    final txnKey = RegExp(r'\b(debited|credited|spent|paid|acct|a\/c|upi|imps|neft)\b', caseSensitive: false);
    final amtKey = RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
    if (txnKey.hasMatch(body) && amtKey.hasMatch(body)) return 'TXN';

    return 'OTHER';
  }

  String? _extractOtp(String body) => RegExp(r'\b(\d{4,8})\b').firstMatch(body)?.group(1);

  Widget _buildList(String category) {
    final filtered = _messages.where((m) => _classify(m.body ?? '') == category).toList();
    if (filtered.isEmpty) {
      return const Center(child: Text('No messages found in this category.'));
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final m = filtered[i];
        final body = m.body ?? '';
        final otp = category == 'OTP' ? _extractOtp(body) : null;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(m.address ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(body),
            ),
            trailing: otp != null
                ? ElevatedButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: otp));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Copied OTP: $otp')),
                      );
                    },
                    child: Text('Copy $otp'),
                  )
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Smart SMS Organizer'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSms),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '💳 Txns'),
              Tab(text: '🔐 OTPs'),
              Tab(text: '💬 Other'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildList('TXN'),
                  _buildList('OTP'),
                  _buildList('OTHER'),
                ],
              ),
      ),
    );
  }
}
