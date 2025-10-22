-- ================================================
-- GUÍA DE EJEMPLOS Y COMANDOS SQL
-- CYK Parser - Trabajo Práctico 2025C2
-- ================================================

-- ================================================
-- 1. PARSEAR EXPRESIONES JSON
-- ================================================

-- JSON vacío
SELECT cyk('{}');

-- JSON con un par simple
SELECT cyk('{"a":10}');
SELECT cyk('{"b":99}');

-- JSON con string
SELECT cyk('{"a":"hola"}');
SELECT cyk('{"name":"juan"}');

-- JSON con múltiples pares
SELECT cyk('{"a":10,"b":"hola"}');
SELECT cyk('{"x":1,"y":2,"z":3}');

-- JSON anidado
SELECT cyk('{"a":10,"b":{"c":20}}');
SELECT cyk('{"outer":{"inner":{}}}');

-- JSON complejo
SELECT cyk('{"a":10,"b":"hola","c":{"d":"chau","e":99}}');

-- ================================================
-- 2. VER LA GRAMÁTICA CARGADA
-- ================================================

-- Ver todas las producciones
SELECT * FROM vista_gramatica;

-- Ver solo producciones a terminales
SELECT * FROM vista_gramatica WHERE tipo = 'Terminal';

-- Ver solo producciones a variables
SELECT * FROM vista_gramatica WHERE tipo = 'Variables';

-- Ver producciones de una variable específica
SELECT * FROM vista_gramatica WHERE variable = 'S';
SELECT * FROM vista_gramatica WHERE variable = 'Y';

-- Contar producciones por variable
SELECT variable, COUNT(*) as cantidad
FROM vista_gramatica
GROUP BY variable
ORDER BY cantidad DESC;

-- Ver el símbolo inicial
SELECT * FROM GLC_en_FNC WHERE start = true;

-- ================================================
-- 3. ANALIZAR LA MATRIZ CYK
-- ================================================

-- Ver toda la matriz después de un parsing
SELECT cyk('{"a":10}');  -- Primero parsear
SELECT * FROM mostrar_matriz_cyk();

-- Ver matriz ordenada por nivel
SELECT * FROM vista_matriz_cyk;

-- Ver solo la celda final (debería contener S si es válido)
SELECT * FROM matriz_cyk 
WHERE i = 1 
ORDER BY j DESC 
LIMIT 1;

-- Ver diagonal principal (primera fila de la matriz)
SELECT i, j, array_to_string(x, ', ') as variables
FROM matriz_cyk
WHERE i = j
ORDER BY i;

-- Ver una celda específica
SELECT ver_celda(1, 1);  -- Primera celda
SELECT ver_celda(1, 5);  -- Celda que cubre caracteres 1-5

-- Contar celdas con variables
SELECT COUNT(*) as celdas_llenas
FROM matriz_cyk
WHERE array_length(x, 1) > 0;

-- Ver celdas vacías
SELECT i, j
FROM matriz_cyk
WHERE x IS NULL OR array_length(x, 1) = 0;

-- ================================================
-- 4. EJECUTAR TESTS
-- ================================================

-- Ejecutar todos los tests
SELECT ejecutar_todos_los_tests();

-- Ejecutar tests individuales
SELECT test_json_vacio();
SELECT test_json_simple();
SELECT test_json_multiple();

-- ================================================
-- 5. ESTADÍSTICAS Y ANÁLISIS
-- ================================================

-- Estadísticas de la gramática
SELECT * FROM estadisticas_gramatica();

-- Contar total de producciones
SELECT COUNT(*) as total_producciones FROM GLC_en_FNC;

-- Ver variables únicas
SELECT DISTINCT parte_izq as variable 
FROM GLC_en_FNC 
ORDER BY parte_izq;

-- Contar producciones por variable
SELECT parte_izq as variable, COUNT(*) as producciones
FROM GLC_en_FNC
GROUP BY parte_izq
ORDER BY producciones DESC;

-- Ver terminales únicos
SELECT DISTINCT parte_der1 as terminal
FROM GLC_en_FNC
WHERE tipo_produccion = 1
ORDER BY terminal;

-- Variables que derivan directamente a terminales
SELECT parte_izq, COUNT(DISTINCT parte_der1) as terminales
FROM GLC_en_FNC
WHERE tipo_produccion = 1
GROUP BY parte_izq
ORDER BY terminales DESC;

-- ================================================
-- 6. DEBUGGING Y ANÁLISIS DETALLADO
-- ================================================

-- Ver qué variables derivan a un terminal específico
SELECT parte_izq, parte_der1
FROM GLC_en_FNC
WHERE tipo_produccion = 1 AND parte_der1 = 'a';

-- Ver qué variables derivan de un par específico
SELECT parte_izq, parte_der1, parte_der2
FROM GLC_en_FNC
WHERE tipo_produccion = 2 
  AND parte_der1 = 'I' 
  AND parte_der2 = 'D';

-- Probar función auxiliar: variables para terminal
SELECT get_vars_for_terminal('a');
SELECT get_vars_for_terminal('{');
SELECT get_vars_for_terminal(':');

-- Probar función auxiliar: variables para par
SELECT get_vars_for_pair('I', 'D');
SELECT get_vars_for_pair('J', 'H');

-- Ver historial de inputs parseados
SELECT * FROM json_input ORDER BY created_at DESC LIMIT 10;

-- ================================================
-- 7. MANTENIMIENTO
-- ================================================

-- Limpiar matriz CYK (preservando gramática)
TRUNCATE TABLE matriz_cyk;

-- Limpiar todo y empezar de nuevo
TRUNCATE TABLE matriz_cyk;
TRUNCATE TABLE GLC_en_FNC RESTART IDENTITY;
TRUNCATE TABLE cyk_input;
TRUNCATE TABLE json_input RESTART IDENTITY;

-- Ver tamaño de las tablas
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Vacuum y análisis
VACUUM ANALYZE GLC_en_FNC;
VACUUM ANALYZE matriz_cyk;

-- ================================================
-- 8. QUERIES AVANZADOS
-- ================================================

-- Encontrar producciones recursivas
SELECT DISTINCT g1.parte_izq, g1.parte_der1, g1.parte_der2
FROM GLC_en_FNC g1
WHERE g1.tipo_produccion = 2
  AND (g1.parte_der1 = g1.parte_izq OR g1.parte_der2
