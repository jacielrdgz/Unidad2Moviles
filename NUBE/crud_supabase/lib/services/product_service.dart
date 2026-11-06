import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

/// Servicio que maneja todas las operaciones CRUD contra la tabla `productos`
/// en Supabase.
class ProductService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'productos';

  // ─── CREATE ───────────────────────────────────────────────────────────

  /// Inserta un nuevo producto y retorna el producto creado.
  Future<Product> createProduct(Product product) async {
    final response = await _client
        .from(_table)
        .insert(product.toMap())
        .select()
        .single();
    return Product.fromMap(response);
  }

  // ─── READ ─────────────────────────────────────────────────────────────

  /// Obtiene todos los productos ordenados por fecha de creación (más reciente primero).
  Future<List<Product>> getProducts() async {
    final response = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => Product.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene un producto por su ID.
  Future<Product> getProductById(int id) async {
    final response =
        await _client.from(_table).select().eq('id', id).single();
    return Product.fromMap(response);
  }

  // ─── UPDATE ───────────────────────────────────────────────────────────

  /// Actualiza un producto existente y retorna el producto actualizado.
  Future<Product> updateProduct(Product product) async {
    final response = await _client
        .from(_table)
        .update(product.toMap())
        .eq('id', product.id!)
        .select()
        .single();
    return Product.fromMap(response);
  }

  // ─── DELETE ───────────────────────────────────────────────────────────

  /// Elimina un producto por su ID.
  Future<void> deleteProduct(int id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
