/* aula16.sql: Técnicas de Cache
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
  O objetivo desta prática é demonstrar as diferentes técnicas de cache 
  disponíveis no banco Oracle 12c.
*/

------------------
-- RESULT CACHE --
------------------

/*
  Vamos começar demonstrando a feature RESULT CACHE, desde a sua configuração, 
  passando pelas funcionalidades da dbms_result_cache, as principais views de 
  performance e finalmente o seu uso nas formas SQL query result cache e PL/SQL
  result cache.
*/

-- mostra parâmetros relacionados
show parameter result_cache;

/*
  dbms_result_cache
 */
 
-- Estado atual do result cache
SELECT dbms_result_cache.status FROM dual;

-- Relatório de uso
SET serveroutput ON
exec dbms_result_cache.memory_report(detailed => TRUE);

-- detalhes sobre o uso da memória
SELECT *
  FROM v$result_cache_memory;

-- objetos que estão em cache
SELECT *
  FROM v$result_cache_objects;

-- objetos do usuário atual que estão em cache
SELECT *
  FROM v$result_cache_objects
 WHERE creator_uid = UID; -- uid = user id

-- estatísticas de uso do result cache
SELECT *
  FROM v$result_cache_statistics;

/*
  SQL QUERY RESULT CACHE
 */

-- Veja o plano de execução da query a seguir
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

-- Verificando que o objeto está no cache
SELECT *
  FROM v$result_cache_objects
 WHERE creator_uid = UID; -- uid = user id

/*
  PL/SQL RESULT CACHE
 */

-- Executar como SYS do PDB
-- vamos precisar desta package para simular o processamento de uma função
GRANT EXECUTE ON dbms_lock TO curso;
 
-- Esta função gasta 1 segundo para cada chamada e retorna o valor de entrada
-- O objetivo é parecer uma função "pesada"
CREATE OR REPLACE FUNCTION func_nocache(pval IN NUMBER)
RETURN NUMBER
AS
BEGIN
  dbms_lock.sleep(1);
  
  RETURN pval;
END;
/

-- Este vai ser o nosso cursor de referência
SELECT ROWNUM ID
  FROM dual CONNECT BY LEVEL <= 10;

-- Para cada linha do cursor de referência vamos chamar a função uma vez
-- com o rownum como parâmetro (valores de 1 a 10)
SELECT ROWNUM ID, func_nocache(ROWNUM)
  FROM dual CONNECT BY LEVEL <= 10;

-- É a mesma query, execute ela novamente... teve diferença no tempo?
SELECT ROWNUM ID, func_nocache(ROWNUM)
  FROM dual CONNECT BY LEVEL <= 10;

-- Agora a mesma função está sendo criada com a cláusula result_cache
CREATE OR REPLACE FUNCTION func_cache(pval IN NUMBER)
RETURN NUMBER result_cache
AS
BEGIN
  dbms_lock.sleep(1);
  
  RETURN pval;
END;
/

-- Executando a primeira vez... até agora nenhuma diferença porque o resultado
-- da função nova não está no cache
SELECT ROWNUM ID, func_cache(ROWNUM)
  FROM dual CONNECT BY LEVEL <= 10;

-- Executando novamente, agora os resultados estão em cache...
SELECT ROWNUM ID, func_cache(ROWNUM)
  FROM dual CONNECT BY LEVEL <= 10;

-- Limpeza do cache
exec dbms_result_cache.FLUSH;

-- Zerado
SELECT count(*)
  FROM v$result_cache_objects;

-- Além disso, se você executar a query acima novamente vai ver que ela estará
-- "trabalhando" de novo

-------------------
-- DETERMINISTIC --
-------------------

-- Vamos começar criando uma tabela auxiliar de 10 linhas, mas com alguns
-- valores repetidos.
DROP TABLE tab_10_linhas;
CREATE TABLE tab_10_linhas AS
SELECT mod(ROWNUM,4) linha FROM dual CONNECT BY LEVEL <= 10;

-- O script original tem 4 valores (divisor do rownum), mas fique a vontade
-- para experimentar outras possibilidades
SELECT count(DISTINCT linha) FROM tab_10_linhas;

-- Cria a mesma função do exemplo anterior, mas com a propriedade
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
-- Executar os próximos dois blocos no sqlplus --
-------------------------------------------------

-- Ativa exibição do tempo decorrido
SET timing ON
-- Tamanho do FETCH
SET arraysize 15

-- Chama a função n vezes... quantas?
SELECT linha, func_det(linha)
  FROM tab_10_linhas;
  
-- Muda o tamanho do fetch para 2 linhas
SET arraysize 2

-- Chama a função n vezes... quantas?
SELECT linha, func_det(linha)
  FROM tab_10_linhas;

-----------------------------------
----- fim do trecho SQL*Plus ------
-----------------------------------



-----------------------------
-- SCALAR SUBQUERY CACHING --
-----------------------------

/*
  Para demonstrar este recurso, poderíamos utilizar a mesma função anterior
  mas vamos usar a técnica de manter um contador de execuções para ficar
  mais claro.
*/
DROP TABLE t16;
CREATE TABLE t16 AS
SELECT 1 cnt FROM dual WHERE 1=0;

-- Tabela T16 só tem um campo NUMBER
DESC t16

-- Inicializa a tabela com o contador em zero
INSERT INTO t16 VALUES(0);
COMMIT;

-- A função é a mesma: retorna o valor de entrada, porém internamente
-- adicionamos o mecanismo de contador
CREATE OR REPLACE FUNCTION func1 (pnum IN NUMBER)
RETURN NUMBER
AS
  -- Esta função realiza uma transação independente do SELECT que chama ela
  pragma autonomous_transaction;
BEGIN
  UPDATE t16 SET cnt = cnt + 1;
  COMMIT;
  
  RETURN pnum;
END;
/

-- Uma chamada da função
SELECT func1(1) FROM dual;

-- Testando o contador
SELECT cnt FROM t16;

-- Executando a função para cada linha da tabela
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

-- Scalar Subquery Cache para vários valores
SELECT linha, (SELECT func1(linha) FROM dual) 
  FROM tab_10_linhas;

-- Quantas chamadas?
SELECT cnt FROM t16;

----------------------------
-- USER DEFINED FUNCTIONS --
----------------------------

DROP TABLE t1 PURGE;

-- 1 milhão de linhas com o mesmo valor
CREATE TABLE t1 AS
SELECT 1 AS id
FROM   dual
CONNECT BY level <= 1000000;

-- Função de teste: retorna o valor passado por parâmetro
CREATE OR REPLACE FUNCTION normal_function(p_id IN NUMBER) RETURN NUMBER IS
BEGIN
  RETURN p_id;
END;
/

-- O código abaixo vai comparar a performance da definição INLINE com a cláusula
-- WITH versus a função normal
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

-- Agora vamos redefinir a função normal para incluir a cláusula PRAGMA UDF
CREATE OR REPLACE FUNCTION normal_function(p_id IN NUMBER) RETURN NUMBER IS
  PRAGMA UDF; -- única mudança
BEGIN
  RETURN p_id;
END;
/

-- Mesmo teste de performance, agora com a função compilada com PRAGMA UDF
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
  Alguns pontos de atenção: 
  
  A documentação sobre o PRAGMA UDF é praticamente inexistente. Pouco sabemos 
  sobre como é implementada e como funciona, porém o manual documenta esta opção
  como sendo potencialmente benéfica, sem promessas de ganhos, mas também sem 
  contra-indicações. De modo geral, vale a pena sinalizar funções que são
  predominantemente chamadas por SQL como UDF.
  
  Testes empíricos mostram sobre a definição inline de funções (na cláusula
  WITH) funciona combinada com a técnica de SCALAR SUBQUERY CACHING, porém 
  desabilita as otimizações de funções determinísticas.
  
  Mais detalhes no artigo:
  https://oracle-base.com/articles/12c/with-clause-enhancements-12cr1#pragma-udf
 */