import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'mbtiles_db.dart';

class MbTilesTileProvider extends TileProvider {
  final MbTilesDb db;
  MbTilesTileProvider(this.db);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final bytes = db.getTileBytes(
      z: coordinates.z.round(),
      x: coordinates.x.round(),
      yIsXyz: coordinates.y.round(),
    );
    
    if (bytes == null || bytes.isEmpty) {
      // Return a transparent pixel if missing
      return MemoryImage(_transparentPng);
    }
    
    // Validate that the bytes look like a valid image
    if (!_isValidImageData(bytes)) {
      // Return transparent pixel for invalid data
      return MemoryImage(_transparentPng);
    }
    
    return _SafeTileImage(bytes);
  }
  
  /// Check if bytes look like valid image data (PNG or JPEG header).
  bool _isValidImageData(Uint8List bytes) {
    if (bytes.length < 8) return false;
    
    // Check PNG signature: 89 50 4E 47 0D 0A 1A 0A
    final isPng = bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
    
    // Check JPEG signature: FF D8 FF
    final isJpeg = bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    
    // Check WebP signature: RIFF....WEBP
    final isWebP = bytes.length >= 12 &&
        bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46 && // F
        bytes[8] == 0x57 && // W
        bytes[9] == 0x45 && // E
        bytes[10] == 0x42 && // B
        bytes[11] == 0x50;  // P
    
    return isPng || isJpeg || isWebP;
  }
}

/// A safe image provider that catches decode errors.
class _SafeTileImage extends ImageProvider<_SafeTileImage> {
  final Uint8List bytes;
  
  _SafeTileImage(this.bytes);

  @override
  Future<_SafeTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_SafeTileImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(_SafeTileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () sync* {
        yield ErrorDescription('Tile image');
      },
    );
  }

  Future<ui.Codec> _loadAsync(_SafeTileImage key, ImageDecoderCallback decode) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(key.bytes);
      return decode(buffer);
    } catch (e) {
      // If decoding fails, return the transparent pixel
      debugPrint('Tile decode error: $e');
      final buffer = await ui.ImmutableBuffer.fromUint8List(_transparentPng);
      return decode(buffer);
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _SafeTileImage && other.bytes == bytes;
  }

  @override
  int get hashCode => bytes.hashCode;
}

// A single transparent PNG pixel
final Uint8List _transparentPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  0x00, 0x00, 0x00, 0x0D, // IHDR chunk length
  0x49, 0x48, 0x44, 0x52, // IHDR
  0x00, 0x00, 0x00, 0x01, // width = 1
  0x00, 0x00, 0x00, 0x01, // height = 1
  0x08, 0x06, // bit depth = 8, color type = 6 (RGBA)
  0x00, 0x00, 0x00, // compression, filter, interlace
  0x1F, 0x15, 0xC4, 0x89, // CRC
  0x00, 0x00, 0x00, 0x0A, // IDAT chunk length
  0x49, 0x44, 0x41, 0x54, // IDAT
  0x78, 0x9C, 0x63, 0x60, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, // compressed data
  0xE2, 0x26, 0x05, 0x9B, // CRC
  0x00, 0x00, 0x00, 0x00, // IEND chunk length
  0x49, 0x45, 0x4E, 0x44, // IEND
  0xAE, 0x42, 0x60, 0x82, // CRC
]);
