
-- GRAMÁTICA PARA JSON

-- Limpiamos la tabla
TRUNCATE TABLE GLC_en_FNC RESTART IDENTITY;

-- Reglas iniciales de la gramática
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) VALUES
(true, 'S', 'I', 'D', 2),
(true, 'S', 'I', 'R', 2),
(false, 'I', '{', NULL, 1),
(false, 'D', '}', NULL, 1),
(false, 'R', 'A', 'D', 2),
(false, 'Q', '''', NULL, 1),
(false, 'K', 'C', 'Q', 2),
(false, 'J', '"', NULL, 1),
(false, 'H', 'C', 'J', 2),
(false, 'G', 'Y', 'E', 2),
(false, 'A', 'X', 'F', 2),
(false, 'F', 'P', 'G', 2),
(false, 'P', ':', NULL, 1),
(false, 'A', 'X', 'U', 2),
(false, 'U', 'P', 'Y', 2),
(false, 'X', 'J', 'H', 2),
(false, 'Y', 'Q', 'K', 2),
(false, 'Y', 'J', 'H', 2),
(false, 'Y', 'I', 'D', 2),
(false, 'Y', 'I', 'R', 2),
(false, 'E', 'W', 'A', 2),
(false, 'W', ',', NULL, 1);

-- Y → 1..9 | NN
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) VALUES
(false, 'Y', '1', NULL, 1),
(false, 'Y', '2', NULL, 1),
(false, 'Y', '3', NULL, 1),
(false, 'Y', '4', NULL, 1),
(false, 'Y', '5', NULL, 1),
(false, 'Y', '6', NULL, 1),
(false, 'Y', '7', NULL, 1),
(false, 'Y', '8', NULL, 1),
(false, 'Y', '9', NULL, 1),
(false, 'Y', 'N', 'N', 2);

-- L → a..z
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) VALUES
(false, 'L', 'a', NULL, 1),
(false, 'L', 'b', NULL, 1),
(false, 'L', 'c', NULL, 1),
(false, 'L', 'd', NULL, 1),
(false, 'L', 'e', NULL, 1),
(false, 'L', 'f', NULL, 1),
(false, 'L', 'g', NULL, 1),
(false, 'L', 'h', NULL, 1),
(false, 'L', 'i', NULL, 1),
(false, 'L', 'j', NULL, 1),
(false, 'L', 'k', NULL, 1),
(false, 'L', 'l', NULL, 1),
(false, 'L', 'm', NULL, 1),
(false, 'L', 'n', NULL, 1),
(false, 'L', 'o', NULL, 1),
(false, 'L', 'p', NULL, 1),
(false, 'L', 'q', NULL, 1),
(false, 'L', 'r', NULL, 1),
(false, 'L', 's', NULL, 1),
(false, 'L', 't', NULL, 1),
(false, 'L', 'u', NULL, 1),
(false, 'L', 'v', NULL, 1),
(false, 'L', 'w', NULL, 1),
(false, 'L', 'x', NULL, 1),
(false, 'L', 'y', NULL, 1),
(false, 'L', 'z', NULL, 1);

-- N → 1..9 | NN
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) VALUES
(false, 'N', '1', NULL, 1),
(false, 'N', '2', NULL, 1),
(false, 'N', '3', NULL, 1),
(false, 'N', '4', NULL, 1),
(false, 'N', '5', NULL, 1),
(false, 'N', '6', NULL, 1),
(false, 'N', '7', NULL, 1),
(false, 'N', '8', NULL, 1),
(false, 'N', '9', NULL, 1),
(false, 'N', 'N', 'N', 2);

-- C → LC | NC
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) VALUES
(false, 'C', 'L', 'C', 2),
(false, 'C', 'N', 'C', 2);

-- C → a..z | 1..9 | NN
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) VALUES
(false, 'C', 'a', NULL, 1),
(false, 'C', 'b', NULL, 1),
(false, 'C', 'c', NULL, 1),
(false, 'C', 'd', NULL, 1),
(false, 'C', 'e', NULL, 1),
(false, 'C', 'f', NULL, 1),
(false, 'C', 'g', NULL, 1),
(false, 'C', 'h', NULL, 1),
(false, 'C', 'i', NULL, 1),
(false, 'C', 'j', NULL, 1),
(false, 'C', 'k', NULL, 1),
(false, 'C', 'l', NULL, 1),
(false, 'C', 'm', NULL, 1),
(false, 'C', 'n', NULL, 1),
(false, 'C', 'o', NULL, 1),
(false, 'C', 'p', NULL, 1),
(false, 'C', 'q', NULL, 1),
(false, 'C', 'r', NULL, 1),
(false, 'C', 's', NULL, 1),
(false, 'C', 't', NULL, 1),
(false, 'C', 'u', NULL, 1),
(false, 'C', 'v', NULL, 1),
(false, 'C', 'w', NULL, 1),
(false, 'C', 'x', NULL, 1),
(false, 'C', 'y', NULL, 1),
(false, 'C', 'z', NULL, 1),
(false, 'C', '1', NULL, 1),
(false, 'C', '2', NULL, 1),
(false, 'C', '3', NULL, 1),
(false, 'C', '4', NULL, 1),
(false, 'C', '5', NULL, 1),
(false, 'C', '6', NULL, 1),
(false, 'C', '7', NULL, 1),
(false, 'C', '8', NULL, 1),
(false, 'C', '9', NULL, 1),
(false, 'C', 'N', 'N', 2);