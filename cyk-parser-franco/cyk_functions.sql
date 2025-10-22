-- ================================================
-- Funciones PL/pgSQL para el Algoritmo CYK
-- Trabajo Práctico - Teoría de la Computación 2025C2
-- ================================================

-- Tabla temporal para almacenar el string de entrada
CREATE TABLE IF NOT EXISTS cyk_input (
    input_string TEXT
);

-- Función auxiliar: obtener variables que derivan a un terminal
CREATE OR REPLACE FUNCTION get_vars_for_terminal(terminal TEXT)
RETURNS TEXT[] AS $$
DECLARE
    vars TEXT[];
BEGIN
    SELECT ARRAY_AGG(DISTINCT parte_izq)
    INTO vars
    FROM GLC_en_FNC
    WHERE tipo_produccion = 1 
      AND parte_der1 = terminal;
    
    RETURN COALESCE(vars, ARRAY[]::TEXT[]);
END;
$$ LANGUAGE plpgsql;

-- Función auxiliar: obtener variables que derivan de dos variables
CREATE OR REPLACE FUNCTION get_vars_for_pair(var1 TEXT, var2 TEXT)
RETURNS TEXT[] AS $$
DECLARE
    vars TEXT[];
BEGIN
    SELECT ARRAY_AGG(DISTINCT parte_izq)
    INTO vars
    FROM GLC_en_FNC
    WHERE tipo_produccion = 2 
      AND parte_der1 = var1 
      AND parte_der2 = var2;
    
    RETURN COALESCE(vars, ARRAY[]::TEXT[]);
END;
$$ LANGUAGE plpgsql;

-- Función auxiliar: unir dos arrays eliminando duplicados
CREATE OR REPLACE FUNCTION array_union(arr1 TEXT[], arr2 TEXT[])
RETURNS TEXT[] AS $$
BEGIN
    RETURN ARRAY(
        SELECT DISTINCT unnest(arr1 || arr2)
    );
END;
$$ LANGUAGE plpgsql;

-- Función para tokenizar el string de entrada
CREATE OR REPLACE FUNCTION tokenize_input(input TEXT)
RETURNS TEXT[] AS $$
DECLARE
    tokens TEXT[];
    i INT;
    current_char TEXT;
BEGIN
    tokens := ARRAY[]::TEXT[];
    
    FOR i IN 1..LENGTH(input) LOOP
        current_char := SUBSTRING(input FROM i FOR 1);
        tokens := array_append(tokens, current_char);
    END LOOP;
    
    RETURN tokens;
END;
$$ LANGUAGE plpgsql;

-- Función principal: setear_matriz(fila)
CREATE OR REPLACE FUNCTION setear_matriz(fila INT)
RETURNS VOID AS $$
DECLARE
    input_str TEXT;
    tokens TEXT[];
    n INT;
    i INT;
    j INT;
    k INT;
    terminal TEXT;
    current_vars TEXT[];
    left_vars TEXT[];
    right_vars TEXT[];
    new_vars TEXT[];
    var_left TEXT;
    var_right TEXT;
    pair_vars TEXT[];
BEGIN
    -- Obtener el string de entrada
    SELECT input_string INTO input_str FROM cyk_input LIMIT 1;
    
    IF input_str IS NULL THEN
        RAISE EXCEPTION 'No hay string de entrada cargado';
    END IF;
    
    -- Tokenizar el input
    tokens := tokenize_input(input_str);
    n := array_length(tokens, 1);
    
    -- Fila 1: llenar diagonal (X_ii)
    IF fila = 1 THEN
        FOR i IN 1..n LOOP
            terminal := tokens[i];
            current_vars := get_vars_for_terminal(terminal);
            
            INSERT INTO matriz_cyk (i, j, x)
            VALUES (i, i, current_vars)
            ON CONFLICT (i, j) DO UPDATE
            SET x = EXCLUDED.x;
        END LOOP;
        
    -- Filas superiores: llenar niveles superiores
    ELSE
        FOR i IN 1..(n - fila + 1) LOOP
            j := i + fila - 1;
            current_vars := ARRAY[]::TEXT[];
            
            -- Probar todas las particiones posibles
            FOR k IN i..(j-1) LOOP
                -- Obtener variables de la celda izquierda (i,k)
                SELECT x INTO left_vars FROM matriz_cyk WHERE matriz_cyk.i = i AND matriz_cyk.j = k;
                
                -- Obtener variables de la celda derecha (k+1,j)
                SELECT x INTO right_vars FROM matriz_cyk WHERE matriz_cyk.i = k+1 AND matriz_cyk.j = j;
                
                -- Si ambas celdas tienen variables
                IF left_vars IS NOT NULL AND right_vars IS NOT NULL THEN
                    -- Probar todas las combinaciones
                    FOREACH var_left IN ARRAY left_vars LOOP
                        FOREACH var_right IN ARRAY right_vars LOOP
                            pair_vars := get_vars_for_pair(var_left, var_right);
                            current_vars := array_union(current_vars, pair_vars);
                        END LOOP;
                    END LOOP;
                END IF;
            END LOOP;
            
            -- Insertar o actualizar la celda (i,j)
            INSERT INTO matriz_cyk (i, j, x)
            VALUES (i, j, current_vars)
            ON CONFLICT (i, j) DO UPDATE
            SET x = EXCLUDED.x;
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Función principal CYK
CREATE OR REPLACE FUNCTION cyk(input TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    n INT;
    fila INT;
    start_symbol TEXT;
    final_vars TEXT[];
    resultado BOOLEAN;
BEGIN
    -- Limpiar tablas temporales
    TRUNCATE TABLE cyk_input;
    TRUNCATE TABLE matriz_cyk;
    
    -- Guardar el input
    INSERT INTO cyk_input (input_string) VALUES (input);
    
    -- Calcular longitud
    n := LENGTH(input);
    
    IF n = 0 THEN
        RETURN FALSE;
    END IF;
    
    -- Llenar la matriz fila por fila
    FOR fila IN 1..n LOOP
        PERFORM setear_matriz(fila);
    END LOOP;
    
    -- Obtener el símbolo inicial de la gramática
    SELECT parte_izq INTO start_symbol
    FROM GLC_en_FNC
    WHERE start = true
    LIMIT 1;
    
    -- Verificar si el símbolo inicial está en X[1,n]
    SELECT x INTO final_vars
    FROM matriz_cyk
    WHERE i = 1 AND j = n;
    
    -- Verificar si el símbolo inicial está en el conjunto final
    resultado := start_symbol = ANY(final_vars);
    
    RETURN resultado;
END;
$$ LANGUAGE plpgsql;

-- ================================================
-- Queries para la Parte 4
-- ================================================

-- Query para mostrar la GLC cargada
CREATE OR REPLACE VIEW vista_gramatica AS
SELECT 
    CASE WHEN start THEN 'S*' ELSE '' END as simbolo_inicial,
    parte_izq as variable,
    CASE 
        WHEN tipo_produccion = 1 THEN parte_der1
        WHEN tipo_produccion = 2 THEN parte_der1 || ' ' || parte_der2
    END as derivacion,
    CASE 
        WHEN tipo_produccion = 1 THEN 'Terminal'
        WHEN tipo_produccion = 2 THEN 'Variables'
    END as tipo
FROM GLC_en_FNC
ORDER BY start DESC, parte_izq, tipo_produccion, parte_der1;

-- Query para mostrar la matriz CYK de forma visual
CREATE OR REPLACE FUNCTION mostrar_matriz_cyk()
RETURNS TABLE(
    nivel INT,
    posicion TEXT,
    variables TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (m.j - m.i + 1) as nivel,
        'X[' || m.i::TEXT || ',' || m.j::TEXT || ']' as posicion,
        COALESCE(array_to_string(m.x, ', '), '∅') as variables
    FROM matriz_cyk m
    ORDER BY nivel, m.i;
END;
$$ LANGUAGE plpgsql;

-- Vista alternativa de la matriz CYK
CREATE OR REPLACE VIEW vista_matriz_cyk AS
SELECT 
    i as fila_inicio,
    j as fila_fin,
    (j - i + 1) as longitud,
    COALESCE(array_to_string(x, ', '), '∅') as variables
FROM matriz_cyk
ORDER BY (j - i + 1), i;

-- ================================================
-- Funciones auxiliares para debugging
-- ================================================

-- Función para mostrar el contenido de una celda específica
CREATE OR REPLACE FUNCTION ver_celda(fila_i INT, fila_j INT)
RETURNS TEXT AS $$
DECLARE
    vars TEXT[];
BEGIN
    SELECT x INTO vars FROM matriz_cyk WHERE i = fila_i AND j = fila_j;
    RETURN COALESCE(array_to_string(vars, ', '), 'vacío');
END;
$$ LANGUAGE plpgsql;

-- Función para contar producciones por tipo
CREATE OR REPLACE FUNCTION estadisticas_gramatica()
RETURNS TABLE(
    tipo TEXT,
    cantidad BIGINT
) AS $
BEGIN
    RETURN QUERY
    SELECT 
        CASE 
            WHEN tipo_produccion = 1 THEN 'Producciones a terminales'
            WHEN tipo_produccion = 2 THEN 'Producciones a variables'
        END as tipo,
        COUNT(*) as cantidad
    FROM GLC_en_FNC
    GROUP BY tipo_produccion
    ORDER BY tipo_produccion;
END;
$ LANGUAGE plpgsql;

-- ================================================
-- Tests unitarios
-- ================================================

-- Test 1: JSON vacío {}
CREATE OR REPLACE FUNCTION test_json_vacio()
RETURNS VOID AS $
DECLARE
    resultado BOOLEAN;
BEGIN
    resultado := cyk('{}');
    
    IF resultado THEN
        RAISE NOTICE 'TEST 1 PASADO: {} es válido';
    ELSE
        RAISE EXCEPTION 'TEST 1 FALLIDO: {} debería ser válido';
    END IF;
END;
$ LANGUAGE plpgsql;

-- Test 2: JSON con un par clave-valor numérico
CREATE OR REPLACE FUNCTION test_json_simple()
RETURNS VOID AS $
DECLARE
    resultado BOOLEAN;
BEGIN
    resultado := cyk('{"a":10}');
    
    IF resultado THEN
        RAISE NOTICE 'TEST 2 PASADO: {"a":10} es válido';
    ELSE
        RAISE EXCEPTION 'TEST 2 FALLIDO: {"a":10} debería ser válido';
    END IF;
END;
$ LANGUAGE plpgsql;

-- Test 3: JSON con múltiples pares
CREATE OR REPLACE FUNCTION test_json_multiple()
RETURNS VOID AS $
DECLARE
    resultado BOOLEAN;
BEGIN
    resultado := cyk('{"a":10,"b":"hola"}');
    
    IF resultado THEN
        RAISE NOTICE 'TEST 3 PASADO: {"a":10,"b":"hola"} es válido';
    ELSE
        RAISE EXCEPTION 'TEST 3 FALLIDO: {"a":10,"b":"hola"} debería ser válido';
    END IF;
END;
$ LANGUAGE plpgsql;

-- Función para ejecutar todos los tests
CREATE OR REPLACE FUNCTION ejecutar_todos_los_tests()
RETURNS VOID AS $
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Ejecutando Tests Unitarios - CYK Parser';
    RAISE NOTICE '========================================';
    
    PERFORM test_json_vacio();
    PERFORM test_json_simple();
    PERFORM test_json_multiple();
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Todos los tests completados exitosamente';
    RAISE NOTICE '========================================';
END;
$ LANGUAGE plpgsql;

-- ================================================
-- Ejemplos de uso
-- ================================================

/*
-- Cargar la gramática (ya está en el script del CLI)

-- Parsear un JSON
SELECT cyk('{}');
SELECT cyk('{"a":10}');
SELECT cyk('{"a":10,"b":"hola"}');

-- Ver la gramática cargada
SELECT * FROM vista_gramatica;

-- Ver la matriz CYK después de parsear
SELECT * FROM mostrar_matriz_cyk();
SELECT * FROM vista_matriz_cyk;

-- Ver una celda específica
SELECT ver_celda(1, 5);

-- Estadísticas de la gramática
SELECT * FROM estadisticas_gramatica();

-- Ejecutar tests
SELECT ejecutar_todos_los_tests();
*/
