/* aula14.sql: Processamento Nativo
 * Copyright (C) 2016 Daniela Petruzalek
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
  O objetivo desta pr�tica � demonstrar os benef�cios da compila��o nativa
  e dos tipos de dados nativos
*/

-- Os scripts desta pr�tica usam dbms_output como sa�da
SET serveroutput ON

-- Verificar que o par�metro PLSQL_CODE_TYPE est� como INTERPRETED
show parameter PLSQL_CODE_TYPE;

-- Voc� pode controlar o tipo de compila��o por par�metro de sistema (acima),
-- por sess�o ou por objeto. Para mudar o tipo de compila��o por sess�o, voc�
-- pode executar:

-- Para interpretado:
ALTER SESSION SET PLSQL_CODE_TYPE = INTERPRETED;

-- Para nativo:
ALTER SESSION SET PLSQL_CODE_TYPE = NATIVE;

-- View que mostra propriedades do c�digo
SELECT NAME, 
       TYPE, 
       PLSQL_OPTIMIZE_LEVEL, 
       PLSQL_CODE_TYPE
  FROM user_plsql_object_settings u
 ORDER BY PLSQL_CODE_TYPE;

-------------------------
-- CEN�RIO 1: FATORIAL --
-------------------------

-- Cria fun��o Fatorial
CREATE OR REPLACE FUNCTION fatorial(numero NUMBER)
RETURN NUMBER
AS
BEGIN
  CASE WHEN numero = 1
       THEN RETURN 1;
       WHEN numero = 0
       THEN RETURN 1;
       WHEN numero < 0
       THEN raise zero_divide;
       ELSE RETURN fatorial(numero - 1) * numero;
  END CASE;
END;
/

ALTER FUNCTION fatorial COMPILE PLSQL_CODE_TYPE=INTERPRETED;

-- Executa fun��o fatorial para todos os n�meros de 1 a 30000
-- Tempo Esperado : 161 segundos
-- Tempo Decorrido: ? segundos
DROP TABLE t_fatorial;
CREATE TABLE t_fatorial AS
SELECT ROWNUM numero, fatorial(ROWNUM) fat_numero 
  FROM dual CONNECT BY LEVEL <= 30000;
  
-- Compila a fun��o como c�digo NATIVO
ALTER FUNCTION fatorial COMPILE PLSQL_CODE_TYPE=NATIVE;

-- Conferindo
SELECT NAME, TYPE, PLSQL_OPTIMIZE_LEVEL, PLSQL_CODE_TYPE
  FROM user_plsql_object_settings u
 WHERE PLSQL_CODE_TYPE = 'NATIVE';

-- Executa fun��o fatorial para todos os n�meros de 1 a 30000 (nativo)
-- Tempo Esperado : 97 segundos
-- Tempo Decorrido: ? segundos
DROP TABLE t_fatorial2;
CREATE TABLE t_fatorial2 AS
SELECT ROWNUM numero, fatorial(ROWNUM) fat_numero 
  FROM dual CONNECT BY LEVEL <= 30000;

-- Embora o c�digo nativo acima tenha benef�cios sobre o interpretado
-- ainda � gasto bastante tempo com trocas de contexto SQL <-> PLSQL
--
-- O cen�rio abaixo explora o mesmo conceito, por�m com PLSQL puro
CREATE OR REPLACE PROCEDURE calcula_fatorial(limite NUMBER) 
AS
  inicio NUMBER := dbms_utility.get_time;
  fim    NUMBER;
  
  fat    NUMBER;
BEGIN
  FOR i IN 1 .. limite
  loop
    fat  := fatorial(i);
  END loop;
  
  dbms_output.put_line('Tempo Decorrido: ' || 
                        to_char(dbms_utility.get_time - inicio) ||
                        ' hsecs');
END;
/

ALTER FUNCTION  fatorial         COMPILE PLSQL_CODE_TYPE=INTERPRETED;
ALTER PROCEDURE calcula_fatorial COMPILE PLSQL_CODE_TYPE=INTERPRETED;

-- Tempo esperado:
--  10000 -  1964 hsecs
--  30000 - 15995 hsecs
--  50000 - 49023 hsecs
BEGIN
  calcula_fatorial(10000);
END;
/

ALTER FUNCTION  fatorial         COMPILE PLSQL_CODE_TYPE=NATIVE;
ALTER PROCEDURE calcula_fatorial COMPILE PLSQL_CODE_TYPE=NATIVE;

-- Tempo esperado:
--  10000 -   789 hsecs
--  30000 -  9434 hsecs
--  50000 - 27832 hsecs
BEGIN
  calcula_fatorial(10000);
END;
/

-- O plsql_optimize_level � o par�metro que define qual � o n�vel de
-- otimiza��o que o compilador do PLSQL vai aplicar no c�digo fonte
--
-- O n�vel padr�o � o n�vel 2. No n�vel 3, ele tenta transformar chamadas
-- de fun��o em fun��o inline. Como o fatorial � uma fun��o recursiva, ele
-- pode se beneficiar desta t�cnica de otimiza��o.
ALTER FUNCTION  fatorial         COMPILE PLSQL_CODE_TYPE=NATIVE PLSQL_OPTIMIZE_LEVEL=3;
ALTER PROCEDURE calcula_fatorial COMPILE PLSQL_CODE_TYPE=NATIVE PLSQL_OPTIMIZE_LEVEL=3;

-- Tempo esperado:
--  10000 -   789 hsecs
--  30000 -  9434 hsecs
--  50000 - 27832 hsecs
BEGIN
  calcula_fatorial(10000);
END;
/


-------------------------------
-- CEN�RIO 2: N�MEROS PRIMOS --
-------------------------------

-- Esta fun��o testa se um n�mero � primo ou n�o
CREATE OR REPLACE FUNCTION primo(numero NUMBER)
RETURN boolean
AS
  x NUMBER := 3;
BEGIN
  CASE WHEN numero = 1
       THEN RETURN FALSE;
       WHEN numero = 2
       THEN RETURN TRUE;
       WHEN numero < 1
       THEN RETURN FALSE;
       WHEN mod(numero, 2) = 0
       THEN RETURN FALSE;
       ELSE
          loop
            exit WHEN x > trunc(sqrt(numero) + 1);
            IF mod(numero, x) = 0 THEN 
              RETURN FALSE;
            END IF;
            x := x + 2;
          END loop;
          RETURN TRUE;
  END CASE;
END;
/

-- Esta procedure testa todos os n�meros de 1 at� o 'limite'
-- e retorna o n�mero de primos encontrados.
CREATE OR REPLACE PROCEDURE calcula_primos(limite NUMBER)
AS
  x NUMBER := 1;
  t NUMBER := dbms_utility.get_time;
  
  num_primos NUMBER := 0;
BEGIN
  loop
    exit WHEN x > limite;
    IF primo(x) THEN
      --dbms_output.put_line(x);
      num_primos := num_primos + 1;
    END IF;
    x := x + 1;
  END loop;
  
  dbms_output.put_line('N�meros primos : ' || num_primos || ' n�meros primos');
  dbms_output.put_line('Tempo Decorrido: ' || 
                        to_char(dbms_utility.get_time - t) || ' hsecs');
END;
/

-- Tempo esperado: 
--  1.000.000 -  1453 hsecs
--  5.000.000 - 16110 hsecs
-- 10.000.000 - 43384 hsecs
BEGIN
  calcula_primos(100000);
END;
/

ALTER FUNCTION  primo          COMPILE PLSQL_CODE_TYPE=NATIVE;
ALTER PROCEDURE calcula_primos COMPILE PLSQL_CODE_TYPE=NATIVE;

-- Tempo esperado: 
--  1.000.000 -  1225 hsecs
--  5.000.000 - 15076 hsecs
-- 10.000.000 - 40962 hsecs
BEGIN
  calcula_primos(5000000);
END;
/

-- Esta procedure repete uma opera��o de soma num_loops vezes para
-- cada tipo de dado num�rico e exibe um relat�rio de tempo no final
CREATE OR REPLACE PROCEDURE testa_numeros_inteiros(num_loops NUMBER)
AS
  l_number1          NUMBER := 1;
  l_number2          NUMBER := 1;
  l_integer1         INTEGER := 1;
  l_integer2         INTEGER := 1;
  l_pls_integer1     pls_integer := 1;
  l_pls_integer2     pls_integer := 1;
  l_binary_integer1  binary_integer := 1;
  l_binary_integer2  binary_integer := 1;
  l_simple_integer1  binary_integer := 1;
  l_simple_integer2  binary_integer := 1;
  l_loops            NUMBER := num_loops;
  l_start            NUMBER;
BEGIN
  -- Time NUMBER.
  l_start := dbms_utility.get_time;
  
  FOR i IN 1 .. l_loops loop
    l_number1 := l_number1 + l_number2;
  END loop;
  
  dbms_output.put_line('NUMBER         : ' ||
                       (dbms_utility.get_time - l_start) || ' hsecs');

  -- Time INTEGER.
  l_start := dbms_utility.get_time;
  
  FOR i IN 1 .. l_loops loop
    l_integer1 := l_integer1 + l_integer2;
  END loop;
  
  dbms_output.put_line('INTEGER        : ' ||
                       (dbms_utility.get_time - l_start) || ' hsecs');

  -- Time PLS_INTEGER.
  l_start := dbms_utility.get_time;
  
  FOR i IN 1 .. l_loops loop
    l_pls_integer1 := l_pls_integer1 + l_pls_integer2;
  END loop;
  
  dbms_output.put_line('PLS_INTEGER    : ' ||
                       (dbms_utility.get_time - l_start) || ' hsecs');

  -- Time BINARY_INTEGER.
  l_start := dbms_utility.get_time;
  
  FOR i IN 1 .. l_loops loop
    l_binary_integer1 := l_binary_integer1 + l_binary_integer2;
  END loop;
  
  dbms_output.put_line('BINARY_INTEGER : ' ||
                       (dbms_utility.get_time - l_start) || ' hsecs');

  -- Time SIMPLE_INTEGER.
  l_start := dbms_utility.get_time;
  
  FOR i IN 1 .. l_loops loop
    l_simple_integer1 := l_simple_integer1 + l_simple_integer2;
  END loop;
  
  dbms_output.put_line('SIMPLE_INTEGER : ' ||
                       (dbms_utility.get_time - l_start) || ' hsecs');
END testa_numeros_inteiros;
/

-- Testando primeiro interpretada
ALTER PROCEDURE testa_numeros_inteiros COMPILE PLSQL_CODE_TYPE=INTERPRETED;

-- Observe a diferen�a de tempo em cada tipo de dado
BEGIN
  testa_numeros_inteiros(50000000);
END;
/
SET serveroutput ON

-- Agora como nativa
ALTER PROCEDURE testa_numeros_inteiros COMPILE PLSQL_CODE_TYPE=NATIVE;

-- Observe novamente as diferen�as de tempo
BEGIN
  testa_numeros_inteiros(50000000);
END;
/

-- Esta procedure repete uma opera��o de soma num_loops vezes para cada tipo de
-- dado num�rico de ponto flutuante e exibe um relat�rio de tempo no final
CREATE OR REPLACE PROCEDURE testa_numeros_ponto_flutuante(num_loops NUMBER)
AS 
  l_number1         NUMBER := 1.1;
  l_number2         NUMBER := 1.1;
  l_binary_float1   BINARY_FLOAT := 1.1;
  l_binary_float2   BINARY_FLOAT := 1.1;
  l_simple_float1   simple_float := 1.1;
  l_simple_float2   simple_float := 1.1;
  l_binary_double1  BINARY_DOUBLE := 1.1;
  l_binary_double2  BINARY_DOUBLE := 1.1;
  l_simple_double1  simple_double := 1.1;
  l_simple_double2  simple_double := 1.1;
  l_loops           NUMBER := num_loops;
  l_start           NUMBER;
BEGIN
  -- Time NUMBER.
  l_start := dbms_utility.get_time;
  
  FOR i IN 1 .. l_loops loop
    l_number1 := l_number1 + l_number2;
  END loop;
  
  dbms_output.put_line('NUMBER         : ' ||
                       (dbms_utility.get_time - l_start) || ' hsecs');

  -- Time BINARY_FLOAT.
  l_start := dbms_utility.get_time;
  
  FOR i IN 1 .. l_loops loop
    l_binary_float1 := l_binary_float1 + l_binary_float2;
  END loop;
  
  dbms_output.put_line('BINARY_FLOAT   : ' ||
                       (dbms_utility.get_time - l_start) || ' hsecs');

  -- Time SIMPLE_FLOAT.
  l_start := dbms_utility.get_time;
  
  FOR i IN 1 .. l_loops loop
    l_simple_float1 := l_simple_float1 + l_simple_float2;
  END loop;
  
  dbms_output.put_line('SIMPLE_FLOAT   : ' ||
                       (dbms_utility.get_time - l_start) || ' hsecs');

  -- Time BINARY_DOUBLE.
  l_start := dbms_utility.get_time;
  
  FOR i IN 1 .. l_loops loop
    l_binary_double1 := l_binary_double1 + l_binary_double2;
  END loop;
  
  dbms_output.put_line('BINARY_DOUBLE  : ' ||
                       (dbms_utility.get_time - l_start) || ' hsecs');

  -- Time SIMPLE_DOUBLE.
  l_start := dbms_utility.get_time;
  
  FOR i IN 1 .. l_loops loop
    l_simple_double1 := l_simple_double1 + l_simple_double2;
  END loop;
  
  dbms_output.put_line('SIMPLE_DOUBLE  : ' ||
                       (dbms_utility.get_time - l_start) || ' hsecs');
END testa_numeros_ponto_flutuante;
/

-- Iniciando com compila��o interpretada
ALTER PROCEDURE testa_numeros_ponto_flutuante COMPILE PLSQL_CODE_TYPE=INTERPRETED;

-- Repare nos tempos
BEGIN
  testa_numeros_ponto_flutuante(50000000);
END;
/

-- Agora com compila��o nativa
ALTER PROCEDURE testa_numeros_ponto_flutuante COMPILE PLSQL_CODE_TYPE=NATIVE;

-- O que aconteceu com os tempos?
BEGIN
  testa_numeros_ponto_flutuante(50000000);
END;
/
