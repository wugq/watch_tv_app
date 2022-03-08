import 'package:fijkplayer/fijkplayer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import "package:auto_size_text/auto_size_text.dart";
import 'package:get/get.dart';
import 'package:tv/app/widgets/category_selector.dart';

import '../data/channel.dart';

class Player extends StatefulWidget {
  const Player({Key? key}) : super(key: key);

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> with WidgetsBindingObserver {
  late AppLifecycleState _appLifecycleState;
  late FijkValue _playerState;
  double videoRatio = 480 / 270;

  final FijkPlayer player = FijkPlayer();
  String title = "请选择电视台";
  String playerStatus = "";

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _appLifecycleState = state;
    });

    if (kDebugMode) {
      print("AppLifecycleState is: " + state.toString());
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      playerPause();
    }
  }

  void playerPause() {
    if (player.state == FijkState.started) {
      player.pause();
    }
  }

  void _playerValueListener() {
    if (kDebugMode) {
      print("PLAYER STATE changed: " + player.value.toString());
    }

    FijkValue value = player.value;
    setState(() {
      _playerState = value;
    });

    if (value.state == FijkState.started && value.size != null) {
      setVideoRatio(value.size!.width, value.size!.height);
    }

    _setPlayerStatus(player.state);
  }

  void _setPlayerStatus(FijkState state) {
    String statusName = "";
    switch (state) {
      case FijkState.initialized:
        statusName = "初始化播放器";
        break;
      case FijkState.asyncPreparing:
        statusName = "准备播放";
        break;
      case FijkState.prepared:
        statusName = "正在缓冲";
        break;
      case FijkState.started:
        statusName = "正在播放";
        break;
      case FijkState.paused:
        statusName = "暂停播放";
        break;
      case FijkState.completed:
        statusName = "播放完成";
        break;
      case FijkState.stopped:
        statusName = "已停止";
        break;
    }
    setState(() {
      playerStatus = statusName;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    player.addListener(_playerValueListener);
    player.setOption(FijkOption.hostCategory, "request-screen-on", 1);
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance?.removeObserver(this);
    player.removeListener(_playerValueListener);
    player.release();
  }

  List<Channel> sourceList = [
    Channel(name: "国家地理", url: "http://iptv.tvfix.org/hls/natlgeo.m3u8"),
  ];

  updateTitle(channelName) {
    setState(() {
      title = channelName;
    });
  }

  setVideoRatio(double width, double height) {
    setState(() {
      videoRatio = width / height;
    });
  }

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;
    FijkFit fit = FijkFit(
      sizeFactor: 1.0,
      aspectRatio: videoRatio,
      alignment: Alignment.center,
    );
    return Column(
      children: [
        SizedBox(
          height: screenSize.width / videoRatio,
          child: FijkView(
            color: Colors.black,
            fit: fit,
            player: player,
          ),
        ),
        Container(
          width: MediaQuery.of(context).size.width,
          color: Colors.teal[500],
          padding: const EdgeInsets.all(10),
          child: Text(playerStatus + " " + title),
        ),
        // const CategorySelector(height: 40),
        Expanded(
          child: Container(
            width: MediaQuery.of(context).size.width,
            color: Colors.teal[600],
            child: GridView.count(
              padding: const EdgeInsets.all(10),
              childAspectRatio: 16 / 6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              crossAxisCount: 2,
              // shrinkWrap: true,
              children: sourceList.map((Channel channel) {
                return InkWell(
                  onTap: () async {
                    Get.snackbar("切换到", channel.name);
                    await player.reset();
                    await player
                        .setDataSource(channel.url, autoPlay: true)
                        .catchError((e) {
                      Get.snackbar("setDataSource error: ", e);
                    });
                    updateTitle(channel.name);
                  },
                  child: Container(
                    color: Colors.teal[200],
                    margin: const EdgeInsets.all(1.0),
                    child: Center(
                      child: AutoSizeText(
                        channel.name,
                        style: const TextStyle(
                          fontSize: 28.0,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        )
      ],
    );
  }
}
