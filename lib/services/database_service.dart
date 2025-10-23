import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/category.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Criar tabela de categorias
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // Criar tabela de tarefas
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        completed INTEGER NOT NULL,
        priority TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        dueDate TEXT,
        categoryId TEXT,
        FOREIGN KEY (categoryId) REFERENCES categories (id)
      )
    ''');

    // Inserir categorias padrão
    await _insertDefaultCategories(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN dueDate TEXT');
    }
    if (oldVersion < 3) {
      // Criar tabela de categorias
      await db.execute('''
        CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          color TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');

      // Adicionar coluna categoryId na tabela tasks
      await db.execute('ALTER TABLE tasks ADD COLUMN categoryId TEXT');

      // Inserir categorias padrão
      await _insertDefaultCategories(db);
    }
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final defaultCategories = [
      Category(
        name: 'Trabalho',
        color: 'FF4285F4', // Azul
      ),
      Category(
        name: 'Pessoal',
        color: 'FF34A853', // Verde
      ),
      Category(
        name: 'Estudos',
        color: 'FFFBBB05', // Amarelo
      ),
      Category(
        name: 'Saúde',
        color: 'FFEA4335', // Vermelho
      ),
      Category(
        name: 'Compras',
        color: 'FFFF6D01', // Laranja
      ),
      Category(
        name: 'Outros',
        color: 'FF8E44AD', // Roxo
      ),
    ];

    for (final category in defaultCategories) {
      await db.insert('categories', category.toMap());
    }
  }

  // tarefas implementadas abaixo

  Future<Task> create(Task task) async {
    final db = await database;
    await db.insert('tasks', task.toMap());
    return task;
  }

  Future<Task?> read(String id) async {
    final db = await database;
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Task>> readAll() async {
    final db = await database;
    const orderBy = 'createdAt DESC';
    final result = await db.query('tasks', orderBy: orderBy);
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<int> update(Task task) async {
    final db = await database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // categorias implementadas abaixo

  Future<Category> createCategory(Category category) async {
    final db = await database;
    await db.insert('categories', category.toMap());
    return category;
  }

  Future<Category?> readCategory(String id) async {
    final db = await database;
    final maps = await db.query('categories', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Category.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Category>> readAllCategories() async {
    final db = await database;
    const orderBy = 'name ASC';
    final result = await db.query('categories', orderBy: orderBy);
    return result.map((map) => Category.fromMap(map)).toList();
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await database;
    // Primeiro, remover a categoria de todas as tarefas
    await db.update(
      'tasks',
      {'categoryId': null},
      where: 'categoryId = ?',
      whereArgs: [id],
    );
    // Depois, deletar a categoria
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // auxiliares abaixo

  Future<List<Task>> getTasksByCategory(String? categoryId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;

    if (categoryId == null) {
      maps = await db.query('tasks', where: 'categoryId IS NULL');
    } else {
      maps = await db.query(
        'tasks',
        where: 'categoryId = ?',
        whereArgs: [categoryId],
      );
    }

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<Map<String, List<Task>>> getTasksGroupedByCategory() async {
    final tasks = await readAll();
    final categories = await readAllCategories();

    final Map<String, List<Task>> grouped = {};

    // Adicionar categoria "Sem Categoria"
    grouped['none'] = tasks.where((task) => task.categoryId == null).toList();

    // Agrupar por categorias existentes
    for (final category in categories) {
      grouped[category.id] = tasks
          .where((task) => task.categoryId == category.id)
          .toList();
    }

    return grouped;
  }
}
