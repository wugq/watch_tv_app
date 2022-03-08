import 'package:fijkplayer/fijkplayer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/data/channel.dart';
import 'package:tv/pages/add_channel_screen/controller/add_channel_controller.dart';

class HomeScreenController extends FullLifeCycleController {
  final appLifecycleState = AppLifecycleState.resumed.obs;

  final FijkPlayer player = FijkPlayer();
  var videoRatio = 1.7777.obs;

  var channelName = "请选择电视台".obs;
  var playerStatus = "".obs;

  addChannel(Channel channel) {
    sourceList.add(channel);
  }

  List<Channel> sourceList = [
    Channel(name: "国家地理", url: "http://iptv.tvfix.org/hls/natlgeo.m3u8"),
    Channel(name: "Discovery", url: "http://iptv.tvfix.org/hls/discovery.m3u8"),
    Channel(name: "动物星球", url: "http://iptv.tvfix.org/hls/animal.m3u8"),
    Channel(name: "动物星球 2", url: "http://iptv.tvfix.org/hls/animal2.m3u8"),
    Channel(
        name: "Love Nature",
        url: "http://iptv.tvfix.org/hls/lovenature4k.m3u8"),
    Channel(
        name: "Love Nature 2",
        url: "http://iptv.tvfix.org/hls/lovenature4k2.m3u8"),
    Channel(
        name: "BBC World",
        url:
            "http://103.199.161.254/Content/bbcworld/Live/Channel(BBCworld)/index.m3u8")
  ].obs;

  @override
  void onReady() {
    WidgetsBinding.instance?.addObserver(this);

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
    player.pause();
  }

  String getTextOfPlayerState(FijkState state) {
    String stateName = "";
    switch (state) {
      case FijkState.initialized:
        stateName = "初始化播放器";
        break;
      case FijkState.asyncPreparing:
        stateName = "准备播放";
        break;
      case FijkState.prepared:
        stateName = "正在缓冲";
        break;
      case FijkState.started:
        stateName = "正在播放";
        break;
      case FijkState.paused:
        stateName = "暂停播放";
        break;
      case FijkState.completed:
        stateName = "播放完成";
        break;
      case FijkState.stopped:
        stateName = "已停止";
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
    Get.snackbar("切换到", channel.name);
    await player.reset();
    await player.setDataSource(channel.url, autoPlay: true).catchError((e) {
      Get.snackbar("setDataSource error: ", e);
    });
    channelName.value = channel.name;
  }
}
