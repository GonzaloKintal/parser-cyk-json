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
    result_vars TEXT[];
BEGIN
    SELECT ARRAY_AGG(DISTINCT parte_izq)
    INTO result_vars
    FROM GLC_en_FNC
    WHERE tipo_produccion = 1 
      AND parte_der1 = terminal;
    
    RETURN COALESCE(result_vars, ARRAY[]::TEXT[]);
END;
$$ LANGUAGE plpgsql;

-- Función auxiliar: obtener variables que derivan de dos variables
CREATE OR REPLACE FUNCTION get_vars_for_pair(left_var TEXT, right_var TEXT)
RETURNS TEXT[] AS $$
DECLARE
    result_vars TEXT[];
BEGIN
    SELECT ARRAY_AGG(DISTINCT parte_izq)
    INTO result_vars
    FROM GLC_en_FNC
    WHERE tipo_produccion = 2 
      AND parte_der1 = left_var 
      AND parte_der2 = right_var;
    
    RETURN COALESCE(result_vars, ARRAY[]::TEXT[]);
END;
$$ LANGUAGE plpgsql;

-- Función auxiliar: unir dos arrays eliminando duplicados
CREATE OR REPLACE FUNCTION array_union(first_array TEXT[], second_array TEXT[])
RETURNS TEXT[] AS $$
BEGIN
    RETURN ARRAY(
        SELECT DISTINCT unnest(first_array || second_array)
    );
END;
$$ LANGUAGE plpgsql;

-- Función para tokenizar el string de entrada
CREATE OR REPLACE FUNCTION tokenize_input(input_text TEXT)
RETURNS TEXT[] AS $$
DECLARE
    token_array TEXT[];
    char_index INT;
    current_char TEXT;
BEGIN
    token_array := ARRAY[]::TEXT[];
    
    FOR char_index IN 1..LENGTH(input_text) LOOP
        current_char := SUBSTRING(input_text FROM char_index FOR 1);
        token_array := array_append(token_array, current_char);
    END LOOP;
    
    RETURN token_array;
END;
$$ LANGUAGE plpgsql;

-- Función principal: setear_matriz(fila)
CREATE OR REPLACE FUNCTION setear_matriz(fila_number INT)
RETURNS VOID AS $$
DECLARE
    input_str TEXT;
    token_array TEXT[];
    string_length INT;
    row_index INT;
    col_index INT;
    partition_index INT;
    terminal_char TEXT;
    terminal_vars TEXT[];
    left_cell_vars TEXT[];
    right_cell_vars TEXT[];
    accumulated_vars TEXT[];
    left_variable TEXT;
    right_variable TEXT;
    pair_production_vars TEXT[];
BEGIN
    -- Obtener el string de entrada
    SELECT input_string INTO input_str FROM cyk_input LIMIT 1;
    
    IF input_str IS NULL THEN
        RAISE EXCEPTION 'No hay string de entrada cargado';
    END IF;
    
    -- Tokenizar el input
    token_array := tokenize_input(input_str);
    string_length := array_length(token_array, 1);
    
    -- Fila 1: llenar diagonal (X_ii)
    IF fila_number = 1 THEN
        FOR row_index IN 1..string_length LOOP
            terminal_char := token_array[row_index];
            terminal_vars := get_vars_for_terminal(terminal_char);
            
            INSERT INTO matriz_cyk (i, j, x)
            VALUES (row_index, row_index, terminal_vars)
            ON CONFLICT (i, j) DO UPDATE
            SET x = EXCLUDED.x;
        END LOOP;
        
    -- Filas superiores: llenar niveles superiores
    ELSE
        FOR row_index IN 1..(string_length - fila_number + 1) LOOP
            col_index := row_index + fila_number - 1;
            accumulated_vars := ARRAY[]::TEXT[];
            
            -- Probar todas las particiones posibles
            FOR partition_index IN row_index..(col_index - 1) LOOP
                -- Obtener variables de la celda izquierda (row_index, partition_index)
                SELECT x INTO left_cell_vars 
                FROM matriz_cyk 
                WHERE i = row_index AND j = partition_index;
                
                -- Obtener variables de la celda derecha (partition_index + 1, col_index)
                SELECT x INTO right_cell_vars 
                FROM matriz_cyk 
                WHERE i = partition_index + 1 AND j = col_index;
                
                -- Si ambas celdas tienen variables
                IF left_cell_vars IS NOT NULL AND right_cell_vars IS NOT NULL THEN
                    -- Probar todas las combinaciones
                    FOREACH left_variable IN ARRAY left_cell_vars LOOP
                        FOREACH right_variable IN ARRAY right_cell_vars LOOP
                            pair_production_vars := get_vars_for_pair(left_variable, right_variable);
                            accumulated_vars := array_union(accumulated_vars, pair_production_vars);
                        END LOOP;
                    END LOOP;
                END IF;
            END LOOP;
            
            -- Insertar o actualizar la celda (row_index, col_index)
            INSERT INTO matriz_cyk (i, j, x)
            VALUES (row_index, col_index, accumulated_vars)
            ON CONFLICT (i, j) DO UPDATE
            SET x = EXCLUDED.x;
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Función principal CYK
CREATE OR REPLACE FUNCTION cyk(input_text TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    string_length INT;
    fila_number INT;
    grammar_start_symbol TEXT;
    final_cell_vars TEXT[];
    is_accepted BOOLEAN;
BEGIN
    -- Limpiar tablas temporales
    TRUNCATE TABLE cyk_input;
    TRUNCATE TABLE matriz_cyk;
    
    -- Guardar el input
    INSERT INTO cyk_input (input_string) VALUES (input_text);
    
    -- Calcular longitud
    string_length := LENGTH(input_text);
    
    IF string_length = 0 THEN
        RETURN FALSE;
    END IF;
    
    -- Llenar la matriz fila por fila
    FOR fila_number IN 1..string_length LOOP
        PERFORM setear_matriz(fila_number);
    END LOOP;
    
    -- Obtener el símbolo inicial de la gramática
    SELECT parte_izq INTO grammar_start_symbol
    FROM GLC_en_FNC
    WHERE start = true
    LIMIT 1;
    
    -- Verificar si el símbolo inicial está en X[1, string_length]
    SELECT x INTO final_cell_vars
    FROM matriz_cyk
    WHERE i = 1 AND j = string_length;
    
    -- Verificar si el símbolo inicial está en el conjunto final
    is_accepted := grammar_start_symbol = ANY(final_cell_vars);
    
    RETURN is_accepted;
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


