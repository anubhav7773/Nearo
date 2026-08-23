import 'package:url_launcher/url_launcher.dart';

Future<void> openWhatsAppChat({
  required String phoneNumber,
  String message = '',
}) async {
  final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  final formattedNumber =
      cleanNumber.startsWith('91') ? cleanNumber : '91$cleanNumber';
  final uri = Uri.parse(
      'https://wa.me/$formattedNumber?text=${Uri.encodeComponent(message)}');

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    throw 'Could not launch WhatsApp';
  }
}
