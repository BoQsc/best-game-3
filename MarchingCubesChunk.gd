extends MeshInstance3D
class_name MarchingCubesChunk

var chunk_coord: Vector3i = Vector3i(0, 0, 0)
var grid_size: int = 32
var scale_factor: float = 1.0
var terrain_height: float = 32.0
var iso_level: float = 0.0
var noise: FastNoiseLite

# Shared resources: built once, reused by every chunk (avoids one material/mesh per chunk).
static var _terrain_material: ShaderMaterial
static var _water_material: ShaderMaterial
static var _water_mesh: PlaneMesh

# We use this to signal the main controller that we are done
signal generation_complete(chunk_coord)

# Tables (Same as before - keeping it collapsed for readability)
const EDGE_TABLE = [0x0, 0x109, 0x203, 0x30a, 0x406, 0x50f, 0x605, 0x70c, 0x80c, 0x905, 0xa0f, 0xb06, 0xc0a, 0xd03, 0xe09, 0xf00, 0x190, 0x99, 0x393, 0x29a, 0x596, 0x49f, 0x795, 0x69c, 0x99c, 0x895, 0xb9f, 0xa96, 0xd9a, 0xc93, 0xf99, 0xe90, 0x230, 0x339, 0x33, 0x13a, 0x636, 0x73f, 0x435, 0x53c, 0xa3c, 0xb35, 0x83f, 0x936, 0xe3a, 0xf33, 0xc39, 0xd30, 0x3a0, 0x2a9, 0x1a3, 0xaa, 0x7a6, 0x6af, 0x5a5, 0x4ac, 0xbac, 0xaa5, 0x9af, 0x8a6, 0xfaa, 0xea3, 0xda9, 0xca0, 0x460, 0x569, 0x663, 0x76a, 0x66, 0x16f, 0x265, 0x36c, 0xc6c, 0xd65, 0xe6f, 0xf66, 0x86a, 0x963, 0xa69, 0xb60, 0x5f0, 0x4f9, 0x7f3, 0x6fa, 0x1f6, 0xff, 0x3f5, 0x2fc, 0xdfc, 0xcf5, 0xfff, 0xef6, 0x9fa, 0x8f3, 0xbf9, 0xaf0, 0x650, 0x759, 0x453, 0x55a, 0x256, 0x35f, 0x55, 0x15c, 0xe5c, 0xf55, 0xc5f, 0xd56, 0xa5a, 0xb53, 0x859, 0x950, 0x7c0, 0x6c9, 0x5c3, 0x4ca, 0x3c6, 0x2cf, 0x1c5, 0xcc, 0xfcc, 0xec5, 0xdcf, 0xcc6, 0xbca, 0xac3, 0x9c9, 0x8c0, 0x8c0, 0x9c9, 0xac3, 0xbca, 0xcc6, 0xdcf, 0xec5, 0xfcc, 0xcc, 0x1c5, 0x2cf, 0x3c6, 0x4ca, 0x5c3, 0x6c9, 0x7c0, 0x950, 0x859, 0xb53, 0xa5a, 0xd56, 0xc5f, 0xf55, 0xe5c, 0x15c, 0x55, 0x35f, 0x256, 0x55a, 0x453, 0x759, 0x650, 0xaf0, 0xbf9, 0x8f3, 0x9fa, 0xef6, 0xfff, 0xcf5, 0xdfc, 0x2fc, 0x3f5, 0xff, 0x1f6, 0x6fa, 0x7f3, 0x4f9, 0x5f0, 0xb60, 0xa69, 0x963, 0x86a, 0xf66, 0xe6f, 0xd65, 0xc6c, 0x36c, 0x265, 0x16f, 0x66, 0x76a, 0x663, 0x569, 0x460, 0xca0, 0xda9, 0xea3, 0xfaa, 0x8a6, 0x9af, 0xaa5, 0xbac, 0x4ac, 0x5a5, 0x6af, 0x7a6, 0xaa, 0x1a3, 0x2a9, 0x3a0, 0xd30, 0xc39, 0xf33, 0xe3a, 0x936, 0x83f, 0xb35, 0xa3c, 0x53c, 0x435, 0x73f, 0x636, 0x13a, 0x33, 0x339, 0x230, 0xe90, 0xf99, 0xc93, 0xd9a, 0xa96, 0xb9f, 0x895, 0x99c, 0x69c, 0x795, 0x49f, 0x596, 0x29a, 0x393, 0x99, 0x190, 0xf00, 0xe09, 0xd03, 0xc0a, 0xb06, 0xa0f, 0x905, 0x80c, 0x70c, 0x605, 0x50f, 0x406, 0x30a, 0x203, 0x109, 0x0]
const TRI_TABLE = [[-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 8, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 1, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[1, 8, 3, 9, 8, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[1, 2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 8, 3, 1, 2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[9, 2, 10, 0, 2, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[2, 8, 3, 2, 10, 8, 10, 9, 8, -1, -1, -1, -1, -1, -1, -1],[3, 11, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 11, 2, 8, 11, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[1, 9, 0, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[1, 11, 2, 1, 9, 11, 9, 8, 11, -1, -1, -1, -1, -1, -1, -1],[3, 10, 1, 11, 10, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 10, 1, 0, 8, 10, 8, 11, 10, -1, -1, -1, -1, -1, -1, -1],[3, 9, 0, 3, 11, 9, 11, 10, 9, -1, -1, -1, -1, -1, -1, -1],[9, 8, 10, 10, 8, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[4, 7, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[4, 3, 0, 7, 3, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 1, 9, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[4, 1, 9, 4, 7, 1, 7, 3, 1, -1, -1, -1, -1, -1, -1, -1],[1, 2, 10, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[3, 4, 7, 3, 0, 4, 1, 2, 10, -1, -1, -1, -1, -1, -1, -1],[9, 2, 10, 9, 0, 2, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1],[2, 10, 9, 2, 9, 7, 2, 7, 3, 7, 9, 4, -1, -1, -1, -1],[8, 4, 7, 3, 11, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[11, 4, 7, 11, 2, 4, 2, 0, 4, -1, -1, -1, -1, -1, -1, -1],[9, 0, 1, 8, 4, 7, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1],[4, 7, 11, 9, 4, 11, 9, 11, 2, 9, 2, 1, -1, -1, -1, -1],[3, 10, 1, 3, 11, 10, 7, 8, 4, -1, -1, -1, -1, -1, -1, -1],[1, 11, 10, 1, 4, 11, 1, 0, 4, 7, 11, 4, -1, -1, -1, -1],[4, 7, 8, 9, 0, 11, 9, 11, 10, 11, 0, 3, -1, -1, -1, -1],[4, 7, 11, 4, 11, 9, 9, 11, 10, -1, -1, -1, -1, -1, -1, -1],[9, 5, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[9, 5, 4, 0, 8, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 5, 4, 1, 5, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[8, 5, 4, 8, 3, 5, 3, 1, 5, -1, -1, -1, -1, -1, -1, -1],[1, 2, 10, 9, 5, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[3, 0, 8, 1, 2, 10, 4, 9, 5, -1, -1, -1, -1, -1, -1, -1],[5, 2, 10, 5, 4, 2, 4, 0, 2, -1, -1, -1, -1, -1, -1, -1],[2, 10, 5, 3, 2, 5, 3, 5, 4, 3, 4, 8, -1, -1, -1, -1],[9, 5, 4, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 11, 2, 0, 8, 11, 4, 9, 5, -1, -1, -1, -1, -1, -1, -1],[0, 5, 4, 0, 1, 5, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1],[2, 1, 5, 2, 5, 8, 2, 8, 11, 4, 8, 5, -1, -1, -1, -1],[10, 3, 11, 10, 1, 3, 9, 5, 4, -1, -1, -1, -1, -1, -1, -1],[4, 9, 5, 0, 8, 1, 8, 10, 1, 8, 11, 10, -1, -1, -1, -1],[5, 4, 0, 5, 0, 11, 5, 11, 10, 11, 0, 3, -1, -1, -1, -1],[5, 4, 8, 5, 8, 10, 10, 8, 11, -1, -1, -1, -1, -1, -1, -1],[9, 7, 8, 5, 7, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[9, 3, 0, 9, 5, 3, 5, 7, 3, -1, -1, -1, -1, -1, -1, -1],[0, 7, 8, 0, 1, 7, 1, 5, 7, -1, -1, -1, -1, -1, -1, -1],[1, 5, 3, 3, 5, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[9, 7, 8, 9, 5, 7, 10, 1, 2, -1, -1, -1, -1, -1, -1, -1],[10, 1, 2, 9, 5, 0, 5, 3, 0, 5, 7, 3, -1, -1, -1, -1],[8, 0, 2, 8, 2, 5, 8, 5, 7, 10, 5, 2, -1, -1, -1, -1],[2, 10, 5, 2, 5, 3, 3, 5, 7, -1, -1, -1, -1, -1, -1, -1],[7, 9, 5, 7, 8, 9, 3, 11, 2, -1, -1, -1, -1, -1, -1, -1],[9, 5, 7, 9, 7, 2, 9, 2, 0, 2, 7, 11, -1, -1, -1, -1],[2, 3, 11, 0, 1, 8, 1, 7, 8, 1, 5, 7, -1, -1, -1, -1],[11, 2, 1, 11, 1, 7, 7, 1, 5, -1, -1, -1, -1, -1, -1, -1],[9, 5, 8, 8, 5, 7, 10, 1, 3, 10, 3, 11, -1, -1, -1, -1],[5, 7, 0, 5, 0, 9, 7, 11, 0, 1, 0, 10, 11, 10, 0, -1],[11, 10, 0, 11, 0, 3, 10, 5, 0, 8, 0, 7, 5, 7, 0, -1],[11, 10, 5, 7, 11, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[10, 6, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 8, 3, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[9, 0, 1, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[1, 8, 3, 1, 9, 8, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1],[1, 6, 5, 2, 6, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[1, 6, 5, 1, 2, 6, 3, 0, 8, -1, -1, -1, -1, -1, -1, -1],[9, 6, 5, 9, 0, 6, 0, 2, 6, -1, -1, -1, -1, -1, -1, -1],[5, 9, 8, 5, 8, 2, 5, 2, 6, 3, 2, 8, -1, -1, -1, -1],[2, 3, 11, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[11, 0, 8, 11, 2, 0, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1],[0, 1, 9, 2, 3, 11, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1],[5, 10, 6, 1, 9, 2, 9, 11, 2, 9, 8, 11, -1, -1, -1, -1],[6, 3, 11, 6, 5, 3, 5, 1, 3, -1, -1, -1, -1, -1, -1, -1],[0, 8, 11, 0, 11, 5, 0, 5, 1, 5, 11, 6, -1, -1, -1, -1],[3, 11, 6, 0, 3, 6, 0, 6, 5, 0, 5, 9, -1, -1, -1, -1],[6, 5, 9, 6, 9, 11, 11, 9, 8, -1, -1, -1, -1, -1, -1, -1],[5, 10, 6, 4, 7, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[4, 3, 0, 4, 7, 3, 6, 5, 10, -1, -1, -1, -1, -1, -1, -1],[1, 9, 0, 5, 10, 6, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1],[10, 6, 5, 1, 9, 7, 1, 7, 3, 7, 9, 4, -1, -1, -1, -1],[6, 1, 2, 6, 5, 1, 4, 7, 8, -1, -1, -1, -1, -1, -1, -1],[1, 2, 5, 5, 2, 6, 3, 0, 4, 3, 4, 7, -1, -1, -1, -1],[8, 4, 7, 9, 0, 5, 0, 6, 5, 0, 2, 6, -1, -1, -1, -1],[7, 3, 9, 7, 9, 4, 3, 2, 9, 5, 9, 6, 2, 6, 9, -1],[3, 11, 2, 7, 8, 4, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1],[5, 10, 6, 4, 7, 2, 4, 2, 0, 2, 7, 11, -1, -1, -1, -1],[0, 1, 9, 4, 7, 8, 2, 3, 11, 5, 10, 6, -1, -1, -1, -1],[9, 2, 1, 9, 11, 2, 9, 4, 11, 7, 11, 4, 5, 10, 6, -1],[8, 4, 7, 3, 11, 5, 3, 5, 1, 5, 11, 6, -1, -1, -1, -1],[5, 1, 11, 5, 11, 6, 1, 0, 11, 7, 11, 4, 0, 4, 11, -1],[0, 5, 9, 0, 6, 5, 0, 3, 6, 11, 6, 3, 8, 4, 7, -1],[6, 5, 9, 6, 9, 11, 4, 7, 9, 7, 11, 9, -1, -1, -1, -1],[10, 4, 9, 6, 4, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[4, 10, 6, 4, 9, 10, 0, 8, 3, -1, -1, -1, -1, -1, -1, -1],[10, 0, 1, 10, 6, 0, 6, 4, 0, -1, -1, -1, -1, -1, -1, -1],[8, 3, 1, 8, 1, 6, 8, 6, 4, 6, 1, 10, -1, -1, -1, -1],[1, 4, 9, 1, 2, 4, 2, 6, 4, -1, -1, -1, -1, -1, -1, -1],[3, 0, 8, 1, 2, 9, 2, 4, 9, 2, 6, 4, -1, -1, -1, -1],[0, 2, 4, 4, 2, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[8, 3, 2, 8, 2, 4, 4, 2, 6, -1, -1, -1, -1, -1, -1, -1],[10, 4, 9, 10, 6, 4, 11, 2, 3, -1, -1, -1, -1, -1, -1, -1],[0, 8, 2, 2, 8, 11, 4, 9, 10, 4, 10, 6, -1, -1, -1, -1],[3, 11, 2, 0, 1, 6, 0, 6, 4, 6, 1, 10, -1, -1, -1, -1],[6, 4, 1, 6, 1, 10, 4, 8, 1, 2, 1, 11, 8, 11, 1, -1],[9, 6, 4, 9, 3, 6, 9, 1, 3, 11, 6, 3, -1, -1, -1, -1],[8, 11, 1, 8, 1, 0, 11, 6, 1, 9, 1, 4, 6, 4, 1, -1],[3, 11, 6, 3, 6, 0, 0, 6, 4, -1, -1, -1, -1, -1, -1, -1],[6, 4, 8, 11, 6, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[7, 10, 6, 7, 8, 10, 8, 9, 10, -1, -1, -1, -1, -1, -1, -1],[0, 7, 3, 0, 10, 7, 0, 9, 10, 6, 7, 10, -1, -1, -1, -1],[10, 6, 7, 1, 10, 7, 1, 7, 8, 1, 8, 0, -1, -1, -1, -1],[10, 6, 7, 10, 7, 1, 1, 7, 3, -1, -1, -1, -1, -1, -1, -1],[1, 2, 6, 1, 6, 8, 1, 8, 9, 8, 6, 7, -1, -1, -1, -1],[2, 6, 9, 2, 9, 1, 6, 7, 9, 0, 9, 3, 7, 3, 9, -1],[7, 8, 0, 7, 0, 6, 6, 0, 2, -1, -1, -1, -1, -1, -1, -1],[7, 3, 2, 6, 7, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[2, 3, 11, 10, 6, 8, 10, 8, 9, 8, 6, 7, -1, -1, -1, -1],[2, 0, 7, 2, 7, 11, 0, 9, 7, 6, 7, 10, 9, 10, 7, -1],[1, 8, 0, 1, 7, 8, 1, 10, 7, 6, 7, 10, 2, 3, 11, -1],[11, 2, 1, 11, 1, 7, 10, 6, 1, 6, 7, 1, -1, -1, -1, -1],[8, 9, 6, 8, 6, 7, 9, 1, 6, 11, 6, 3, 1, 3, 6, -1],[0, 9, 1, 11, 6, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[7, 8, 0, 7, 0, 6, 3, 11, 0, 11, 6, 0, -1, -1, -1, -1],[7, 11, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[7, 6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[3, 0, 8, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 1, 9, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[8, 1, 9, 8, 3, 1, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1],[10, 1, 2, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[1, 2, 10, 3, 0, 8, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1],[2, 9, 0, 2, 10, 9, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1],[6, 11, 7, 2, 10, 3, 10, 8, 3, 10, 9, 8, -1, -1, -1, -1],[7, 2, 3, 6, 2, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[7, 0, 8, 7, 6, 0, 6, 2, 0, -1, -1, -1, -1, -1, -1, -1],[2, 7, 6, 2, 3, 7, 0, 1, 9, -1, -1, -1, -1, -1, -1, -1],[1, 6, 2, 1, 8, 6, 1, 9, 8, 8, 7, 6, -1, -1, -1, -1],[10, 7, 6, 10, 1, 7, 1, 3, 7, -1, -1, -1, -1, -1, -1, -1],[10, 7, 6, 1, 7, 10, 1, 8, 7, 1, 0, 8, -1, -1, -1, -1],[0, 3, 7, 0, 7, 10, 0, 10, 9, 6, 10, 7, -1, -1, -1, -1],[7, 6, 10, 7, 10, 8, 8, 10, 9, -1, -1, -1, -1, -1, -1, -1],[6, 8, 4, 11, 8, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[3, 6, 11, 3, 0, 6, 0, 4, 6, -1, -1, -1, -1, -1, -1, -1],[8, 6, 11, 8, 4, 6, 9, 0, 1, -1, -1, -1, -1, -1, -1, -1],[9, 4, 6, 9, 6, 3, 9, 3, 1, 11, 3, 6, -1, -1, -1, -1],[6, 8, 4, 6, 11, 8, 2, 10, 1, -1, -1, -1, -1, -1, -1, -1],[1, 2, 10, 3, 0, 11, 0, 6, 11, 0, 4, 6, -1, -1, -1, -1],[4, 11, 8, 4, 6, 11, 0, 2, 9, 2, 10, 9, -1, -1, -1, -1],[10, 9, 3, 10, 3, 2, 9, 4, 3, 11, 3, 6, 4, 6, 3, -1],[8, 2, 3, 8, 4, 2, 4, 6, 2, -1, -1, -1, -1, -1, -1, -1],[0, 4, 2, 4, 6, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[1, 9, 0, 2, 3, 4, 2, 4, 6, 4, 3, 8, -1, -1, -1, -1],[1, 9, 4, 1, 4, 2, 2, 4, 6, -1, -1, -1, -1, -1, -1, -1],[8, 1, 3, 8, 6, 1, 8, 4, 6, 6, 10, 1, -1, -1, -1, -1],[10, 1, 0, 10, 0, 6, 6, 0, 4, -1, -1, -1, -1, -1, -1, -1],[4, 6, 3, 4, 3, 8, 6, 10, 3, 0, 3, 9, 10, 9, 3, -1],[10, 9, 4, 6, 10, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[4, 9, 5, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 8, 3, 4, 9, 5, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1],[5, 0, 1, 5, 4, 0, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1],[11, 7, 6, 8, 3, 4, 3, 5, 4, 3, 1, 5, -1, -1, -1, -1],[9, 5, 4, 10, 1, 2, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1],[6, 11, 7, 1, 2, 10, 0, 8, 3, 4, 9, 5, -1, -1, -1, -1],[7, 6, 11, 5, 4, 10, 4, 2, 10, 4, 0, 2, -1, -1, -1, -1],[3, 4, 8, 3, 5, 4, 3, 2, 5, 10, 5, 2, 11, 7, 6, -1],[7, 2, 3, 7, 6, 2, 5, 4, 9, -1, -1, -1, -1, -1, -1, -1],[9, 5, 4, 0, 8, 6, 0, 6, 2, 6, 8, 7, -1, -1, -1, -1],[3, 6, 2, 3, 7, 6, 1, 5, 0, 5, 4, 0, -1, -1, -1, -1],[6, 2, 8, 6, 8, 7, 2, 1, 8, 4, 8, 5, 1, 5, 8, -1],[9, 5, 4, 10, 1, 6, 1, 7, 6, 1, 3, 7, -1, -1, -1, -1],[1, 6, 10, 1, 7, 6, 1, 0, 7, 8, 7, 0, 9, 5, 4, -1],[4, 0, 10, 4, 10, 5, 0, 3, 10, 6, 10, 7, 3, 7, 10, -1],[7, 6, 10, 7, 10, 8, 5, 4, 10, 4, 8, 10, -1, -1, -1, -1],[6, 9, 5, 6, 11, 9, 11, 8, 9, -1, -1, -1, -1, -1, -1, -1],[3, 6, 11, 0, 6, 3, 0, 5, 6, 0, 9, 5, -1, -1, -1, -1],[0, 11, 8, 0, 5, 11, 0, 1, 5, 5, 6, 11, -1, -1, -1, -1],[6, 11, 3, 6, 3, 5, 5, 3, 1, -1, -1, -1, -1, -1, -1, -1],[1, 2, 10, 9, 5, 11, 9, 11, 8, 11, 5, 6, -1, -1, -1, -1],[0, 11, 3, 0, 6, 11, 0, 9, 6, 5, 6, 9, 1, 2, 10, -1],[11, 8, 5, 11, 5, 6, 8, 0, 5, 10, 5, 2, 0, 2, 5, -1],[6, 11, 3, 6, 3, 5, 2, 10, 3, 10, 5, 3, -1, -1, -1, -1],[5, 8, 9, 5, 2, 8, 5, 6, 2, 3, 8, 2, -1, -1, -1, -1],[9, 5, 6, 9, 6, 0, 0, 6, 2, -1, -1, -1, -1, -1, -1, -1],[1, 5, 8, 1, 8, 0, 5, 6, 8, 3, 8, 2, 6, 2, 8, -1],[1, 5, 6, 2, 1, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[1, 3, 6, 1, 6, 10, 3, 8, 6, 5, 6, 9, 8, 9, 6, -1],[10, 1, 0, 10, 0, 6, 9, 5, 0, 5, 6, 0, -1, -1, -1, -1],[0, 3, 8, 5, 6, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[10, 5, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[11, 5, 10, 7, 5, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[11, 5, 10, 11, 7, 5, 8, 3, 0, -1, -1, -1, -1, -1, -1, -1],[5, 11, 7, 5, 10, 11, 1, 9, 0, -1, -1, -1, -1, -1, -1, -1],[10, 7, 5, 10, 11, 7, 9, 8, 1, 8, 3, 1, -1, -1, -1, -1],[11, 1, 2, 11, 7, 1, 7, 5, 1, -1, -1, -1, -1, -1, -1, -1],[0, 8, 3, 1, 2, 7, 1, 7, 5, 7, 2, 11, -1, -1, -1, -1],[9, 7, 5, 9, 2, 7, 9, 0, 2, 2, 11, 7, -1, -1, -1, -1],[7, 5, 2, 7, 2, 11, 5, 9, 2, 3, 2, 8, 9, 8, 2, -1],[2, 5, 10, 2, 3, 5, 3, 7, 5, -1, -1, -1, -1, -1, -1, -1],[8, 2, 0, 8, 5, 2, 8, 7, 5, 10, 2, 5, -1, -1, -1, -1],[9, 0, 1, 5, 10, 3, 5, 3, 7, 3, 10, 2, -1, -1, -1, -1],[9, 8, 2, 9, 2, 1, 8, 7, 2, 10, 2, 5, 7, 5, 2, -1],[1, 3, 5, 3, 7, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 8, 7, 0, 7, 1, 1, 7, 5, -1, -1, -1, -1, -1, -1, -1],[9, 0, 3, 9, 3, 5, 5, 3, 7, -1, -1, -1, -1, -1, -1, -1],[9, 8, 7, 5, 9, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[5, 8, 4, 5, 10, 8, 10, 11, 8, -1, -1, -1, -1, -1, -1, -1],[5, 0, 4, 5, 11, 0, 5, 10, 11, 11, 3, 0, -1, -1, -1, -1],[0, 1, 9, 8, 4, 10, 8, 10, 11, 10, 4, 5, -1, -1, -1, -1],[10, 11, 4, 10, 4, 5, 11, 3, 4, 9, 4, 1, 3, 1, 4, -1],[2, 5, 1, 2, 8, 5, 2, 11, 8, 4, 5, 8, -1, -1, -1, -1],[0, 4, 11, 0, 11, 3, 4, 5, 11, 2, 11, 1, 5, 1, 11, -1],[0, 2, 5, 0, 5, 9, 2, 11, 5, 4, 5, 8, 11, 8, 5, -1],[9, 4, 5, 2, 11, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[2, 5, 10, 3, 5, 2, 3, 4, 5, 3, 8, 4, -1, -1, -1, -1],[5, 10, 2, 5, 2, 4, 4, 2, 0, -1, -1, -1, -1, -1, -1, -1],[3, 10, 2, 3, 5, 10, 3, 8, 5, 4, 5, 8, 0, 1, 9, -1],[5, 10, 2, 5, 2, 4, 1, 9, 2, 9, 4, 2, -1, -1, -1, -1],[8, 4, 5, 8, 5, 3, 3, 5, 1, -1, -1, -1, -1, -1, -1, -1],[0, 4, 5, 1, 0, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[8, 4, 5, 8, 5, 3, 9, 0, 5, 0, 3, 5, -1, -1, -1, -1],[9, 4, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[4, 11, 7, 4, 9, 11, 9, 10, 11, -1, -1, -1, -1, -1, -1, -1],[0, 8, 3, 4, 9, 7, 9, 11, 7, 9, 10, 11, -1, -1, -1, -1],[1, 10, 11, 1, 11, 4, 1, 4, 0, 7, 4, 11, -1, -1, -1, -1],[3, 1, 4, 3, 4, 8, 1, 10, 4, 7, 4, 11, 10, 11, 4, -1],[4, 11, 7, 9, 11, 4, 9, 2, 11, 9, 1, 2, -1, -1, -1, -1],[9, 7, 4, 9, 11, 7, 9, 1, 11, 2, 11, 1, 0, 8, 3, -1],[11, 7, 4, 11, 4, 2, 2, 4, 0, -1, -1, -1, -1, -1, -1, -1],[11, 7, 4, 11, 4, 2, 8, 3, 4, 3, 2, 4, -1, -1, -1, -1],[2, 9, 10, 2, 7, 9, 2, 3, 7, 7, 4, 9, -1, -1, -1, -1],[9, 10, 7, 9, 7, 4, 10, 2, 7, 8, 7, 0, 2, 0, 7, -1],[3, 7, 10, 3, 10, 2, 7, 4, 10, 1, 10, 0, 4, 0, 10, -1],[1, 10, 2, 8, 7, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[4, 9, 1, 4, 1, 7, 7, 1, 3, -1, -1, -1, -1, -1, -1, -1],[4, 9, 1, 4, 1, 7, 0, 8, 1, 8, 7, 1, -1, -1, -1, -1],[4, 0, 3, 7, 4, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[4, 8, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[9, 10, 8, 10, 11, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[3, 0, 9, 3, 9, 11, 11, 9, 10, -1, -1, -1, -1, -1, -1, -1],[0, 1, 10, 0, 10, 8, 8, 10, 11, -1, -1, -1, -1, -1, -1, -1],[3, 1, 10, 11, 3, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[1, 2, 11, 1, 11, 9, 9, 11, 8, -1, -1, -1, -1, -1, -1, -1],[3, 0, 9, 3, 9, 11, 1, 2, 9, 2, 11, 9, -1, -1, -1, -1],[0, 2, 11, 8, 0, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[3, 2, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[2, 3, 8, 2, 8, 10, 10, 8, 9, -1, -1, -1, -1, -1, -1, -1],[9, 10, 2, 0, 9, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[2, 3, 8, 2, 8, 10, 0, 1, 8, 1, 10, 8, -1, -1, -1, -1],[1, 10, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[1, 3, 8, 9, 1, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 9, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[0, 3, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],[-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]]

const GRASS_TEXTURE = preload("res://green-grass-texture.jpg")
const ROAD_TEXTURE = preload("res://gravel-texture.jpg")
const SAND_TEXTURE = preload("res://sand-texture.jpg")
const ROCK_TEXTURE = preload("res://rocky-texture.jpg")
const SNOW_TEXTURE = preload("res://snow-texture.jpg")

const TERRAIN_SHADER = preload("res://terrain.gdshader")
const WATER_SHADER = preload("res://water.gdshader")
const TREE_SCENE = preload("res://Tree.tscn")

func _ready():
	var chunk_size = grid_size * scale_factor

	if _terrain_material == null:
		var mat = ShaderMaterial.new()
		mat.shader = TERRAIN_SHADER
		mat.set_shader_parameter("grass_texture", GRASS_TEXTURE)
		mat.set_shader_parameter("road_texture", ROAD_TEXTURE)
		mat.set_shader_parameter("sand_texture", SAND_TEXTURE)
		mat.set_shader_parameter("rock_texture", ROCK_TEXTURE)
		mat.set_shader_parameter("snow_texture", SNOW_TEXTURE)
		mat.set_shader_parameter("texture_scale", 0.5) # Adjusted scale for better tiling
		_terrain_material = mat
	self.material_override = _terrain_material

	if _water_mesh == null:
		var water_mesh = PlaneMesh.new()
		water_mesh.size = Vector2(chunk_size, chunk_size)
		_water_mesh = water_mesh

	if _water_material == null:
		var water_mat = ShaderMaterial.new()
		water_mat.shader = WATER_SHADER
		_water_material = water_mat

	# Water Plane
	var water_inst = MeshInstance3D.new()
	water_inst.mesh = _water_mesh
	water_inst.material_override = _water_material

	# Position water: centered in X/Z, fixed height in Y
	# PlaneMesh is centered by default, so we offset it to the center of the chunk
	water_inst.position = Vector3(chunk_size/2.0, 15.0, chunk_size/2.0) 

	# Disable collision for raycasting/physics (visual only)
	# By default MeshInstance3D has no collision, so this is safe.
	
	add_child(water_inst)

# Threading & Synchronization
var thread: Thread
var mutex: Mutex = Mutex.new()
var field: PackedFloat32Array
var road_data: PackedFloat32Array

func _exit_tree():
	if thread and thread.is_started():
		thread.wait_to_finish()

func start_generation(p_chunk_coord, p_grid_size, p_iso_level, p_scale_factor, p_terrain_height, p_noise):
	chunk_coord = p_chunk_coord
	grid_size = p_grid_size
	iso_level = p_iso_level
	scale_factor = p_scale_factor
	terrain_height = p_terrain_height
	noise = p_noise
	
	# Start thread
	if thread and thread.is_started():
		thread.wait_to_finish()
	
	thread = Thread.new()
	thread.start(_generate.bind(thread))

func modify_terrain(local_pos: Vector3, radius: float, amount: float, shape: String = "sphere"):
	# Wait for any existing generation to finish BEFORE touching data
	if thread and thread.is_started():
		thread.wait_to_finish()

	# Convert local position (scaled) to grid coordinates
	var center_x = local_pos.x / scale_factor
	var center_y = local_pos.y / scale_factor
	var center_z = local_pos.z / scale_factor
	
	var r_sq = (radius / scale_factor) ** 2
	var s = grid_size + 1
	var s2 = s * s
	
	var min_x = int(max(0, center_x - radius))
	var max_x = int(min(grid_size, center_x + radius))
	var min_y = int(max(0, center_y - radius))
	var max_y = int(min(grid_size, center_y + radius))
	var min_z = int(max(0, center_z - radius))
	var max_z = int(min(grid_size, center_z + radius))
	
	var modified = false
	
	mutex.lock()
	if field.size() == s*s*s:
		for x in range(min_x, max_x + 1):
			for y in range(min_y, max_y + 1):
				for z in range(min_z, max_z + 1):
					var hit = false
					if shape == "sphere":
						var dist_sq = (x - center_x)**2 + (y - center_y)**2 + (z - center_z)**2
						if dist_sq <= r_sq:
							hit = true
					elif shape == "box":
						if abs(x - center_x) <= (radius / scale_factor) and \
						   abs(y - center_y) <= (radius / scale_factor) and \
						   abs(z - center_z) <= (radius / scale_factor):
							hit = true
					
					if hit:
						var idx = x * s2 + y * s + z
						field[idx] += amount
						modified = true
	mutex.unlock()

	if modified:
		thread = Thread.new()
		thread.start(_generate.bind(thread))

func modify_road(local_pos: Vector3, radius: float, amount: float):
	if thread and thread.is_started():
		thread.wait_to_finish()

	var center_x = local_pos.x / scale_factor
	var center_y = local_pos.y / scale_factor
	var center_z = local_pos.z / scale_factor
	
	var r_sq = (radius / scale_factor) ** 2
	var s = grid_size + 1
	var s2 = s * s
	
	var min_x = int(max(0, center_x - radius))
	var max_x = int(min(grid_size, center_x + radius))
	var min_y = int(max(0, center_y - radius))
	var max_y = int(min(grid_size, center_y + radius))
	var min_z = int(max(0, center_z - radius))
	var max_z = int(min(grid_size, center_z + radius))
	
	var modified = false
	
	mutex.lock()
	# Ensure road data exists (it should if generated, but check size)
	if road_data.size() == s*s*s:
		for x in range(min_x, max_x + 1):
			for y in range(min_y, max_y + 1):
				for z in range(min_z, max_z + 1):
					var dist_sq = (x - center_x)**2 + (y - center_y)**2 + (z - center_z)**2
					if dist_sq <= r_sq:
						var idx = x * s2 + y * s + z
						road_data[idx] = clamp(road_data[idx] + amount, 0.0, 1.0)
						modified = true
	mutex.unlock()

	if modified:
		thread = Thread.new()
		thread.start(_generate.bind(thread))

func _generate(thread_ref):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var s = grid_size + 1
	var s2 = s * s
	
	mutex.lock()
	if field.is_empty():
		field.resize(s * s * s)
		road_data.resize(s * s * s)
		road_data.fill(0.0) # Initialize as grass
		
		# Determine global offset for noise continuity
		var global_offset_x = chunk_coord.x * grid_size
		var global_offset_z = chunk_coord.z * grid_size
		
		for x in range(s):
			for y in range(s):
				for z in range(s):
					# Use GLOBAL coordinates for noise
					var val = noise.get_noise_3d(global_offset_x + x, y, global_offset_z + z)
					var density = -float(y) + (val * terrain_height) + (grid_size / 2.0)
					field[x * s2 + y * s + z] = -density
	
	# Ensure road_data matches field size (in case field was loaded but road wasn't)
	if road_data.size() != field.size():
		road_data.resize(field.size())
		road_data.fill(0.0)
	mutex.unlock()

	# Standard Marching Cubes
	for x in range(grid_size):
		for y in range(grid_size):
			for z in range(grid_size):
				
				var idx = x * s2 + y * s + z
				
				# Fetch densities
				var vals = [
					field[idx], field[idx + s2], field[idx + s2 + 1], field[idx + 1],
					field[idx + s], field[idx + s2 + s], field[idx + s2 + s + 1], field[idx + s + 1]
				]
				
				# Fetch road weights
				var roads = [
					road_data[idx], road_data[idx + s2], road_data[idx + s2 + 1], road_data[idx + 1],
					road_data[idx + s], road_data[idx + s2 + s], road_data[idx + s2 + s + 1], road_data[idx + s + 1]
				]
				
				var cube_index = 0
				if vals[0] < iso_level: cube_index |= 1
				if vals[1] < iso_level: cube_index |= 2
				if vals[2] < iso_level: cube_index |= 4
				if vals[3] < iso_level: cube_index |= 8
				if vals[4] < iso_level: cube_index |= 16
				if vals[5] < iso_level: cube_index |= 32
				if vals[6] < iso_level: cube_index |= 64
				if vals[7] < iso_level: cube_index |= 128
				
				if EDGE_TABLE[cube_index] == 0: continue
				
				var corners = [
					Vector3(x, y, z), Vector3(x+1, y, z), Vector3(x+1, y, z+1), Vector3(x, y, z+1),
					Vector3(x, y+1, z), Vector3(x+1, y+1, z), Vector3(x+1, y+1, z+1), Vector3(x, y+1, z+1)
				]
				
				var vert_list = []
				vert_list.resize(12)
				var color_list = []
				color_list.resize(12)
				
				# Helper lambda for vertex interpolation with color
				# Not actually using a lambda because of GDScript version potential issues, just inline logic
				
				# Edge 0: 0 -> 1
				if (EDGE_TABLE[cube_index] & 1): 
					vert_list[0] = vertex_interp(iso_level, corners[0], corners[1], vals[0], vals[1])
					color_list[0] = scalar_interp(iso_level, roads[0], roads[1], vals[0], vals[1])
				
				# Edge 1: 1 -> 2
				if (EDGE_TABLE[cube_index] & 2): 
					vert_list[1] = vertex_interp(iso_level, corners[1], corners[2], vals[1], vals[2])
					color_list[1] = scalar_interp(iso_level, roads[1], roads[2], vals[1], vals[2])

				# Edge 2: 2 -> 3
				if (EDGE_TABLE[cube_index] & 4): 
					vert_list[2] = vertex_interp(iso_level, corners[2], corners[3], vals[2], vals[3])
					color_list[2] = scalar_interp(iso_level, roads[2], roads[3], vals[2], vals[3])

				# Edge 3: 3 -> 0
				if (EDGE_TABLE[cube_index] & 8): 
					vert_list[3] = vertex_interp(iso_level, corners[3], corners[0], vals[3], vals[0])
					color_list[3] = scalar_interp(iso_level, roads[3], roads[0], vals[3], vals[0])

				# Edge 4: 4 -> 5
				if (EDGE_TABLE[cube_index] & 16): 
					vert_list[4] = vertex_interp(iso_level, corners[4], corners[5], vals[4], vals[5])
					color_list[4] = scalar_interp(iso_level, roads[4], roads[5], vals[4], vals[5])

				# Edge 5: 5 -> 6
				if (EDGE_TABLE[cube_index] & 32): 
					vert_list[5] = vertex_interp(iso_level, corners[5], corners[6], vals[5], vals[6])
					color_list[5] = scalar_interp(iso_level, roads[5], roads[6], vals[5], vals[6])

				# Edge 6: 6 -> 7
				if (EDGE_TABLE[cube_index] & 64): 
					vert_list[6] = vertex_interp(iso_level, corners[6], corners[7], vals[6], vals[7])
					color_list[6] = scalar_interp(iso_level, roads[6], roads[7], vals[6], vals[7])

				# Edge 7: 7 -> 4
				if (EDGE_TABLE[cube_index] & 128): 
					vert_list[7] = vertex_interp(iso_level, corners[7], corners[4], vals[7], vals[4])
					color_list[7] = scalar_interp(iso_level, roads[7], roads[4], vals[7], vals[4])

				# Edge 8: 0 -> 4
				if (EDGE_TABLE[cube_index] & 256): 
					vert_list[8] = vertex_interp(iso_level, corners[0], corners[4], vals[0], vals[4])
					color_list[8] = scalar_interp(iso_level, roads[0], roads[4], vals[0], vals[4])

				# Edge 9: 1 -> 5
				if (EDGE_TABLE[cube_index] & 512): 
					vert_list[9] = vertex_interp(iso_level, corners[1], corners[5], vals[1], vals[5])
					color_list[9] = scalar_interp(iso_level, roads[1], roads[5], vals[1], vals[5])

				# Edge 10: 2 -> 6
				if (EDGE_TABLE[cube_index] & 1024): 
					vert_list[10] = vertex_interp(iso_level, corners[2], corners[6], vals[2], vals[6])
					color_list[10] = scalar_interp(iso_level, roads[2], roads[6], vals[2], vals[6])

				# Edge 11: 3 -> 7
				if (EDGE_TABLE[cube_index] & 2048): 
					vert_list[11] = vertex_interp(iso_level, corners[3], corners[7], vals[3], vals[7])
					color_list[11] = scalar_interp(iso_level, roads[3], roads[7], vals[3], vals[7])

				var i = 0
				while TRI_TABLE[cube_index][i] != -1:
					var v1 = vert_list[TRI_TABLE[cube_index][i]] * scale_factor
					var v2 = vert_list[TRI_TABLE[cube_index][i+1]] * scale_factor
					var v3 = vert_list[TRI_TABLE[cube_index][i+2]] * scale_factor
					
					var c1 = color_list[TRI_TABLE[cube_index][i]]
					var c2 = color_list[TRI_TABLE[cube_index][i+1]]
					var c3 = color_list[TRI_TABLE[cube_index][i+2]]
					
					# Add Triangle
					st.set_color(Color(c1, 0, 0))
					st.add_vertex(v1)
					
					st.set_color(Color(c3, 0, 0))
					st.add_vertex(v3)
					
					st.set_color(Color(c2, 0, 0))
					st.add_vertex(v2)
					
					i += 3

	st.index()
	st.generate_normals()
	
	call_deferred("_finalize_mesh", st.commit(), thread_ref)

func _finalize_mesh(new_mesh, thread_ref):
	if thread_ref.is_started():
		thread_ref.wait_to_finish()
	self.mesh = new_mesh
	
	# Clear old collision shapes to prevent stacking/ghost collisions
	for child in get_children():
		if child is StaticBody3D:
			child.queue_free()
			
	var sb = StaticBody3D.new()
	var cs = CollisionShape3D.new()
	cs.shape = new_mesh.create_trimesh_shape()
	sb.add_child(cs)
	add_child(sb)
	
	populate_vegetation()
	
	generation_complete.emit(chunk_coord)

func populate_vegetation():
	# Use Physics Raycast for perfect placement
	# Collision shape is already created and added to tree in _finalize_mesh
	
	var step = 8 # Reduced density for performance (was 4)
	var s = grid_size
	var global_x = chunk_coord.x * grid_size
	var global_z = chunk_coord.z * grid_size
	
	var space_state = get_world_3d().direct_space_state
	
	for x in range(2, s - 2, step):
		for z in range(2, s - 2, step):
			
			var tree_val = noise.get_noise_2d((global_x + x) * 5.0, (global_z + z) * 5.0)
			
			if tree_val > 0.2:
				# Raycast from top of chunk down
				var from_pos = to_global(Vector3(x * scale_factor, grid_size * scale_factor, z * scale_factor))
				var to_pos = to_global(Vector3(x * scale_factor, -10.0, z * scale_factor))
				
				var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
				# Ensure we hit ourselves (the chunk)
				# query.collide_with_bodies = true (default)
				
				var result = space_state.intersect_ray(query)
				
				if result:
					var hit_y = result.position.y
					
					# Biome Rules
					if hit_y > 19.0 and hit_y < 50.0:
						
						# Road Check
						# Convert local hit to grid index roughly
						var local_hit = to_local(result.position)
						var grid_y = int(local_hit.y / scale_factor)
						var idx = x * (s+1)*(s+1) + clamp(grid_y, 0, s) * (s+1) + z
						
						if idx < road_data.size() and road_data[idx] < 0.5:
							var tree = TREE_SCENE.instantiate()
							add_child(tree)
							# Use the EXACT raycast hit position (local)
							tree.global_position = result.position
							
							tree.rotate_y(randf() * TAU)
							var scale_mod = randf_range(0.8, 1.2)
							tree.scale = Vector3(scale_mod, scale_mod, scale_mod)

func vertex_interp(isolevel: float, p1: Vector3, p2: Vector3, val_p1: float, val_p2: float) -> Vector3:
	if abs(isolevel - val_p1) < 0.00001: return p1
	if abs(isolevel - val_p2) < 0.00001: return p2
	if abs(val_p1 - val_p2) < 0.00001: return p1
	var mu = (isolevel - val_p1) / (val_p2 - val_p1)
	return p1.lerp(p2, mu)

func scalar_interp(isolevel: float, r1: float, r2: float, val_p1: float, val_p2: float) -> float:
	if abs(isolevel - val_p1) < 0.00001: return r1
	if abs(isolevel - val_p2) < 0.00001: return r2
	if abs(val_p1 - val_p2) < 0.00001: return r1
	var mu = (isolevel - val_p1) / (val_p2 - val_p1)
	return lerp(r1, r2, mu)
