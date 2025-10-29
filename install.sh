#!/bin/bash

# Script de instalación rápida para CYK Parser
# Trabajo Práctico - Teoría de la Computación 2025C2

echo "================================================"
echo "   Instalación CYK Parser - TP 2025C2"
echo "================================================"
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
DB_NAME="cyk_parser"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5432"

echo -e "${BLUE}Configuración:${NC}"
echo "  Base de datos: $DB_NAME"
echo "  Usuario: $DB_USER"
echo "  Host: $DB_HOST"
echo "  Puerto: $DB_PORT"
echo ""

# Verificar si PostgreSQL está instalado
echo -e "${YELLOW}Verificando PostgreSQL...${NC}"
if ! command -v psql &> /dev/null; then
    echo -e "${RED}✗ PostgreSQL no está instalado${NC}"
    echo "Por favor instala PostgreSQL primero:"
    echo "  Ubuntu/Debian: sudo apt install postgresql postgresql-contrib"
    echo "  Arch Linux: sudo pacman -S postgresql"
    echo "  Fedora: sudo dnf install postgresql-server"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL encontrado${NC}"

# Verificar conexión a PostgreSQL
echo -e "${YELLOW}Verificando conexión...${NC}"
if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "SELECT 1;" &> /dev/null; then
    echo -e "${RED}✗ No se pudo conectar a PostgreSQL${NC}"
    echo "Verifica que:"
    echo "  1. PostgreSQL esté corriendo: sudo systemctl status postgresql"
    echo "  2. El usuario '$DB_USER' exista"
    echo "  3. Las credenciales sean correctas"
    exit 1
fi
echo -e "${GREEN}✓ Conexión exitosa${NC}"

# Crear base de datos
echo -e "${YELLOW}Creando base de datos '$DB_NAME'...${NC}"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Base de datos creada${NC}"
else
    echo -e "${YELLOW}⚠ La base de datos ya existe (continuando)${NC}"
fi

# Verificar si existe el archivo de funciones
if [ ! -f "cyk_functions.sql" ]; then
    echo -e "${RED}✗ No se encontró el archivo 'cyk_functions.sql'${NC}"
    echo "Asegúrate de tener el archivo en el mismo directorio"
    exit 1
fi

# Crear tablas y funciones
echo -e "${YELLOW}Creando tablas...${NC}"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
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
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Tablas creadas${NC}"
else
    echo -e "${RED}✗ Error al crear tablas${NC}"
    exit 1
fi

# Cargar funciones PL/pgSQL
echo -e "${YELLOW}Cargando funciones PL/pgSQL...${NC}"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "cyk_functions.sql" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Funciones cargadas${NC}"
else
    echo -e "${RED}✗ Error al cargar funciones${NC}"
    exit 1
fi

# Cargar gramática
echo -e "${YELLOW}Cargando gramática en FNC...${NC}"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF' > /dev/null 2>&1
TRUNCATE TABLE GLC_en_FNC RESTART IDENTITY;

-- Símbolo inicial y estructura básica
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) 
VALUES 
    (true, 'S', 'I', 'D', 2),
    (false, 'I', '{', NULL, 1),
    (false, 'D', '}', NULL, 1),
    (false, 'S', 'I', 'R', 2),
    (false, 'R', 'A', 'D', 2);

-- Comillas y strings
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) 
VALUES 
    (false, 'Q', '''', NULL, 1),
    (false, 'S', 'Q', 'K', 2),
    (false, 'K', 'C', 'Q', 2),
    (false, 'J', '"', NULL, 1),
    (false, 'S', 'J', 'H', 2),
    (false, 'H', 'C', 'J', 2);

-- Pares clave-valor
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) 
VALUES 
    (false, 'G', 'Y', 'E', 2),
    (false, 'A', 'X', 'F', 2),
    (false, 'F', 'P', 'G', 2),
    (false, 'P', ':', NULL, 1),
    (false, 'A', 'X', 'U', 2),
    (false, 'U', 'P', 'Y', 2),
    (false, 'X', 'J', 'H', 2);

-- Valores
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) 
VALUES 
    (false, 'Y', 'Q', 'K', 2),
    (false, 'Y', 'J', 'H', 2),
    (false, 'Y', 'I', 'D', 2),
    (false, 'Y', 'I', 'R', 2),
    (false, 'E', 'W', 'A', 2),
    (false, 'W', ',', NULL, 1);

-- Terminales: números
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) 
SELECT false, 'S', n::TEXT, NULL, 1 FROM generate_series(1,9) n
UNION ALL
SELECT false, 'Y', n::TEXT, NULL, 1 FROM generate_series(1,9) n
UNION ALL
SELECT false, 'N', n::TEXT, NULL, 1 FROM generate_series(1,9) n
UNION ALL
SELECT false, 'C', n::TEXT, NULL, 1 FROM generate_series(1,9) n;

-- Terminales: letras
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) 
SELECT false, 'L', chr(n), NULL, 1 FROM generate_series(97,122) n
UNION ALL
SELECT false, 'C', chr(n), NULL, 1 FROM generate_series(97,122) n;

-- Producciones de contenido
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) 
VALUES 
    (false, 'C', 'L', 'C', 2),
    (false, 'C', 'N', 'C', 2),
    (false, 'C', ' ', NULL, 1),
    (false, 'N', 'N', 'N', 2),
    (false, 'S', 'N', 'N', 2),
    (false, 'Y', 'N', 'N', 2),
    (false, 'C', 'N', 'N', 2);
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Gramática cargada${NC}"
else
    echo -e "${RED}✗ Error al cargar gramática${NC}"
    exit 1
fi

# Verificar instalación
echo ""
echo -e "${YELLOW}Verificando instalación...${NC}"
test_result=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT cyk('{}');" 2>&1 | tr -d ' ')

if [[ "$test_result" == "t" ]] || [[ "$test_result" == "true" ]]; then
    echo -e "${GREEN}✓ Test básico pasado: {} es reconocido${NC}"
else
    echo -e "${RED}✗ Test básico falló${NC}"
    echo "Respuesta: $test_result"
fi

# Mostrar estadísticas
echo ""
echo -e "${BLUE}Estadísticas de la gramática:${NC}"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM estadisticas_gramatica();"

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}   ✓ Instalación completada exitosamente${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Comandos disponibles:${NC}"
echo "  ./cyk_cli.sh                    # Ejecutar CLI interactivo"
echo "  psql -U $DB_USER -d $DB_NAME    # Conectar directamente"
echo ""
echo -e "${BLUE}Ejemplos de uso:${NC}"
echo "  SELECT cyk('{}');"
echo "  SELECT cyk('{\"a\":10}');"
echo "  SELECT * FROM vista_gramatica;"
echo "  SELECT ejecutar_todos_los_tests();"
echo ""
