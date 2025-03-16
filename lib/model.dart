class NetworkFolder {
  final String host;
  final String share;
  final String path;
  final String username;
  final String password;
  final String type;

  NetworkFolder({
    required this.host,
    required this.share,
    required this.path,
    required this.username,
    required this.password,
    required this.type,
  });
}

class PhotoInfo {
  final NetworkFolder folder;
  final String path;
  final bool? isPortrait;

  PhotoInfo({
    required this.folder,
    required this.path,
    required this.isPortrait,
  });
}