class Producto {
  final String id;
  final String nombre;
  final String precio;

  Producto({required this.id, required this.nombre, required this.precio});

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      precio: json['precio']?.toString() ?? '0.00',
    );
  }
}