import 'package:fijkplayer/fijkplayer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';

import '../data/channel.dart';

class Player extends StatefulWidget {
  const Player({Key? key}) : super(key: key);

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  final FijkPlayer player = FijkPlayer();

  @override
  void initState() {
    super.initState();
    player.setDataSource(
      "http://iptv.tvfix.org/hls/natlgeo.m3u8",
      autoPlay: true,
    );
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
  ];

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
          child: const Text("电视"),
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
                    Get.snackbar(channel.url, "hi");
                    await player.reset();
                    await player.setDataSource(channel.url, autoPlay: true);
                  },
                  child: Container(
                    color: Colors.teal[200],
                    margin: const EdgeInsets.all(1.0),
                    child: Center(
                      child: Text(
                        channel.name,
                        style: const TextStyle(
                          fontSize: 28.0,
                          color: Colors.white,
                        ),
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
