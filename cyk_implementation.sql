-- ====================================
-- PARTE 3: IMPLEMENTACIÓN CYK EN PostgreSQL
-- ====================================

-- 1. Crear las tablas requeridas
CREATE TABLE IF NOT EXISTS GLC_en_FNC (
    start boolean,
    parte_izq text,
    parte_der1 text,
    parte_der2 text,
    tipo_produccion smallint
);

CREATE TABLE IF NOT EXISTS matriz_cyk (
    i smallint,
    j smallint,
    x text[],
    PRIMARY KEY (i, j)
);

-- Tabla auxiliar para almacenar el string a analizar
CREATE TABLE IF NOT EXISTS input_string (
    id serial PRIMARY KEY,
    string_value text,
    tokens text[],  -- Array de tokens extraídos del string
    longitud int
);

-- ====================================
-- 2. CARGAR GRAMÁTICA DE EJEMPLO (ajusta a tu gramática JSON)
-- ====================================
-- Ejemplo simple para probar (luego cargas tu gramática real)

DELETE FROM GLC_en_FNC;

-- Ejemplo: Gramática simple para expresiones
-- S -> AB | BC
-- A -> BA | a
-- B -> CC | b
-- C -> AB | a

INSERT INTO GLC_en_FNC VALUES (true, 'S', 'A', 'B', 2);
INSERT INTO GLC_en_FNC VALUES (false, 'S', 'B', 'C', 2);
INSERT INTO GLC_en_FNC VALUES (false, 'A', 'B', 'A', 2);
INSERT INTO GLC_en_FNC VALUES (false, 'A', 'a', null, 1);
INSERT INTO GLC_en_FNC VALUES (false, 'B', 'C', 'C', 2);
INSERT INTO GLC_en_FNC VALUES (false, 'B', 'b', null, 1);
INSERT INTO GLC_en_FNC VALUES (false, 'C', 'A', 'B', 2);
INSERT INTO GLC_en_FNC VALUES (false, 'C', 'a', null, 1);

-- ====================================
-- 3. FUNCIÓN PARA TOKENIZAR EL STRING
-- ====================================
CREATE OR REPLACE FUNCTION tokenizar_string(input_str text) 
RETURNS text[] AS $$
DECLARE
    tokens text[];
BEGIN
    -- Para JSON, necesitarás extraer: '{', '}', ':', ',', strings, números
    -- Este es un ejemplo simple, ajústalo a tu necesidad
    
    -- Opción 1: Split por caracteres individuales (para gramática simple)
    -- tokens := string_to_array(input_str, null);
    
    -- Opción 2: Expresión regular para extraer tokens JSON
    -- Aquí deberías implementar un tokenizador más sofisticado
    tokens := regexp_split_to_array(input_str, '');
    
    RETURN tokens;
END;
$$ LANGUAGE plpgsql;

-- ====================================
-- 4. FUNCIÓN PRINCIPAL: setear_matriz(fila)
-- ====================================
CREATE OR REPLACE FUNCTION setear_matriz(fila int) 
RETURNS void AS $$
DECLARE
    n int;
    i int;
    j int;
    k int;
    var_izq text;
    var_der1 text;
    var_der2 text;
    tipo int;
    token text;
    variables_encontradas text[];
    vars_B text[];
    vars_C text[];
    longitud_input int;
    tokens_input text[];
BEGIN
    -- Obtener el string tokenizado
    SELECT tokens, longitud INTO tokens_input, longitud_input 
    FROM input_string 
    ORDER BY id DESC 
    LIMIT 1;
    
    n := longitud_input;
    
    IF fila = 1 THEN
        -- CASO BASE: Llenar diagonal principal (Xii)
        FOR i IN 1..n LOOP
            token := tokens_input[i];
            variables_encontradas := ARRAY[]::text[];
            
            -- Buscar todas las variables que producen este terminal
            FOR var_izq, var_der1 IN 
                SELECT parte_izq, parte_der1 
                FROM GLC_en_FNC 
                WHERE tipo_produccion = 1 AND parte_der1 = token
            LOOP
                variables_encontradas := array_append(variables_encontradas, var_izq);
            END LOOP;
            
            -- Insertar en la matriz
            INSERT INTO matriz_cyk (i, j, x) 
            VALUES (i, i, variables_encontradas)
            ON CONFLICT (i, j) DO UPDATE SET x = EXCLUDED.x;
        END LOOP;
        
    ELSE
        -- CASO RECURSIVO: Llenar filas superiores
        FOR i IN 1..(n - fila + 1) LOOP
            j := i + fila - 1;
            variables_encontradas := ARRAY[]::text[];
            
            -- Para cada k entre i y j-1
            FOR k IN i..(j-1) LOOP
                -- Obtener Xi,k y Xk+1,j
                SELECT x INTO vars_B FROM matriz_cyk WHERE matriz_cyk.i = i AND matriz_cyk.j = k;
                SELECT x INTO vars_C FROM matriz_cyk WHERE matriz_cyk.i = k+1 AND matriz_cyk.j = j;
                
                -- Si alguno es NULL o vacío, continuar
                IF vars_B IS NULL OR vars_C IS NULL OR 
                   array_length(vars_B, 1) IS NULL OR array_length(vars_C, 1) IS NULL THEN
                    CONTINUE;
                END IF;
                
                -- Buscar producciones A -> BC donde B está en Xi,k y C está en Xk+1,j
                FOR var_izq IN
                    SELECT DISTINCT g.parte_izq
                    FROM GLC_en_FNC g
                    WHERE g.tipo_produccion = 2
                      AND g.parte_der1 = ANY(vars_B)
                      AND g.parte_der2 = ANY(vars_C)
                LOOP
                    -- Agregar si no existe
                    IF NOT (var_izq = ANY(variables_encontradas)) THEN
                        variables_encontradas := array_append(variables_encontradas, var_izq);
                    END IF;
                END LOOP;
            END LOOP;
            
            -- Insertar en la matriz
            INSERT INTO matriz_cyk (i, j, x) 
            VALUES (i, j, variables_encontradas)
            ON CONFLICT (i, j) DO UPDATE SET x = EXCLUDED.x;
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ====================================
-- 5. FUNCIÓN PRINCIPAL CYK
-- ====================================
CREATE OR REPLACE FUNCTION cyk(input_str text) 
RETURNS boolean AS $$
DECLARE
    n int;
    tokens_array text[];
    resultado boolean;
    simbolo_inicial text;
    vars_finales text[];
BEGIN
    -- Limpiar tablas
    DELETE FROM matriz_cyk;
    DELETE FROM input_string;
    
    -- Tokenizar y guardar el string
    tokens_array := tokenizar_string(input_str);
    n := array_length(tokens_array, 1);
    
    INSERT INTO input_string (string_value, tokens, longitud)
    VALUES (input_str, tokens_array, n);
    
    -- Ejecutar CYK para cada fila
    FOR i IN 1..n LOOP
        PERFORM setear_matriz(i);
    END LOOP;
    
    -- Verificar si el símbolo inicial está en X1,n
    SELECT parte_izq INTO simbolo_inicial 
    FROM GLC_en_FNC 
    WHERE start = true 
    LIMIT 1;
    
    SELECT x INTO vars_finales 
    FROM matriz_cyk 
    WHERE i = 1 AND j = n;
    
    -- Verificar si S está en el conjunto final
    resultado := (simbolo_inicial = ANY(vars_finales));
    
    RETURN resultado;
END;
$$ LANGUAGE plpgsql;

-- ====================================
-- PARTE 4: QUERIES PARA VISUALIZACIÓN
-- ====================================

-- Query para mostrar la gramática
CREATE OR REPLACE VIEW vista_gramatica AS
SELECT 
    CASE WHEN start THEN '→ ' ELSE '  ' END || parte_izq || ' → ' ||
    CASE 
        WHEN tipo_produccion = 1 THEN parte_der1
        WHEN tipo_produccion = 2 THEN parte_der1 || ' ' || parte_der2
    END AS produccion,
    start,
    tipo_produccion
FROM GLC_en_FNC
ORDER BY start DESC, parte_izq, tipo_produccion;

-- Query para mostrar la matriz CYK
CREATE OR REPLACE FUNCTION mostrar_matriz_cyk()
RETURNS TABLE(fila text) AS $$
DECLARE
    n int;
    i int;
    j int;
    fila_texto text;
    vars text;
BEGIN
    SELECT MAX(matriz_cyk.j) INTO n FROM matriz_cyk;
    
    -- Mostrar de arriba hacia abajo (invertido)
    FOR i IN REVERSE n..1 LOOP
        fila_texto := 'Fila ' || i || ': ';
        FOR j IN i..n LOOP
            SELECT array_to_string(x, ',') INTO vars 
            FROM matriz_cyk 
            WHERE matriz_cyk.i = i AND matriz_cyk.j = j;
            
            IF vars IS NULL OR vars = '' THEN
                vars := '∅';
            END IF;
            
            fila_texto := fila_texto || '{' || vars || '} ';
        END LOOP;
        fila := fila_texto;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ====================================
-- EJEMPLOS DE USO
-- ====================================

-- Ver la gramática cargada
-- SELECT * FROM vista_gramatica;

-- Probar el algoritmo CYK
-- SELECT cyk('baaba');

-- Ver la matriz resultante
-- SELECT * FROM mostrar_matriz_cyk();

-- Ver la matriz en formato tabla
-- SELECT i, j, array_to_string(x, ', ') as variables 
-- FROM matriz_cyk 
-- ORDER BY j-i DESC, i;