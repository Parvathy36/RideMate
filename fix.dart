import 'dart:io';
void main() {
  File file = File('lib/driver_dashboard.dart');
  String text = file.readAsStringSync();
  
  String target1 = '''
  void _showRidesDialog() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      // Get all rides for this driver
      final rides = await FirestoreService.getRidesForUser(user.uid, 'driver');
      if (mounted) {
        _showRidesDialogFromList(rides);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading rides: \')),
        );
      }
    }
  }''';
  
  text = text.replaceAll(target1, '');
  
  String target2 = '''
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],''';
  String replacement2 = '''
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],''';
  
  text = text.replaceAll(target2, replacement2);
  
  file.writeAsStringSync(text);
  print('Replaced!');
}
