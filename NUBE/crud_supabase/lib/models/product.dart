/// Modelo de datos para un Producto.
/// Corresponde a la tabla `productos` en Supabase.
class Product {
  final int? id;
  final String nombre;
  final String descripcion;
  final double precio;
  final int cantidad;
  final DateTime? createdAt;

  Product({
    this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.cantidad,
    this.createdAt,
  });

  /// Crea un Product desde un Map (row de Supabase).
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      nombre: map['nombre'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      cantidad: map['cantidad'] as int? ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  /// Convierte a Map para enviar a Supabase (sin id ni created_at).
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'cantidad': cantidad,
    };
  }

  /// Crea una copia del producto con campos opcionales modificados.
  Product copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    double? precio,
    int? cantidad,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precio: precio ?? this.precio,
      cantidad: cantidad ?? this.cantidad,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
