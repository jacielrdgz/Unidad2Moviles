import 'package:flutter_test/flutter_test.dart';
import 'package:crud_supabase/models/product.dart';

void main() {
  test('Product model serialization and deserialization', () {
    final product = Product(
      id: 1,
      nombre: 'Creatina',
      descripcion: '500g',
      precio: 450.0,
      cantidad: 10,
    );

    final map = product.toMap();
    expect(map['nombre'], 'Creatina');
    expect(map['precio'], 450.0);
    expect(map['cantidad'], 10);

    final fromMap = Product.fromMap({
      'id': 1,
      'nombre': 'Creatina',
      'descripcion': '500g',
      'precio': 450.0,
      'cantidad': 10,
      'created_at': DateTime.now().toIso8601String(),
    });

    expect(fromMap.id, 1);
    expect(fromMap.nombre, 'Creatina');
    expect(fromMap.precio, 450.0);
  });
}
