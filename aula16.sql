/* aula16.sql: T�cnicas de Cache
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
  O objetivo desta pr�tica � demonstrar as diferentes t�cnicas de cache 
  dispon�veis no banco Oracle 12c.
*/

------------------
-- RESULT CACHE --
------------------

/*
  Vamos come�ar demonstrando a feature RESULT CACHE, desde a sua configura��o, 
  passando pelas funcionalidades da dbms_result_cache, as principais views de 
  performance e finalmente o seu uso nas formas SQL query result cache e PL/SQL
  result cache.
*/

-- mostra par�metros relacionados
show parameter result_cache;

/*
  dbms_result_cache
 */
 
-- Estado atual do result cache
SELECT dbms_result_cache.status FROM dual;

-- Relat�rio de uso
SET serveroutput ON
exec dbms_result_cache.memory_report(detailed => TRUE);

-- detalhes sobre o uso da mem�ria
SELECT *
  FROM v$result_cache_memory;

-- objetos que est�o em cache
SELECT *
  FROM v$result_cache_objects;

-- objetos do usu�rio atual que est�o em cache
SELECT *
  FROM v$result_cache_objects
 WHERE creator_uid = UID; -- uid = user id

-- estat�sticas de uso do result cache
SELECT *
  FROM v$result_cache_statistics;

/*
  SQL QUERY RESULT CACHE
 */

-- Veja o plano de execu��o da query a seguir
EXPLAIN PLAN FOR
SELECT o.customer_id,
       sum(oi.unit_price * oi.quantity) total_compras
  FROM oe.orders      o,
       oe.order_items oi
 WHERE o.order_id = oi.order_id
 GROUP BY customer_id;
 
SELECT plan_table_output
  FROM TABLE(dbms_xplan.display);

-- Agora vamos rodar a query com result cache
SELECT --+ RESULT_CACHE
       o.customer_id,
       sum(oi.unit_price * oi.quantity) total_compras
  FROM oe.orders      o,
       oe.order_items oi
 WHERE o.order_id = oi.order_id
 GROUP BY customer_id;

-- Compare os planos
EXPLAIN PLAN FOR
SELECT --+ RESULT_CACHE
       o.customer_id,
       sum(oi.unit_price * oi.quantity) total_compras
  FROM oe.orders      o,
       oe.order_items oi
 WHERE o.order_id = oi.order_id
 GROUP BY customer_id;

SELECT plan_table_output
  FROM TABLE(dbms_xplan.display);

-- Verificando que o objeto est� no cache
SELECT *
  FROM v$result_cache_objects
 WHERE creator_uid = UID; -- uid = user id

/*
  PL/SQL RESULT CACHE
 */

-- Executar como SYS do PDB
-- vamos precisar desta package para simular o processamento de uma fun��o
GRANT EXECUTE ON dbms_lock TO curso;
 
-- Esta fun��o gasta 1 segundo para cada chamada e retorna o valor de entrada
-- O objetivo � parecer uma fun��o "pesada"
CREATE OR REPLACE FUNCTION func_nocache(pval IN NUMBER)
RETURN NUMBER
AS
BEGIN
  dbms_lock.sleep(1);
  
  RETURN pval;
END;
/

-- Este vai ser o nosso cursor de refer�ncia
SELECT ROWNUM ID
  FROM dual CONNECT BY LEVEL <= 10;

-- Para cada linha do cursor de refer�ncia vamos chamar a fun��o uma vez
-- com o rownum como par�metro (valores de 1 a 10)
SELECT ROWNUM ID, func_nocache(ROWNUM)
  FROM dual CONNECT BY LEVEL <= 10;

-- � a mesma query, execute ela novamente... teve diferen�a no tempo?
SELECT ROWNUM ID, func_nocache(ROWNUM)
  FROM dual CONNECT BY LEVEL <= 10;

-- Agora a mesma fun��o est� sendo criada com a cl�usula result_cache
CREATE OR REPLACE FUNCTION func_cache(pval IN NUMBER)
RETURN NUMBER result_cache
AS
BEGIN
  dbms_lock.sleep(1);
  
  RETURN pval;
END;
/

-- Executando a primeira vez... at� agora nenhuma diferen�a porque o resultado
-- da fun��o nova n�o est� no cache
SELECT ROWNUM ID, func_cache(ROWNUM)
  FROM dual CONNECT BY LEVEL <= 10;

-- Executando novamente, agora os resultados est�o em cache...
SELECT ROWNUM ID, func_cache(ROWNUM)
  FROM dual CONNECT BY LEVEL <= 10;

-- Limpeza do cache
exec dbms_result_cache.FLUSH;

-- Zerado
SELECT count(*)
  FROM v$result_cache_objects;

-- Al�m disso, se voc� executar a query acima novamente vai ver que ela estar�
-- "trabalhando" de novo

-------------------
-- DETERMINISTIC --
-------------------

-- Vamos come�ar criando uma tabela auxiliar de 10 linhas, mas com alguns
-- valores repetidos.
DROP TABLE tab_10_linhas;
CREATE TABLE tab_10_linhas AS
SELECT mod(ROWNUM,4) linha FROM dual CONNECT BY LEVEL <= 10;

-- O script original tem 4 valores (divisor do rownum), mas fique a vontade
-- para experimentar outras possibilidades
SELECT count(DISTINCT linha) FROM tab_10_linhas;

-- Cria a mesma fun��o do exemplo anterior, mas com a propriedade
-- DETERMINISTIC.
CREATE OR REPLACE FUNCTION func_det(pval IN NUMBER)
RETURN NUMBER deterministic
AS
BEGIN
  dbms_lock.sleep(1);
  
  RETURN pval;
END;
/

-------------------------------------------------
-- Executar os pr�ximos dois blocos no sqlplus --
-------------------------------------------------

-- Ativa exibi��o do tempo decorrido
SET timing ON
-- Tamanho do FETCH
SET arraysize 15

-- Chama a fun��o n vezes... quantas?
SELECT linha, func_det(linha)
  FROM tab_10_linhas;
  
-- Muda o tamanho do fetch para 2 linhas
SET arraysize 2

-- Chama a fun��o n vezes... quantas?
SELECT linha, func_det(linha)
  FROM tab_10_linhas;

-----------------------------------
----- fim do trecho SQL*Plus ------
-----------------------------------



-----------------------------
-- SCALAR SUBQUERY CACHING --
-----------------------------

/*
  Para demonstrar este recurso, poder�amos utilizar a mesma fun��o anterior
  mas vamos usar a t�cnica de manter um contador de execu��es para ficar
  mais claro.
*/
DROP TABLE t16;
CREATE TABLE t16 AS
SELECT 1 cnt FROM dual WHERE 1=0;

-- Tabela T16 s� tem um campo NUMBER
DESC t16

-- Inicializa a tabela com o contador em zero
INSERT INTO t16 VALUES(0);
COMMIT;

-- A fun��o � a mesma: retorna o valor de entrada, por�m internamente
-- adicionamos o mecanismo de contador
CREATE OR REPLACE FUNCTION func1 (pnum IN NUMBER)
RETURN NUMBER
AS
  -- Esta fun��o realiza uma transa��o independente do SELECT que chama ela
  pragma autonomous_transaction;
BEGIN
  UPDATE t16 SET cnt = cnt + 1;
  COMMIT;
  
  RETURN pnum;
END;
/

-- Uma chamada da fun��o
SELECT func1(1) FROM dual;

-- Testando o contador
SELECT cnt FROM t16;

-- Executando a fun��o para cada linha da tabela
SELECT linha, func1(linha) 
  FROM tab_10_linhas;

-- 10 linhas, 10 chamadas... confere?
SELECT cnt FROM t16;

-- Chamada com o mesmo valor
SELECT linha, func1(1) 
  FROM tab_10_linhas;

-- Ainda assim, 10 chamadas
SELECT cnt FROM t16;

-- Scalar Subquery Cache para um valor
SELECT linha, (SELECT func1(1) FROM dual) 
  FROM tab_10_linhas;

-- Quantas chamadas?
SELECT cnt FROM t16;

-- Scalar Subquery Cache para v�rios valores
SELECT linha, (SELECT func1(linha) FROM dual) 
  FROM tab_10_linhas;

-- Quantas chamadas?
SELECT cnt FROM t16;

----------------------------
-- USER DEFINED FUNCTIONS --
----------------------------

DROP TABLE t1 PURGE;

-- 1 milh�o de linhas com o mesmo valor
CREATE TABLE t1 AS
SELECT 1 AS id
FROM   dual
CONNECT BY level <= 1000000;

-- Fun��o de teste: retorna o valor passado por par�metro
CREATE OR REPLACE FUNCTION normal_function(p_id IN NUMBER) RETURN NUMBER IS
BEGIN
  RETURN p_id;
END;
/

-- O c�digo abaixo vai comparar a performance da defini��o INLINE com a cl�usula
-- WITH versus a fun��o normal
SET SERVEROUTPUT ON
DECLARE
  l_time    PLS_INTEGER;
  l_cpu     PLS_INTEGER;
  
  l_sql     VARCHAR2(32767);
  l_cursor  SYS_REFCURSOR;
  
  TYPE t_tab IS TABLE OF NUMBER;
  l_tab t_tab;
BEGIN
  l_time := DBMS_UTILITY.get_time;
  l_cpu  := DBMS_UTILITY.get_cpu_time;

  l_sql := 'WITH
              FUNCTION with_function(p_id IN NUMBER) RETURN NUMBER IS
              BEGIN
                RETURN p_id;
              END;
            SELECT with_function(id)
            FROM   t1';
            
  OPEN l_cursor FOR l_sql;
  FETCH l_cursor
  BULK COLLECT INTO l_tab;
  CLOSE l_cursor;
  
  DBMS_OUTPUT.put_line('WITH_FUNCTION  : ' ||
                       'Time=' || TO_CHAR(DBMS_UTILITY.get_time - l_time) || ' hsecs ' ||
                       'CPU Time=' || (DBMS_UTILITY.get_cpu_time - l_cpu) || ' hsecs ');

  l_time := DBMS_UTILITY.get_time;
  l_cpu  := DBMS_UTILITY.get_cpu_time;

  l_sql := 'SELECT normal_function(id)
            FROM   t1';
            
  OPEN l_cursor FOR l_sql;
  FETCH l_cursor
  BULK COLLECT INTO l_tab;
  CLOSE l_cursor;
  
  DBMS_OUTPUT.put_line('NORMAL_FUNCTION: ' ||
                       'Time=' || TO_CHAR(DBMS_UTILITY.get_time - l_time) || ' hsecs ' ||
                       'CPU Time=' || (DBMS_UTILITY.get_cpu_time - l_cpu) || ' hsecs ');
 
END;
/

-- Agora vamos redefinir a fun��o normal para incluir a cl�usula PRAGMA UDF
CREATE OR REPLACE FUNCTION normal_function(p_id IN NUMBER) RETURN NUMBER IS
  PRAGMA UDF; -- �nica mudan�a
BEGIN
  RETURN p_id;
END;
/

-- Mesmo teste de performance, agora com a fun��o compilada com PRAGMA UDF
SET SERVEROUTPUT ON
DECLARE
  l_time    PLS_INTEGER;
  l_cpu     PLS_INTEGER;
  
  l_sql     VARCHAR2(32767);
  l_cursor  SYS_REFCURSOR;
  
  TYPE t_tab IS TABLE OF NUMBER;
  l_tab t_tab;
BEGIN
  l_time := DBMS_UTILITY.get_time;
  l_cpu  := DBMS_UTILITY.get_cpu_time;

  l_sql := 'WITH
              FUNCTION with_function(p_id IN NUMBER) RETURN NUMBER IS
              BEGIN
                RETURN p_id;
              END;
            SELECT with_function(id)
            FROM   t1';
            
  OPEN l_cursor FOR l_sql;
  FETCH l_cursor
  BULK COLLECT INTO l_tab;
  CLOSE l_cursor;
  
  DBMS_OUTPUT.put_line('WITH_FUNCTION  : ' ||
                       'Time=' || TO_CHAR(DBMS_UTILITY.get_time - l_time) || ' hsecs ' ||
                       'CPU Time=' || (DBMS_UTILITY.get_cpu_time - l_cpu) || ' hsecs ');

  l_time := DBMS_UTILITY.get_time;
  l_cpu  := DBMS_UTILITY.get_cpu_time;

  l_sql := 'SELECT normal_function(id)
            FROM   t1';
            
  OPEN l_cursor FOR l_sql;
  FETCH l_cursor
  BULK COLLECT INTO l_tab;
  CLOSE l_cursor;
  
  DBMS_OUTPUT.put_line('NORMAL_FUNCTION: ' ||
                       'Time=' || TO_CHAR(DBMS_UTILITY.get_time - l_time) || ' hsecs ' ||
                       'CPU Time=' || (DBMS_UTILITY.get_cpu_time - l_cpu) || ' hsecs ');
 
END;
/

/*
  Alguns pontos de aten��o: 
  
  A documenta��o sobre o PRAGMA UDF � praticamente inexistente. Pouco sabemos 
  sobre como � implementada e como funciona, por�m o manual documenta esta op��o
  como sendo potencialmente ben�fica, sem promessas de ganhos, mas tamb�m sem 
  contra-indica��es. De modo geral, vale a pena sinalizar fun��es que s�o
  predominantemente chamadas por SQL como UDF.
  
  Testes emp�ricos mostram sobre a defini��o inline de fun��es (na cl�usula
  WITH) funciona combinada com a t�cnica de SCALAR SUBQUERY CACHING, por�m 
  desabilita as otimiza��es de fun��es determin�sticas.
  
  Mais detalhes no artigo:
  https://oracle-base.com/articles/12c/with-clause-enhancements-12cr1#pragma-udf
 */