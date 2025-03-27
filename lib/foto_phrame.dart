import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:smb_connect/smb_connect.dart';
import 'model.dart';
import 'setup_screen.dart';

class FotoPhrame extends StatefulWidget {
  final List<NetworkFolder> folders;

  const FotoPhrame({Key? key, required this.folders}) : super(key: key);

  @override
  State<FotoPhrame> createState() => _FotoPhrameState();
}

class _FotoPhrameState extends State<FotoPhrame> {
  List<PhotoInfo> _allPhotos = [];
  List<ImageProvider> _preloadedImages = [];
  int _currentIndex = 0;
  bool _loading = true;
  Timer? _slideTimer;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeFotoPhrame();
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeFotoPhrame() async {
    await _scanNetworkFolders();

    if (_allPhotos.isNotEmpty) {
      await _preloadImages(3); // Preload first 3 images

      // Start slideshow timer
      _slideTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _showNextPhoto();
      });

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _scanNetworkFolders() async {
    setState(() {
      _loading = true;
      _allPhotos = [];
    });

    for (final folder in widget.folders) {
      try {
        final List<PhotoInfo> photos = await _getPhotosFromFolder(folder);
        _allPhotos.addAll(photos);
      } catch (e) {
        print('Error scanning folder ${folder.host}/${folder.share}: $e');
      }
    }

    // Shuffle the photos
    _allPhotos.shuffle(_random);
  }

  Future<List<PhotoInfo>> _getPhotosFromFolder(NetworkFolder folder) async {
    final List<PhotoInfo> photos = [];

    try {
      if (folder.type == 'SMB') {
        // Connect to SMB share using smb_connect
        final smbConnection = await SmbConnect.connectAuth(
          host: folder.host,
          domain: '',
          username: folder.username,
          password: folder.password,
        );

        // List files in the directory
        final String directoryPath =
        folder.path.startsWith('/') ? folder.path : '/${folder.path}';

        SmbFile directory = await smbConnection.file(directoryPath);

        List<SmbFile> filesResponse = await smbConnection.listFiles(directory);

        // Filter for image files
        for (final file in filesResponse) {
          final String fullPath = '$directoryPath/${file.name}';

          if (_isImageFile(file.name) && !file.isDirectory()) {
            // For simplicity, we'll determine portrait/landscape later when loading
            photos.add(
              PhotoInfo(
                folder: folder,
                path: fullPath,
                isPortrait: null, // Will be determined when loading
              ),
            );
          } else if (file.isDirectory() &&
              file.name != '.' &&
              file.name != '..') {
            // Recursively scan subdirectories
            final subFolder = NetworkFolder(
              host: folder.host,
              share: folder.share,
              path: '$directoryPath/${file.name}',
              username: folder.username,
              password: folder.password,
              type: folder.type,
            );
            final subPhotos = await _getPhotosFromFolder(subFolder);
            photos.addAll(subPhotos);
          }
        }
      } else if (folder.type == 'NFS') {
        // NFS implementation would go here
        // This is a placeholder for NFS implementation
      }
    } catch (e) {
      print('Error accessing network folder: $e');
    }

    return photos;
  }

  bool _isImageFile(String filename) {
    final lowerCaseName = filename.toLowerCase();
    return lowerCaseName.endsWith('.jpg') ||
        lowerCaseName.endsWith('.jpeg') ||
        lowerCaseName.endsWith('.png') ||
        lowerCaseName.endsWith('.gif');
  }

  Future<void> _preloadImages(int count) async {
    for (int i = 0; i < count && i < _allPhotos.length; i++) {
      final index = (_currentIndex + i) % _allPhotos.length;

      if (index >= _preloadedImages.length) {
        try {
          final photoInfo = _allPhotos[index];

          // Load image and determine orientation
          final imageData = await _loadImageData(photoInfo);
          final image = MemoryImage(imageData);

          // Determine if portrait by decoding the image
          final isPortrait = await _isImagePortrait(imageData);

          // Update the photo info with orientation data
          _allPhotos[index] = PhotoInfo(
            folder: photoInfo.folder,
            path: photoInfo.path,
            isPortrait: isPortrait,
          );

          setState(() {
            _preloadedImages.add(image);
          });
        } catch (e) {
          print('Error preloading image: $e');
          // Remove the problematic image from the list
          _allPhotos.removeAt(index);
          i--; // Try again with the next image
        }
      }
    }
  }

  Future<Uint8List> _loadImageData(PhotoInfo photoInfo) async {
    final folder = photoInfo.folder;

    if (folder.type == 'SMB') {
      try {
        // Connect to SMB share
        final smbConnection = await SmbConnect.connectAuth(
          host: folder.host,
          domain: '',
          username: folder.username,
          password: folder.password,
        );

        // Download the file
        SmbFile downloadFile = await smbConnection.file(photoInfo.path);
        Stream<Uint8List> reader = await smbConnection.openRead(downloadFile);

        final bytesBuilder = BytesBuilder();

        // Listen to the stream and collect all chunks
        await for (final chunk in reader) {
          bytesBuilder.add(chunk);
        }

        // Return the complete Uint8List
        return bytesBuilder.takeBytes();
      } catch (e) {
        throw Exception('Error loading image from SMB: $e');
      }
    } else if (folder.type == 'NFS') {
      // NFS implementation would go here
      throw Exception('NFS not implemented yet');
    } else {
      throw Exception('Unsupported folder type: ${folder.type}');
    }
  }

  Future<bool> _isImagePortrait(Uint8List imageData) async {
    final completer = Completer<bool>();

    final image = Image.memory(imageData);
    image.image
        .resolve(const ImageConfiguration())
        .addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        final width = info.image.width;
        final height = info.image.height;
        completer.complete(height > width);
      }),
    );

    return completer.future;
  }

  void _showNextPhoto() async {
    if (_allPhotos.isEmpty) return;

    // Preload more images if needed
    if (_preloadedImages.length <= _currentIndex + 2) {
      await _preloadImages(2);
    }

    setState(() {
      _currentIndex = (_currentIndex + 1) % _preloadedImages.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading photos...'),
            ],
          ),
        ),
      );
    }

    if (_allPhotos.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No photos found in the specified folders.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SetupScreen(),
                    ),
                  );
                },
                child: const Text('Back to Setup'),
              ),
            ],
          ),
        ),
      );
    }

    // Check if we need to display two portrait images side by side
    if (_currentIndex < _allPhotos.length &&
        _allPhotos[_currentIndex].isPortrait == true) {
      // Find another portrait image if available
      int? secondPortraitIndex;
      for (int i = 0; i < _allPhotos.length; i++) {
        if (i != _currentIndex &&
            i < _preloadedImages.length &&
            _allPhotos[i].isPortrait == true) {
          secondPortraitIndex = i;
          break;
        }
      }

      if (secondPortraitIndex != null) {
        // Display two portrait images side by side
        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: _showNextPhoto,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: _preloadedImages[_currentIndex],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: _preloadedImages[secondPortraitIndex],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Display a single image (landscape or portrait)
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _showNextPhoto,
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: _preloadedImages[_currentIndex],
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}