import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../logging/logger.dart';
import '../types/geo.dart' as core_geo;

class PathResult {
  final List<ll.LatLng> points;
  final double lengthMeters;
  const PathResult({required this.points, required this.lengthMeters});
}

/// Cached graph to avoid rebuilding on every path computation
_Graph? _cachedGraph;
int _cachedWalkwaysHashCode = 0;

/// Clear the cached graph (useful for testing or when walkways change)
void clearPathfinderCache() {
  _cachedGraph = null;
  _cachedWalkwaysHashCode = 0;
}

/// Compute a simple hash for walkways list to detect changes
int _computeWalkwaysHash(List<Polyline> walkways) {
  var hash = walkways.length;
  for (final poly in walkways) {
    hash ^= poly.points.length;
    if (poly.points.isNotEmpty) {
      final first = poly.points.first;
      hash ^= (first.latitude * 1000000).toInt();
      hash ^= (first.longitude * 1000000).toInt();
    }
  }
  return hash;
}

PathResult? computeWalkwayPath(
  List<Polyline> walkways,
  ll.LatLng start,
  ll.LatLng end,
) {
  if (walkways.isEmpty) {
    logWarn('computeWalkwayPath: no walkways supplied');
    return null;
  }

  // Check if we can use cached graph
  final walkwaysHash = _computeWalkwaysHash(walkways);
  _Graph graph;
  
  if (_cachedGraph != null && _cachedWalkwaysHashCode == walkwaysHash) {
    graph = _cachedGraph!;
  } else {
    // Build new graph and cache it
    final graphBuilder = _GraphBuilder();
    for (final poly in walkways) {
      final pts = poly.points;
      for (var i = 0; i < pts.length - 1; i++) {
        graphBuilder.addEdge(pts[i], pts[i + 1]);
      }
    }
    graph = graphBuilder.build();
    _cachedGraph = graph;
    _cachedWalkwaysHashCode = walkwaysHash;
    logDebug('Pathfinder: Built and cached graph with ${graph.nodes.length} nodes');
  }
  
  if (graph.nodes.isEmpty) {
    logWarn('computeWalkwayPath: walkway graph is empty');
    return null;
  }

  final startNode = graph.findNearestNode(start);
  final endNode = graph.findNearestNode(end);
  if (startNode == null || endNode == null) {
    logWarn('computeWalkwayPath: unable to locate start or end node');
    return null;
  }

  final pathIndices = _dijkstraOptimized(graph, startNode, endNode);
  if (pathIndices == null || pathIndices.isEmpty) {
    logWarn('computeWalkwayPath: no route found between nodes');
    return null;
  }

  final points = <ll.LatLng>[];
  final nodes = graph.nodes;
  for (final index in pathIndices) {
    points.add(nodes[index]!.coord);
  }

  if (_distanceBetween(points.first, start) > 1.0) {
    points.insert(0, start);
  } else {
    points[0] = start;
  }
  if (_distanceBetween(points.last, end) > 1.0) {
    points.add(end);
  } else {
    points[points.length - 1] = end;
  }

  var total = 0.0;
  for (var i = 0; i < points.length - 1; i++) {
    total += _distanceBetween(points[i], points[i + 1]);
  }

  return PathResult(points: points, lengthMeters: total);
}

class _GraphBuilder {
  final Map<String, _NodeBuilder> _nodes = {};

  void addEdge(ll.LatLng a, ll.LatLng b) {
    final nodeA = _nodes.putIfAbsent(_key(a), () => _NodeBuilder(a));
    final nodeB = _nodes.putIfAbsent(_key(b), () => _NodeBuilder(b));
    final distance = _distanceBetween(a, b);
    if (distance <= 0) return;
    nodeA.addNeighbor(nodeB, distance);
    nodeB.addNeighbor(nodeA, distance);
  }

  _Graph build() {
    final nodes = <int, _GraphNode>{};
    var index = 0;
    for (final builder in _nodes.values) {
      nodes[index] = _GraphNode(index, builder.coord);
      builder.index = index;
      index += 1;
    }
    for (final builder in _nodes.values) {
      final node = nodes[builder.index]!;
      for (final entry in builder.neighbors.entries) {
        final neighbor = entry.key;
        final weight = entry.value;
        if (neighbor.index == null) continue;
        node.addEdge(neighbor.index!, weight);
      }
    }

    const thresholdMeters = 2.0;
    final entries = nodes.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final a = entries[i].value;
      for (var j = i + 1; j < entries.length; j++) {
        final b = entries[j].value;
        final distance = _distanceBetween(a.coord, b.coord);
        if (distance > 0 && distance <= thresholdMeters) {
          a.addEdge(b.index, distance);
          b.addEdge(a.index, distance);
        }
      }
    }

    return _Graph(nodes);
  }

  String _key(ll.LatLng coord) {
    final lat = coord.latitude.toStringAsFixed(9);
    final lng = coord.longitude.toStringAsFixed(9);
    return '${lat}_$lng';
  }
}

class _NodeBuilder {
  final ll.LatLng coord;
  final Map<_NodeBuilder, double> neighbors = {};
  int? index;

  _NodeBuilder(this.coord);

  void addNeighbor(_NodeBuilder other, double distance) {
    if (other == this) return;
    neighbors[other] = math.min(neighbors[other] ?? double.infinity, distance);
  }
}

class _Graph {
  final Map<int, _GraphNode> nodes;
  _Graph(this.nodes);

  int? findNearestNode(ll.LatLng coord) {
    var bestIndex = -1;
    var bestDistance = double.infinity;
    nodes.forEach((index, node) {
      final d = _distanceBetween(node.coord, coord);
      if (d < bestDistance) {
        bestDistance = d;
        bestIndex = index;
      }
    });
    return bestIndex >= 0 ? bestIndex : null;
  }
}

class _GraphNode {
  final int index;
  final ll.LatLng coord;
  final Map<int, double> edges = {};
  _GraphNode(this.index, this.coord);

  void addEdge(int neighbor, double weight) {
    final existing = edges[neighbor];
    if (existing == null || weight < existing) {
      edges[neighbor] = weight;
    }
  }
}

/// Priority queue entry for Dijkstra's algorithm
class _PQEntry implements Comparable<_PQEntry> {
  final int nodeIndex;
  final double distance;
  
  const _PQEntry(this.nodeIndex, this.distance);
  
  @override
  int compareTo(_PQEntry other) => distance.compareTo(other.distance);
}

/// Optimized Dijkstra using a simple sorted list as priority queue
/// with early exit when destination is reached
List<int>? _dijkstraOptimized(_Graph graph, int startIndex, int endIndex) {
  final dist = <int, double>{startIndex: 0};
  final prev = <int, int?>{};
  final visited = <int>{};
  
  // Simple priority queue using sorted insertion
  final pq = <_PQEntry>[_PQEntry(startIndex, 0)];

  while (pq.isNotEmpty) {
    // Get minimum distance node
    final current = pq.removeAt(0);
    final currentIndex = current.nodeIndex;
    
    // Skip if already visited
    if (visited.contains(currentIndex)) continue;
    
    // Early exit: found destination
    if (currentIndex == endIndex) break;
    
    visited.add(currentIndex);
    
    final node = graph.nodes[currentIndex];
    if (node == null) continue;
    
    // Process neighbors
    for (final entry in node.edges.entries) {
      final neighbor = entry.key;
      final weight = entry.value;
      
      if (weight <= 0 || visited.contains(neighbor)) continue;
      
      final alt = dist[currentIndex]! + weight;
      if (alt < (dist[neighbor] ?? double.infinity)) {
        dist[neighbor] = alt;
        prev[neighbor] = currentIndex;
        
        // Insert maintaining sorted order (binary search insertion)
        final newEntry = _PQEntry(neighbor, alt);
        var insertIndex = pq.length;
        for (var i = 0; i < pq.length; i++) {
          if (pq[i].distance > alt) {
            insertIndex = i;
            break;
          }
        }
        pq.insert(insertIndex, newEntry);
      }
    }
  }

  if (!dist.containsKey(endIndex)) {
    return null;
  }

  // Reconstruct path
  final path = Queue<int>();
  var u = endIndex;
  path.addFirst(u);
  while (prev.containsKey(u)) {
    final p = prev[u];
    if (p == null) break;
    u = p;
    path.addFirst(u);
  }
  if (path.first != startIndex) {
    path.addFirst(startIndex);
  }
  return path.toList();
}

double _distanceBetween(ll.LatLng a, ll.LatLng b) {
  return core_geo.haversineMeters(
    core_geo.LatLng(a.latitude, a.longitude),
    core_geo.LatLng(b.latitude, b.longitude),
  );
}
