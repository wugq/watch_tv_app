import 'package:fijkplayer/fijkplayer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tv/data/channel.dart';
import 'package:tv/data/channel_database.dart';
import 'package:tv/data/channel_database_helper.dart';

class HomeScreenController extends FullLifeCycleController {
  final appLifecycleState = AppLifecycleState.resumed.obs;

  final FijkPlayer player = FijkPlayer();
  var videoRatio = 1.7777.obs;

  var channelName = "Please select a channel".obs;
  var playerStatus = "idle".obs;

  late ChannelDatabaseHelper channelDatabaseHelper;
  var sourceList = <Channel>[].obs;

  loadSourceList() async {
    List<Channel> list = await channelDatabaseHelper.showAllData();
    for (var element in list) {
      sourceList.add(element);
    }
    if (list.isNotEmpty) {
      switchChannel(list[0]);
    }
  }

  @override
  void onReady() async {
    WidgetsBinding.instance?.addObserver(this);

    Database channelDatabase = await ChannelDatabase.getDatabase();
    channelDatabaseHelper = ChannelDatabaseHelper(channelDatabase);
    // await channelDatabaseHelper.clearTable();
    loadSourceList();

    player.setOption(FijkOption.hostCategory, "request-screen-on", 1);
    player.addListener(playerValueListener);
    super.onReady();
  }

  @override
  void onClose() {
    WidgetsBinding.instance?.removeObserver(this);

    player.removeListener(playerValueListener);
    player.release();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appLifecycleState.value = state;

    if (kDebugMode) {
      print("AppLifecycleState is: " + state.toString());
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      playerPause();
    }

    super.didChangeAppLifecycleState(state);
  }

  void playerPause() {
    if (player.state == FijkState.started) {
      player.pause();
    }
  }

  Future<int> addChannel(Channel channel) async {
    sourceList.add(channel);
    return await channelDatabaseHelper.insertData(channel);
  }

  void deleteChannel(Channel channel) {
    sourceList.removeWhere((item) => item.key == channel.key);
    channelDatabaseHelper.deleteData(channel.key);
  }

  String getTextOfPlayerState(FijkState state) {
    String stateName = "";
    switch (state) {
      case FijkState.initialized:
        // stateName = "初始化播放器";
        stateName = "initialized";
        break;
      case FijkState.asyncPreparing:
        // stateName = "准备播放";
        stateName = "preparing";
        break;
      case FijkState.prepared:
        // stateName = "正在缓冲";
        stateName = "prepared";
        break;
      case FijkState.started:
        // stateName = "正在播放";
        stateName = "playing";
        break;
      case FijkState.paused:
        // stateName = "暂停播放";
        stateName = "paused";
        break;
      case FijkState.completed:
        // stateName = "播放完成";
        stateName = "completed";
        break;
      case FijkState.stopped:
        // stateName = "已停止";
        stateName = "stopped";
        break;
      case FijkState.idle:
        // stateName = "空闲";
        stateName = "idle";
        break;
      case FijkState.error:
        // stateName = "出错";
        stateName = "error";
        break;
      case FijkState.end:
        // stateName = "结束";
        stateName = "end";
        break;
    }
    return stateName;
  }

  void playerValueListener() {
    if (kDebugMode) {
      print("PLAYER STATE changed: " + player.value.toString());
    }
    FijkValue value = player.value;

    if (value.state == FijkState.started && value.size != null) {
      videoRatio.value = value.size!.width / value.size!.height;
    }

    setPlayerStatus(value.state);
  }

  void setPlayerStatus(FijkState state) {
    playerStatus.value = getTextOfPlayerState(state);
  }

  void switchChannel(Channel channel) async {
    Get.snackbar("Switch To", channel.name);
    await player.reset();
    await player.setDataSource(channel.url, autoPlay: true).catchError((e) {
      Get.snackbar("setDataSource error: ", e);
    });
    channelName.value = channel.name;
  }
}
