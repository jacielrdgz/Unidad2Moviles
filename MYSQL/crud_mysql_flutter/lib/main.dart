import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'producto.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CRUD MySQL Flutter',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const ProductoListScreen(),
    );
  }
}

class ProductoListScreen extends StatefulWidget {
  const ProductoListScreen({super.key});

  @override
  State<ProductoListScreen> createState() => _ProductoListScreenState();
}

class _ProductoListScreenState extends State<ProductoListScreen> {
  // Configuración de URL según plataforma:
  // - Web / Windows Desktop: Apache en http://localhost/api_productos (puerto 80)
  // - Android Emulator: 10.0.2.2 mapea al localhost de la máquina host
  String get baseUrl {
    if (kIsWeb) {
      return "http://localhost/api_productos";
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2/api_productos";
    } else {
      return "http://localhost/api_productos";
    }
  }

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();

  // READ
  Future<List<Producto>> _fetchProductos() async {
    final response = await http.get(Uri.parse('$baseUrl/obtener.php'));
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        return decoded.map((item) => Producto.fromJson(item)).toList();
      } else if (decoded is Map && decoded.containsKey('message')) {
        throw Exception(decoded['message']);
      }
      return [];
    } else {
      throw Exception('Error al cargar productos (HTTP ${response.statusCode})');
    }
  }

  // CREATE / UPDATE
  Future<void> _saveProducto({String? id}) async {
    final isEditing = id != null;
    final url = isEditing ? '$baseUrl/actualizar.php' : '$baseUrl/crear.php';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          if (isEditing) 'id': id,
          'nombre': _nombreController.text,
          'precio': _precioController.text,
        }),
      );

      if (response.statusCode == 200) {
        _nombreController.clear();
        _precioController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing ? 'Producto actualizado con éxito' : 'Producto creado con éxito',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        setState(() {});
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // DELETE
  Future<void> _deleteProducto(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/eliminar.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Producto eliminado con éxito'),
              backgroundColor: Colors.green,
            ),
          );
        }
        setState(() {});
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Diálogo para crear o editar
  void _showFormDialog({Producto? producto}) {
    if (producto != null) {
      _nombreController.text = producto.nombre;
      _precioController.text = producto.precio;
    } else {
      _nombreController.clear();
      _precioController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(producto == null ? 'Nuevo Producto' : 'Editar Producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: _precioController,
              decoration: const InputDecoration(labelText: 'Precio'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveProducto(id: producto?.id);
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos (MySQL + Apache)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: FutureBuilder<List<Producto>>(
        future: _fetchProductos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay productos registrados.'));
          }

          final productos = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              itemCount: productos.length,
              itemBuilder: (context, index) {
                final prod = productos[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(prod.id),
                  ),
                  title: Text(prod.nombre),
                  subtitle: Text('\$${prod.precio}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showFormDialog(producto: prod),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteProducto(prod.id),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}