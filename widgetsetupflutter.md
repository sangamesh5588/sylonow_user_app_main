Get the Flutter SDK from Here!

Note: To ensure that this SDK functions correctly within your mobile application, please enable Mobile Integration while configuring the widget.
Step 1: Install the package in your project using the below command.
flutter pub add sendotp_flutter_sdk
Step 2: After successful installation of the package, you can import OTPVerification in your project. For example
import 'package:flutter/material.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
Step 3: Finally integrate the OTP verification using below code.

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: OTPExample(),
    );
  }
}

class OTPExample extends StatefulWidget {
  @override
  _OTPExampleState createState() => _OTPExampleState();
}

class _OTPExampleState extends State<OTPExample> {
  final String widgetId = '366274677442303433393835';  // Your widgetId
  final String authToken = '{token}'; // Your authToken

  String phoneNumber = '';
  
  @override
  void initState() {
    super.initState();
    OTPWidget.initializeWidget(widgetId, authToken); // Initialize widget
  }

  // Method to send OTP
  Future<void> handleSendOtp() async {
    final data = {'identifier': '91758XXXXXXX'};
    final response = await OTPWidget.sendOTP(data);
    print(response); // Handle response
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Send OTP Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Enter phone number'),
              onChanged: (value) {
                setState(() {
                  phoneNumber = value;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: handleSendOtp,
              child: Text('Send OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
SDK Methods:
We provide methods, which helps you integrate the OTP verification within your own user interface.

getWidgetProcess is an optional method, this will receive the widget configuration data.

There are three methods sendOTP, retryOTP and verifyOTP for the otp verification process.

You can call these methods as follow:

sendOTP: The sendOTP method is used to send an OTP to an identifier. The identifier can be an email or mobile number (it must contain the country code without +). You can call this method on a button press.
Note: This SDK does not support the Invisible OTP verification.

Future<void> handleSendOtp() async {
  final data = {
    'identifier': '91758XXXXXXX'  // Phone number or email
  };
  final response = await OTPWidget.sendOTP(data);
  print(response);  // Handle response
}
or


Future<void> handleSendOtp() async {
  final data = {
    'identifier': 'example@mail.com'  // Phone number or email
  };
  final response = await OTPWidget.sendOTP(data);
  print(response);  // Handle response
}
retryOTP: The retryOTP method allows retrying the OTP on desired communication channel. retryOTP method takes optional channel code for 'SMS-11', 'VOICE-4', 'EMAIL-3', 'WHATSAPP-12' for retrying otp.
Note: If the widget uses the default configuration, don't pass the channel as argument.

Future<void> handleRetryOtp() async {
  final data = {
    'reqId': '3463***************43931',  // Request ID
    'retryChannel': 11  // Retry via SMS
  };
  final response = await OTPWidget.retryOTP(data);
  print(response);  // Handle response
}
verifyOTP: The verifyOTP method is used to verify an OTP entered by the user.

Future<void> handleVerifyOtp() async {
  final data = {
    'reqId': '3463***************43931',  // Request ID
    'otp': '****'  // OTP entered by the user
  };
  final response = await OTPWidget.verifyOTP(data);
  print(response);  // Handle response
}



server side intigration 


curl --location --request POST
  'https://control.msg91.com/api/v5/widget/verifyAccessToken'
  --header 'Content-Type: application/json'
  --data-raw '{
  "authkey": "495150Aecd63E869a098d5P1",
  "access-token": "{jwt_token_from_otp_widget}"
}'


