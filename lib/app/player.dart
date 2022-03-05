import 'package:fijkplayer/fijkplayer.dart';
import 'package:flutter/material.dart';
import "package:auto_size_text/auto_size_text.dart";
import 'package:get/get.dart';

import '../data/channel.dart';

class Player extends StatefulWidget {
  const Player({Key? key}) : super(key: key);

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  final FijkPlayer player = FijkPlayer();

  String title = "国家地理";

  @override
  void initState() {
    super.initState();
    player
        .setDataSource("http://iptv.tvfix.org/hls/natlgeo.m3u8", autoPlay: true)
        .catchError((e) {
      Get.snackbar("setDataSource error: ", e);
    });
  }

  @override
  void dispose() {
    super.dispose();
    // player.removeListener(_fijkValueListener);
    player.release();
  }

  List<Channel> sourceList = [
    Channel("国家地理", "http://iptv.tvfix.org/hls/natlgeo.m3u8"),
    Channel("动物星球", "http://iptv.tvfix.org/hls/animal.m3u8"),
    Channel("Discovery", "http://iptv.tvfix.org/hls/discovery.m3u8"),
    Channel("动物星球 2", "http://iptv.tvfix.org/hls/animal2.m3u8"),

    Channel("Hands Up Channel", "http://iptv.tvfix.org/hls/kid.m3u8"),
    Channel("Hands Up Channel 2", "http://iptv.tvfix.org/hls/kid2.m3u8"),
    Channel("Thrill", "http://iptv.tvfix.org/hls/thrill.m3u8"),
    Channel("Thrill 2", "http://iptv.tvfix.org/hls/thrill2.m3u8"),
    Channel("Love Nature", "http://iptv.tvfix.org/hls/lovenature4k.m3u8"),
    Channel("Love Nature 2", "http://iptv.tvfix.org/hls/lovenature4k2.m3u8"),
    Channel("Channel V", "http://iptv.tvfix.org/hls/channelv.m3u8"),
  ];

  updateTitle(channelName) {
    setState(() {
      title = channelName;
    });
  }

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;
    const videoRatio = 480 / 270;
    FijkFit fit = const FijkFit(
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
          child: Text("正在观看：" + title),
        ),
        Expanded(
          child: Container(
            width: MediaQuery.of(context).size.width,
            color: Colors.teal[600],
            child: GridView.count(
              padding: const EdgeInsets.all(10),
              childAspectRatio: 16 / 8,
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
