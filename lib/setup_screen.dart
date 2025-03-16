import 'package:shared_preferences/shared_preferences.dart';
import 'model.dart';
import 'package:flutter/material.dart';
import 'foto_phrame.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<NetworkFolder> _folders = [];
  final _hostController = TextEditingController();
  final _shareController = TextEditingController();
  final _pathController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _folderType = 'SMB';

  @override
  void initState() {
    super.initState();
    _loadSavedFolders();
  }

  Future<void> _loadSavedFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final folderList = prefs.getStringList('folders') ?? [];

    setState(() {
      _folders.clear();
      for (final folderString in folderList) {
        final parts = folderString.split('|');
        if (parts.length == 6) {
          _folders.add(NetworkFolder(
            host: parts[0],
            share: parts[1],
            path: parts[2],
            username: parts[3],
            password: parts[4],
            type: parts[5],
          ));
        }
      }
    });
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final folderList = _folders.map((folder) =>
    '${folder.host}|${folder.share}|${folder.path}|${folder.username}|${folder.password}|${folder.type}'
    ).toList();

    await prefs.setStringList('folders', folderList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Frame Setup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _folders.isEmpty
                ? null
                : () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => FotoPhrame(folders: _folders),
                ),
              );
            },
            tooltip: 'Start Slideshow',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add Network Folders',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _folderType,
                        decoration: const InputDecoration(
                          labelText: 'Folder Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'SMB', child: Text('SMB/CIFS (Windows/NAS)')),
                          DropdownMenuItem(value: 'NFS', child: Text('NFS')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _folderType = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host/IP Address (e.g., 192.168.1.100)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a host';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _shareController,
                        decoration: const InputDecoration(
                          labelText: 'Share Name (e.g., photos)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a share name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _pathController,
                        decoration: const InputDecoration(
                          labelText: 'Path (e.g., /vacation or blank)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        _folders.add(NetworkFolder(
                          host: _hostController.text,
                          share: _shareController.text,
                          path: _pathController.text,
                          username: _usernameController.text,
                          password: _passwordController.text,
                          type: _folderType,
                        ));

                        _hostController.clear();
                        _shareController.clear();
                        _pathController.clear();
                        _usernameController.clear();
                        _passwordController.clear();
                      });

                      _saveFolders();
                    }
                  },
                  child: const Text('Add Folder'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Added Folders:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Flexible(
                  child: ListView.builder(
                    itemCount: _folders.length,
                    shrinkWrap: true,
                    primary: false,
                    itemBuilder: (context, index) {
                      final folder = _folders[index];
                      return ListTile(
                        title: Text('${folder.host}/${folder.share}${folder.path.isNotEmpty ? '/${folder.path}' : ''}'),
                        subtitle: Text('Type: ${folder.type}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              _folders.removeAt(index);
                            });
                            _saveFolders();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}