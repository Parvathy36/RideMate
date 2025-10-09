# Google Maps Route Selection Example

This example demonstrates how to implement multiple route selection with Google Maps in Flutter.

## Features

1. Fetches multiple routes using Google Directions API
2. Properly decodes polyline points for accurate route display
3. Sorts routes by distance (shortest first)
4. Displays routes in a bottom sheet for user selection
5. Highlights the selected route on the map
6. Shows distance and duration for each route option

## How to Use

1. Add the `route_selection_example.dart` file to your project
2. Make sure you have the required dependencies in your `pubspec.yaml`:
   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     google_maps_flutter: ^2.9.0
     http: ^1.2.1
   ```
3. Add your Google Maps API key to your platform-specific configurations:
   - Android: `android/app/src/main/AndroidManifest.xml`
   - iOS: `ios/Runner/AppDelegate.swift`
   - Web: `web/index.html`

4. Import and use the `RouteSelectionExample` widget in your app:
   ```dart
   import 'route_selection_example.dart';
   
   // In your widget tree
   const RouteSelectionExample()
   ```

## Key Implementation Details

### Polyline Decoding
The example properly decodes Google Maps polyline strings using the `_decodePolyline` method:

```dart
List<LatLng> _decodePolyline(String encoded) {
  // Implementation that correctly converts encoded strings to LatLng points
}
```

### Multiple Routes
The Google Directions API is called with `alternatives=true` to get multiple route options:

```dart
final url = Uri.parse(
  'https://maps.googleapis.com/maps/api/directions/json'
  '?origin=${origin.latitude},${origin.longitude}'
  '&destination=${destination.latitude},${destination.longitude}'
  '&key=$apiKey'
  '&alternatives=true' // This parameter is key for multiple routes
  '&mode=driving'
  '&units=metric'
);
```

### Route Selection UI
A bottom sheet interface allows users to select between different route options, with clear display of distance and duration:

```dart
void _showRouteSelectionBottomSheet() {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      // Route selection UI with distance and duration
    },
  );
}
```

## Customization

You can easily customize:
1. The source and destination locations by modifying `_source` and `_destination` constants
2. The map styling by modifying the `GoogleMap` widget properties
3. The route selection UI in the bottom sheet
4. The highlighting colors for selected vs. alternative routes

## Troubleshooting

1. **Straight lines appearing**: Make sure polyline decoding is working correctly and that you're using the `points` from the decoded polyline rather than just start/end points.

2. **No routes showing**: Verify your Google Maps API key is correctly configured and that the Directions API is enabled in the Google Cloud Console.

3. **Only one route showing**: Ensure you're using the `alternatives=true` parameter in your API request.