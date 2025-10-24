#!/bin/bash

# CYK Parser CLI - Trabajo Práctico Teoría de la Computación
# CLI para gestionar el parser CYK en PostgreSQL

DB_NAME="cyk_parser"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5432"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir encabezado
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}   CYK Parser CLI - TP 2025C2${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Función para ejecutar SQL
execute_sql() {
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$1"
}

# Función para ejecutar archivo SQL
execute_sql_file() {
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$1"
}

# Función para crear base de datos
create_database() {
    echo -e "${YELLOW}Creando base de datos...${NC}"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Base de datos creada exitosamente${NC}"
    else
        echo -e "${YELLOW}La base de datos ya existe o hubo un error${NC}"
    fi
}

# Función para crear tablas
create_tables() {
    echo -e "${YELLOW}Creando tablas...${NC}"
    execute_sql "
    CREATE TABLE IF NOT EXISTS GLC_en_FNC (
        id SERIAL PRIMARY KEY,
        start BOOLEAN,
        parte_izq TEXT,
        parte_der1 TEXT,
        parte_der2 TEXT,
        tipo_produccion SMALLINT
    );

    CREATE INDEX IF NOT EXISTS idx_parte_izq ON GLC_en_FNC(parte_izq);
    CREATE INDEX IF NOT EXISTS idx_start ON GLC_en_FNC(start);
    CREATE INDEX IF NOT EXISTS idx_tipo ON GLC_en_FNC(tipo_produccion);

    CREATE TABLE IF NOT EXISTS matriz_cyk (
        i SMALLINT,
        j SMALLINT,
        x TEXT[],
        PRIMARY KEY (i, j)
    );

    CREATE TABLE IF NOT EXISTS json_input (
        id SERIAL PRIMARY KEY,
        json_string TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    "
    echo -e "${GREEN}Tablas creadas exitosamente${NC}"
}

# Función para crear funciones
create_functions() {
    echo -e "${YELLOW}Cargando funciones PL/pgSQL...${NC}"
    
    if [ -f "cyk_functions.sql" ]; then
        execute_sql_file "cyk_functions.sql"
        echo -e "${GREEN}Funciones cargadas exitosamente${NC}"
    else
        echo -e "${RED}Error: archivo 'cyk_functions.sql' no encontrado${NC}"
        return 1
    fi
}

# Función para cargar gramática
load_grammar() {
    echo -e "${YELLOW}Cargando gramática en FNC...${NC}"
    
    # Primero limpiamos la tabla
    execute_sql "TRUNCATE TABLE GLC_en_FNC RESTART IDENTITY;"
    
    # Insertamos todas las producciones
    execute_sql_file "load_grammar.sql"

    
    echo -e "${GREEN}Gramática cargada exitosamente${NC}"
}


# Función para mostrar la gramática
show_grammar() {
    echo -e "${YELLOW}Gramática actual en FNC:${NC}"
    execute_sql "
    SELECT 
        CASE WHEN start THEN '→' ELSE ' ' END as inicio,
        parte_izq || ' → ' || 
        COALESCE(parte_der1, '') || 
        COALESCE(' ' || parte_der2, '') as produccion,
        CASE 
            WHEN tipo_produccion = 1 THEN 'Terminal'
            WHEN tipo_produccion = 2 THEN 'Variables'
        END as tipo
    FROM GLC_en_FNC 
    ORDER BY start DESC, parte_izq, tipo_produccion, parte_der1;
    "
}

# Función para parsear JSON
parse_json() {
    local json_string="$1"
    echo -e "${YELLOW}Parseando: ${NC}$json_string"
    
    result=$(execute_sql "SELECT cyk('$json_string');" 2>&1)
    
    if [[ $result == *"t"* ]] || [[ $result == *"true"* ]]; then
        echo -e "${GREEN}✓ JSON VÁLIDO${NC}"
        return 0
    else
        echo -e "${RED}✗ JSON INVÁLIDO${NC}"
        return 1
    fi
}

# Función para mostrar matriz CYK
show_matrix() {
    echo -e "${YELLOW}Matriz CYK:${NC}"
    execute_sql "
    SELECT i, j, array_to_string(x, ', ') as variables
    FROM matriz_cyk
    ORDER BY j-i, i;
    "
}

# Menú principal
show_menu() {
    echo ""
    echo -e "${GREEN}Opciones:${NC}"
    echo "1. Crear/Inicializar base de datos"
    echo "2. Cargar gramática en FNC"
    echo "3. Mostrar gramática"
    echo "4. Parsear expresión JSON"
    echo "5. Mostrar matriz CYK"
    echo "6. Ejecutar tests"
    echo "7. Limpiar tablas"
    echo "8. Salir"
    echo ""
    echo -n "Seleccione una opción: "
}

# Función para ejecutar tests
run_tests() {
    echo -e "${YELLOW}Ejecutando tests unitarios...${NC}"
    
    tests=(
        '{"a":10}'
        '{"a":10,"b":"hola"}'
        '{}'
    )
    
    passed=0
    failed=0
    
    for test in "${tests[@]}"; do
        echo ""
        echo -e "${BLUE}Test: $test${NC}"
        if parse_json "$test"; then
            ((passed++))
        else
            ((failed++))
        fi
    done
    
    echo ""
    echo -e "${GREEN}Tests pasados: $passed${NC}"
    echo -e "${RED}Tests fallidos: $failed${NC}"
}

# Función para limpiar tablas
clean_tables() {
    echo -e "${YELLOW}Limpiando tablas...${NC}"
    execute_sql "TRUNCATE TABLE matriz_cyk; TRUNCATE TABLE GLC_en_FNC RESTART IDENTITY;"
    echo -e "${GREEN}Tablas limpiadas${NC}"
}

# Main loop
main() {
    print_header
    
    while true; do
        show_menu
        read option
        
        case $option in
            1)
                create_database
                create_tables
                create_functions
                ;;
            2)
                load_grammar
                ;;
            3)
                show_grammar
                ;;
            4)
                echo -n "Ingrese la expresión JSON: "
                read json_expr
                parse_json "$json_expr"
                ;;
            5)
                show_matrix
                ;;
            6)
                run_tests
                ;;
            7)
                clean_tables
                ;;
            8)
                echo -e "${BLUE}¡Hasta luego!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Opción inválida${NC}"
                ;;
        esac
    done
}

# Ejecutar main
main