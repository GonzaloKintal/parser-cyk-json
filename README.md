# Trabajo Práctico: Algoritmo CYK en PostgreSQL (PL/pgSQL)

Proyecto del 2do semestre de 2025 para la materia de Teoría de la Computación. Implementa el algoritmo de parsing CYK sobre una Gramática Libre de Contexto (GLC) en Forma Normal de Chomsky (FNC), utilizando funciones en PL/pgSQL y tablas en PostgreSQL. Incluye tablas y funciones para cargar una gramática, tokenizar un string de entrada, ejecutar el algoritmo y visualizar tanto la gramática como la matriz triangular de CYK.


## 🧩 Descripción general

- CYK (Cocke–Younger–Kasami) es un algoritmo de parsing bottom-up que determina si un string pertenece al lenguaje generado por una GLC en FNC.
- El algoritmo construye una matriz triangular X[i,j] donde cada celda contiene el conjunto de variables que generan el substring desde la posición i hasta j del string de entrada.
- El string es reconocido si el símbolo inicial S pertenece a la celda X[1,n], donde n es la longitud del string tokenizado.

Este TP abarca:
- Diseño de una GLC que reconoce expresiones JSON simples (o cualquier otro lenguaje elegido).
- Normalización de esa GLC a FNC (algoritmos de limpieza y conversión a FNC).
- Implementación del algoritmo CYK en SQL (PL/pgSQL) con tablas y funciones.
- Ejecución de pruebas y visualizaciones.


## ⚙️ Requisitos del entorno

- PostgreSQL
- PL/pgSQL habilitado (activado por defecto en PostgreSQL)
- Permisos para crear tablas, vistas y funciones en el esquema de trabajo
- Cliente psql o GUI (pgAdmin, DBeaver, etc.)

Verificación rápida desde psql:

```sql
-- Debe devolver plpgsql
SHOW plpgsql.variable_conflict;
-- Si se requiere, asegurar que plpgsql está disponible (ya lo está por defecto)
```


## 🗂️ Estructura del proyecto

Archivo principal:
- cyk_implementation.sql

Tablas obligatorias:
- GLC_en_FNC(start boolean, parte_izq text, parte_der1 text, parte_der2 text, tipo_produccion smallint)
- matriz_cyk(i smallint, j smallint, x text[])
- input_string(id serial, string_value text, tokens text[], longitud int)

Funciones implementadas:
- tokenizar_string(input_str text) returns text[]
- setear_matriz(fila int) returns void
- cyk(input_str text) returns boolean
- mostrar_matriz_cyk() returns setof record (fila text)

Vista:
- vista_gramatica

Observación: las tablas GLC_en_FNC y matriz_cyk siguen exactamente el formato solicitado en el enunciado para facilitar la corrección.


## 🧠 Resumen del algoritmo CYK

1. Precondición: la gramática debe estar en FNC (producciones del tipo A→BC o A→a). Se define un único símbolo inicial S (start = true en la tabla GLC_en_FNC).
2. Dado un string de entrada w de longitud n (luego de tokenización):
   - Se inicializa la diagonal principal X[i,i] con todas las variables A tales que A→w[i].
   - Para longitudes l = 2..n: para cada intervalo (i,j) con j = i + l - 1:
     - Para cada k en [i..j-1], se calculan combinaciones Xi,k y Xk+1,j; por cada producción A→BC, si B∈Xi,k y C∈Xk+1,j entonces A∈Xi,j.
3. Aceptación: w pertenece al lenguaje si S ∈ X[1,n].

En este proyecto, X[i,j] se almacena en la tabla matriz_cyk como un arreglo text[] con las variables correspondientes.


## 💾 Instalación y ejecución

1) Crear objetos de base de datos
- Abrir psql (o su cliente preferido) en el esquema de trabajo y ejecutar el script:

```sql
\i path/a/tu/proyecto/cyk_implementation.sql
```

Este script:
- Crea las tablas GLC_en_FNC, matriz_cyk e input_string.
- Crea las funciones tokenizar_string, setear_matriz, cyk y mostrar_matriz_cyk.
- Crea la vista vista_gramatica.
- Inserta una gramática de ejemplo sencilla (útil para pruebas iniciales). Reemplace luego por su propia gramática en FNC.

2) Cargar una gramática en FNC
- La tabla GLC_en_FNC se carga con INSERT por cada producción. Estructura:
  - start: true solo para el símbolo inicial S (exactamente una fila con true).
  - parte_izq: variable a la izquierda (A, B, ...).
  - parte_der1: terminal (si tipo_produccion=1) o primera variable (si tipo_produccion=2).
  - parte_der2: segunda variable (si tipo_produccion=2), NULL si tipo_produccion=1.
  - tipo_produccion: 1 para A→a, 2 para A→BC.

Ejemplo de inserción (del script):

```sql
-- S -> A B
INSERT INTO GLC_en_FNC VALUES (true, 'S', 'A', 'B', 2);
```

3) Ejecutar el algoritmo CYK
- Usar la función principal cyk(text). La función internamente tokeniza, inicializa la matriz y ejecuta CYK.

```sql
SELECT cyk('baaba');
-- devuelve true/false
```

4) Visualizar la gramática

```sql
SELECT * FROM vista_gramatica;
```

5) Mostrar la matriz CYK (visualización por filas)

```sql
SELECT * FROM mostrar_matriz_cyk();
```

6) Explorar la matriz cruda (opcional)

```sql
SELECT i, j, array_to_string(x, ', ') AS variables
FROM matriz_cyk
ORDER BY j - i DESC, i;
```


## 🧪 Ejemplos de uso

Con la gramática de ejemplo incluida en el script (didáctica):

Gramática (resumen):
- S → A B | B C
- A → B A | a
- B → C C | b
- C → A B | a

Ejemplo 1:
```sql
SELECT cyk('baaba');
-- Esperado: boolean (puede ser true según la gramática de ejemplo)
```

Ejemplo 2:
```sql
SELECT cyk('abba');
-- Esperado: boolean
```

Ejemplo 3 (no reconocido):
```sql
SELECT cyk('cccc');
-- Esperado: false (según producciones de la gramática de ejemplo)
```

Para JSON u otro lenguaje, reemplace las producciones en GLC_en_FNC y ajuste la tokenización si es necesario (ver nota más abajo).


## 🔍 Pruebas unitarias sugeridas (3 tests)

- Test 1: String válido reconocido (caso positivo)
  - Input: 'baaba'
  - Precondición: gramática de ejemplo cargada.
  - Resultado esperado: true.
  - Comandos:
    ```sql
    SELECT cyk('baaba') AS reconocido;
    SELECT * FROM mostrar_matriz_cyk();
    ```

- Test 2: String no reconocido (caso negativo)
  - Input: 'bbbbba'
  - Resultado esperado: false.
  - Comandos:
    ```sql
    SELECT cyk('bbbbba') AS reconocido;
    ```

- Test 3: Visualización de gramática y consistencia
  - Acción: listar producciones y verificar que existe exactamente un start=true.
  - Comandos:
    ```sql
    SELECT * FROM vista_gramatica;
    SELECT COUNT(*) FROM GLC_en_FNC WHERE start = true;  -- Esperado: 1
    ```

Si adopta una gramática JSON, reemplace las entradas de GLC_en_FNC y ajuste los tests para inputs JSON válidos e inválidos.


## 🧱 Gramática para JSON (opcional)

- Este proyecto es compatible con cualquier GLC en FNC.
- Para JSON con números, strings alfabéticos/blancos y objetos anidados, se recomienda:
  - Definir una gramática conceptual primero (parte 1),
  - Limpiarla y convertirla a FNC (parte 2),
  - Cargar la FNC en GLC_en_FNC (parte 3).
- Nota: la función tokenizar_string del script contiene una implementación simple (usa regexp_split_to_array por caracteres). Para JSON real, deberá implementar un tokenizador que extraiga llaves { }, dos puntos :, comas ,, strings entre comillas y números enteros. Luego, asegúrese de que los terminales de la gramática coincidan exactamente con los tokens generados.


## 🧑‍💻 Autores / Grupo

- Integrante 1 — Legajo: _____
- Integrante 2 — Legajo: _____
- Integrante 3 — Legajo: _____
- Integrante 4 — Legajo: _____


## 📚 Notas adicionales

- Proyecto de carácter didáctico para evidenciar el ciclo completo de un parser: diseño de GLC, normalización a FNC, e implementación de parsing.
- La parte 1 (diseño de gramática) y la parte 2 (normalización a FNC) se presentan en documentos de texto aparte. Este repositorio provee la parte 3 (implementación CYK) y parte 4 (visualización), además de facilitar la parte 5 (cambio de gramática).
- Puede utilizarse cualquier gramática en FNC para probar el algoritmo. La tabla GLC_en_FNC puede borrarse y recargarse con una nueva gramática; evite perder datos haciendo respaldos si es necesario.
- Rendimiento: para strings largos, considere índices sobre GLC_en_FNC(parte_der1, parte_der2, tipo_produccion) y sobre matriz_cyk(i, j).
- Ejecución de demo: prepare al menos tres casos de prueba (dos positivos y uno negativo) y muestre la matriz y la gramática en pantalla.


## 📝 Referencias breves

- Cocke, Younger, Kasami: algoritmo CYK para GLC en FNC.
- Documentación PostgreSQL — PL/pgSQL.
