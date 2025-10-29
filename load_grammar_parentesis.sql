
-- GRAMÁTICA PARA PARÉNTESIS BALANCEADOS

-- Limpiamos la tabla
TRUNCATE TABLE GLC_en_FNC RESTART IDENTITY;

-- Gramática en FNC para paréntesis balanceados
INSERT INTO GLC_en_FNC (start, parte_izq, parte_der1, parte_der2, tipo_produccion) VALUES
(true,  'S', 'A', 'B', 2),     -- S -> A B    <-- producción base para ()
(true,  'S', 'A', 'X', 2),     -- S -> A X    (anidamiento)
(true,  'S', 'S', 'S', 2),     -- S -> S S    (concatenación)
(false, 'X', 'S', 'B', 2),     -- X -> S B
(false, 'A', '(', NULL, 1),    -- A -> (
(false, 'B', ')', NULL, 1);    -- B -> )