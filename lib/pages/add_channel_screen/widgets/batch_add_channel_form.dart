import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/pages/add_channel_screen/controller/add_channel_controller.dart';
import 'package:tv/pages/add_channel_screen/widgets/input_text_widget.dart';

class BatchAddChannelForm extends StatefulWidget {
  const BatchAddChannelForm({Key? key}) : super(key: key);

  @override
  State<BatchAddChannelForm> createState() => _BatchAddChannelFormState();
}

class _BatchAddChannelFormState extends State<BatchAddChannelForm> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var controller = Get.find<AddChannelController>();

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          shrinkWrap: true,
          children: [
            InputTextWidget(
              inputController: _text,
              validatorText: 'You have to input channel name',
              hintText:
                  'Name, http://domain/stream.m3u8\nName, http://domain/stream.m3u8',
              isMultiLine: true,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) {
                  return;
                }
                await controller.batchAddChannel(_text.text);
                Get.back();
                Get.snackbar("batch add channel", "");
              },
              child: const Text("Save"),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF565368),
                primary: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
