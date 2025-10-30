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
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para imprimir caja con bordes gruesos y redondeados
print_box() {
    local text="$1"
    local color="$2"
    local length=${#text}
    local width=$((length + 8))
    
    echo -e "${color}╭$(printf '─%.0s' $(seq 1 $width))╮${NC}"
    echo -e "${color}│    ${text}    │${NC}"
    echo -e "${color}╰$(printf '─%.0s' $(seq 1 $width))╯${NC}"
}

# Función para imprimir encabezado
print_header() {
    echo -e "${BLUE}╭────────────────────────────────────────────╮${NC}"
    echo -e "${BLUE}│           CYK Parser CLI                   │${NC}"
    echo -e "${BLUE}│           TP 2025C2                        │${NC}"
    echo -e "${BLUE}╰────────────────────────────────────────────╯${NC}"
}

# Función para imprimir separador
print_separator() {
    echo -e "${CYAN}────────────────────────────────────────────${NC}"
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
    print_box "Creando base de datos..." "$YELLOW"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;" 2>/dev/null
    if [ $? -eq 0 ]; then
        print_box "Base de datos creada exitosamente" "$GREEN"
    else
        print_box "La base de datos ya existe o hubo un error" "$YELLOW"
    fi
}

# Función para crear tablas
create_tables() {
    print_box "Creando tablas..." "$YELLOW"
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
    print_box "Tablas creadas exitosamente" "$GREEN"
}

# Función para crear funciones
create_functions() {
    print_box "Cargando funciones PL/pgSQL..." "$YELLOW"
    
    if [ -f "cyk_functions.sql" ]; then
        execute_sql_file "cyk_functions.sql"
        print_box "Funciones cargadas exitosamente" "$GREEN"
    else
        print_box "Error: archivo 'cyk_functions.sql' no encontrado" "$RED"
        return 1
    fi
}

# Función para cargar gramática
load_grammar() {
    echo ""
    print_box "Seleccione la gramática a cargar:" "$GREEN"
    echo -e "${CYAN}╭────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│  1. Gramática JSON                         │${NC}"
    echo -e "${CYAN}│  2. Gramática Paréntesis Balanceados       │${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────╯${NC}"
    echo -n -e "${YELLOW}Opción: ${NC}"
    read grammar_option

    case $grammar_option in
        1)
            grammar_file="load_grammar_json.sql"
            ;;
        2)
            grammar_file="load_grammar_parentesis.sql"
            ;;
        *)
            print_box "Opción inválida" "$RED"
            return 1
            ;;
    esac

    if [ ! -f "$grammar_file" ]; then
        print_box "Error: archivo '$grammar_file' no encontrado" "$RED"
        return 1
    fi

    print_box "Cargando gramática desde ${grammar_file}..." "$YELLOW"
    execute_sql_file "$grammar_file"
    print_box "Gramática cargada exitosamente" "$GREEN"
}

# Función para mostrar la gramática
show_grammar() {
    echo ""
    print_box "Gramática actual en FNC:" "$YELLOW"
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

# Función para parsear expresión
parse_expression() {
    local expression="$1"
    echo ""
    print_box "Parseando expresión:" "$YELLOW"
    echo -e "${CYAN}╭────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│   $expression${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────╯${NC}"
    
    result=$(execute_sql "SELECT cyk('$expression');" 2>&1)
    
    if [[ $result == *"t"* ]] || [[ $result == *"true"* ]]; then
        print_box "EXPRESIÓN VÁLIDA" "$GREEN"
        return 0
    else
        print_box "EXPRESIÓN INVÁLIDA" "$RED"
        return 1
    fi
}

# Función para mostrar matriz CYK
show_matrix() {
    echo ""
    print_box "Matriz CYK:" "$YELLOW"
    execute_sql "
    SELECT i, j, array_to_string(x, ', ') as variables
    FROM matriz_cyk
    ORDER BY j-i, i;
    "
}

# Función para limpiar tablas
clean_tables() {
    print_box "Limpiando tablas..." "$YELLOW"
    execute_sql "TRUNCATE TABLE matriz_cyk; TRUNCATE TABLE GLC_en_FNC RESTART IDENTITY;"
    print_box "Tablas limpiadas" "$GREEN"
}

# Menú principal
show_menu() {
    echo ""
    print_box "Menú Principal:" "$GREEN"
    echo -e "${CYAN}╭────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│  1. Crear/Inicializar base de datos        │${NC}"
    echo -e "${CYAN}│  2. Cargar gramática en FNC                │${NC}"
    echo -e "${CYAN}│  3. Mostrar gramática                      │${NC}"
    echo -e "${CYAN}│  4. Parsear expresión                      │${NC}"
    echo -e "${CYAN}│  5. Mostrar matriz CYK                     │${NC}"
    echo -e "${CYAN}│  6. Limpiar tablas                         │${NC}"
    echo -e "${CYAN}│  7. Salir                                  │${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────╯${NC}"
    echo -n -e "${YELLOW}Seleccione una opción: ${NC}"
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
                echo -n -e "${PURPLE}Ingrese la expresión: ${NC}"
                read expression
                parse_expression "$expression"
                ;;
            5)
                show_matrix
                ;;
            6)
                clean_tables
                ;;
            7)
                echo ""
                print_box "¡Hasta luego!" "$BLUE"
                echo ""
                exit 0
                ;;
            *)
                print_box "Opción inválida" "$RED"
                ;;
        esac
    done
}

# Ejecutar main
main
