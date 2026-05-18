import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/engine_controller.dart';
import '../../app/routes.dart';

class ProjectHubScreen extends StatelessWidget {
  const ProjectHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<EngineController>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // IDE dark background
      appBar: AppBar(
        title: const Text('Developer Sandbox Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Row(
        children: [
          // Left Side Menu (Similar to Unity / Unreal Hub)
          Container(
            width: 250,
            color: const Color(0xFF252526),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                ListTile(
                  leading: const Icon(Icons.apps, color: Colors.blueAccent),
                  title: const Text('Projects', style: TextStyle(color: Colors.white)),
                  selected: true,
                  selectedTileColor: Colors.blueAccent.withOpacity(0.1),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.extension, color: Colors.white54),
                  title: const Text('Plugins', style: TextStyle(color: Colors.white54)),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.white54),
                  title: const Text('Installs', style: TextStyle(color: Colors.white54)),
                  onTap: () {},
                ),
              ],
            ),
          ),
          // Main Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Installed Payloads',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D2D30),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.of(context).pushNamed(AppRoutes.uiBuilder);
                            },
                            icon: const Icon(Icons.build),
                            label: const Text('UI Builder IDE'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Add Project - Not Implemented')),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('New Project'),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: engine.installedPayloads.length,
                      itemBuilder: (context, index) {
                        final payload = engine.installedPayloads[index];
                        return Card(
                          color: const Color(0xFF2D2D30),
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: Colors.white12, width: 1),
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: InkWell(
                            onTap: () {
                               engine.loadProject(payload);
                               Navigator.of(context).pushNamed(AppRoutes.visualEditor);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.folder_copy, color: Colors.amberAccent, size: 32),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.more_vert, color: Colors.white54),
                                        onPressed: () {
                                           // Remove / Edit project options
                                        },
                                      )
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    payload.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'v1.0.0 • Local Payload',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      )
    );
  }
}
