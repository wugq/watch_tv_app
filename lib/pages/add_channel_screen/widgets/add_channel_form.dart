import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/pages/add_channel_screen/controller/add_channel_controller.dart';
import 'package:tv/pages/add_channel_screen/widgets/input_text_widget.dart';

class AddChannelForm extends StatefulWidget {
  const AddChannelForm({Key? key}) : super(key: key);

  @override
  State<AddChannelForm> createState() => _AddChannelFormState();
}

class _AddChannelFormState extends State<AddChannelForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _url = TextEditingController();

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
              inputController: _name,
              validatorText: 'You have to input a channel name',
              hintText: 'Channel Name',
            ),
            const SizedBox(height: 20),
            InputTextWidget(
              inputController: _url,
              validatorText: 'You have to input a channel URL',
              hintText: 'Channel URL',
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) {
                  return;
                }

                controller.addChannel(_name.text, _url.text);
                Get.back();
                Get.snackbar("add channel", _name.text);
              },
              child: const Text("save"),
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
