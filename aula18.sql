/* aula18.sql: Modelagem Física
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
  O objetivo desta prática é demonstrar o impacto de alterações na modelagem
  física dos objetos.
*/

--------------------
-- INDEX COMPRESS --
--------------------

/*
  Neste cenário vamos criar uma tabela com dados artificiais para simular a
  compressão de índices com diferentes ordens de coluna.
*/

DROP TABLE t;
CREATE TABLE t(pedido PRIMARY KEY, produto, cliente, dt_pedido) AS
SELECT ROWNUM            pedido,
       mod(ROWNUM, 1000) produto,
       mod(ROWNUM, 100)  cliente,
       SYSDATE + mod(ROWNUM, 100) dt_pedido
  FROM dual CONNECT BY LEVEL <= 1000000;
  
-- Criação dos índices
CREATE INDEX t_idx1 ON t(pedido, produto, cliente);
CREATE INDEX t_idx2 ON t(produto, cliente);
CREATE INDEX t_idx3 ON t(produto, cliente, dt_pedido);
CREATE INDEX t_idx4 ON t(cliente, produto, pedido);
CREATE INDEX t_idx5 ON t(cliente);

-- Esta é uma tabela auxiliar que será utilizada pela package a seguir
CREATE TABLE idx_stats AS
SELECT * FROM INDEX_STATS;

-- Esta package automatiza o processo de análise e compactação dos índices
--
-- A rotina idx_compress_analyze calcula o prefixo ideal e a compactação
-- estimada.
--
-- A rotina idx_compress_execute executa a compactação recomendada para todos
-- os índices cujo pctsave for maior igual ao seu parâmetro (default 10)
--
CREATE OR REPLACE PACKAGE pkg_idx_compress AS

  PROCEDURE idx_compress_analyze;
  PROCEDURE idx_compress_execute(pctsave NUMBER DEFAULT 10);

END pkg_idx_compress;
/

CREATE OR REPLACE PACKAGE BODY pkg_idx_compress AS

PROCEDURE idx_compress_analyze AS
BEGIN
  FOR r IN (SELECT USER AS owner,
                   index_name
              FROM user_indexes)
  loop
    EXECUTE IMMEDIATE 'analyze index ' || r.owner || '.' || r.index_name || ' validate structure';
    INSERT INTO idx_stats SELECT * FROM INDEX_STATS;
  END loop;
  COMMIT;
 
END idx_compress_analyze;

PROCEDURE idx_compress_execute(pctsave NUMBER DEFAULT 10) AS
BEGIN
  FOR r IN (SELECT USER AS owner, NAME, opt_cmpr_count FROM idx_stats WHERE opt_cmpr_pctsave >= pctsave)
  loop
    EXECUTE IMMEDIATE 'alter index ' || r.owner || '.' || r.NAME || ' rebuild compress ' || r.opt_cmpr_count;
  END loop;
 
END idx_compress_execute;

END pkg_idx_compress;
/

-- Índices antes da compactação
SELECT table_name, index_name, bytes / 1024 AS kbytes, compression
  FROM user_indexes  ui,
       user_segments us
 WHERE ui.index_name = us.segment_name;

-- Análise
BEGIN
  pkg_idx_compress.idx_compress_analyze;
END;
/

-- Resultado da análise e estimativas
SELECT USER AS owner,
       NAME AS index_name,
       opt_cmpr_count,
       opt_cmpr_pctsave
  FROM idx_stats;
  
-- Executa compactação
BEGIN
  pkg_idx_compress.idx_compress_execute;
END;
/

-- Resultado
SELECT table_name, index_name, bytes / 1024 AS kbytes, compression
  FROM user_indexes  ui,
       user_segments us
 WHERE ui.index_name = us.segment_name;
 
--------------------
-- COMPRESSED IOT --
--------------------

-- Estamos usando uma pk com ordem atípica apenas para demonstrar a taxa de
-- compactação
DROP TABLE t2;
CREATE TABLE t2(pedido, produto, cliente, dt_pedido, CONSTRAINT pk_t2 PRIMARY KEY(cliente, produto, pedido))
ORGANIZATION INDEX AS SELECT * FROM t;

-- Observe o tamanho
SELECT table_name, index_name, bytes / 1024 AS kbytes, compression
  FROM user_indexes  ui,
       user_segments us
 WHERE ui.index_name = us.segment_name
   AND ui.table_name = 'T2';

-- Lembrando que a PK não tem apenas o índice, mas também os dados
ANALYZE INDEX pk_t2 VALIDATE STRUCTURE;

-- Estimativa de compressão e número ideal de colunas
SELECT NAME, opt_cmpr_count, opt_cmpr_pctsave FROM INDEX_STATS;

-- Para compactar, usamos o alter table move ao invés de alter index rebuild
-- mas a sintaxe do compress continua sendo COMPRESS [número de colunas]
ALTER TABLE t2 MOVE ONLINE COMPRESS 2;

-- Compare o tamanho
SELECT table_name, index_name, bytes / 1024 AS kbytes, compression
  FROM user_indexes  ui,
       user_segments us
 WHERE ui.index_name = us.segment_name
   AND ui.table_name = 'T2';

--------------------------------
-- COMPRESSION e PARTITIONING --
--------------------------------

/*
  Para demonstrar os recursos de compressão e particionamento, nós vamos criar 
  três tabelas: uma tabela com compressão ativada, uma tabela com compressão e
  particionamento (com diferentes níveis de compressão para cada partição) e
  uma tabela sem compressão.
*/

-- Compressão básica
DROP TABLE test_tab_1;
CREATE TABLE test_tab_1 (
  ID            NUMBER(10)    NOT NULL,
  description   VARCHAR2(50)  NOT NULL,
  created_date  DATE          NOT NULL
) ROW STORE COMPRESS;

-- Definindo níveis diferentes de compressão para cada partição
DROP TABLE test_tab_2;
CREATE TABLE test_tab_2 (
  ID            NUMBER(10)    NOT NULL,
  description   VARCHAR2(50)  NOT NULL,
  created_date  DATE          NOT NULL
)
PARTITION BY RANGE (created_date) (
  PARTITION test_tab_q1 VALUES LESS THAN (to_date('01/04/2008', 'DD/MM/YYYY')) ROW STORE COMPRESS,
  PARTITION test_tab_q2 VALUES LESS THAN (to_date('01/07/2008', 'DD/MM/YYYY')) ROW STORE COMPRESS basic,
  PARTITION test_tab_q3 VALUES LESS THAN (to_date('01/10/2008', 'DD/MM/YYYY')) ROW STORE COMPRESS advanced,
  PARTITION test_tab_q4 VALUES LESS THAN (MAXVALUE) NOCOMPRESS
);

-- Tabela sem compressão, também será a nossa fonte de dados
--
-- Repare que as oportunidades para compressão nesta tabela são a repetição da
-- descrição e as datas.
DROP TABLE t_nocompress;
CREATE TABLE t_nocompress AS
SELECT ROWNUM ID, 
       'descricao ' || mod(ROWNUM, 10) description, 
       to_date('01/01/2008', 'DD/MM/YYYY') + trunc(dbms_random.VALUE(0,3600)) created_date
  FROM dual CONNECT BY LEVEL <= 1000000;

-- distribuição de datas
SELECT created_date, count(*)
  FROM t_nocompress
 GROUP BY created_date;

-- Visualizando a compressão por tabela...
SELECT table_name, compression, compress_for 
  FROM user_tables
 WHERE table_name IN ('TEST_TAB_1', 'TEST_TAB_2', 'T_NOCOMPRESS');

-- E por partição
SELECT table_name, partition_name, compression, compress_for
  FROM user_tab_partitions
 WHERE table_name IN ('TEST_TAB_1', 'TEST_TAB_2', 'T_NOCOMPRESS');
 
 -- Estamos fazendo um direct path insert para que os dados sejam comprimidos
 INSERT /*+ append */ INTO test_tab_1
 SELECT * FROM t_nocompress;
 
 -- Estamos fazendo um direct path insert para que os dados sejam comprimidos
 INSERT /*+ append */ INTO test_tab_2
 SELECT * FROM t_nocompress;

COMMIT;

-- Comparação de tamanho
SELECT segment_name, partition_name, segment_type, bytes / 1024 kbytes
  FROM user_segments
 WHERE segment_name IN ('TEST_TAB_1', 'TEST_TAB_2', 'T_NOCOMPRESS', 
                        'TEST_TAB_Q1', 'TEST_TAB_Q2', 'TEST_TAB_Q3', 
                        'TEST_TAB_Q4');

BEGIN
  dbms_stats.gather_table_stats(USER, 'TEST_TAB_1');
  dbms_stats.gather_table_stats(USER, 'TEST_TAB_2');
  dbms_stats.gather_table_stats(USER, 'T_NOCOMPRESS');
END;
/

-- Agora compare o plano e custo do acesso em cada tabela

-- Sem compressão
EXPLAIN PLAN FOR
SELECT *
  FROM t_nocompress
 WHERE created_date BETWEEN to_date('01/05/2008', 'DD/MM/YYYY')
                        AND to_date('30/05/2008', 'DD/MM/YYYY');
 
 SELECT *
  FROM TABLE(dbms_xplan.display);

-- Com compressão
EXPLAIN PLAN FOR
SELECT *
  FROM test_tab_1
 WHERE created_date BETWEEN to_date('01/05/2008', 'DD/MM/YYYY')
                        AND to_date('30/05/2008', 'DD/MM/YYYY');
 
 SELECT *
  FROM TABLE(dbms_xplan.display);

-- Com compressão e particionamento
EXPLAIN PLAN FOR
SELECT *
  FROM test_tab_2
 WHERE created_date BETWEEN to_date('01/05/2008', 'DD/MM/YYYY')
                        AND to_date('30/05/2008', 'DD/MM/YYYY');
 
 SELECT *
  FROM TABLE(dbms_xplan.display);
