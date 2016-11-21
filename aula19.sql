/* aula19.sql: In-Memory Database Option
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
  O objetivo desta pr�tica � demonstrar a option In-Memory Database.
*/

-- mostra par�metros relacionados
show parameter inmemory;

-- Como n�s j� configuramos o inmemory na pr�tica 07 n�o � necess�rio
-- configurar mais nada aqui

-- Caso quisessemos desativar o inmemory para o banco atual, basta
-- rodar os comandos abaixo

-- N�O EXECUTE - apenas para refer�ncia
ALTER SYSTEM SET inmemory_size=0;
-- N�O EXECUTE - apenas para refer�ncia
ALTER SYSTEM RESET inmemory_size;

-- Para completar a desativa��o ainda seria necess�rio baixar e subir o
-- banco novamente

-- Voc� tamb�m pode controlar a ativa��o do inmemory pelo par�metro
-- INMEMORY_FORCE

-- N�O EXECUTE - desliga o INMEMORY
ALTER SYSTEM SET inmemory_force=OFF;
-- N�O EXECUTE - ativa o INMEMORY
ALTER SYSTEM SET inmemory_force=DEFAULT;

-- Finalmente, tamb�m temos o controle por query. O comando acima efetivamente
-- "desliga" a �rea de inmemory. O par�metro INMEMORY_QUERY apenas avisa para
-- o otimizador utilizar ou n�o a �rea de INMEMORY, se estiver dispon�vel.

-- N�O EXECUTE - desliga o INMEMORY globalmente
ALTER SYSTEM SET inmemory_query=DISABLE;
-- N�O EXECUTE - ativa o INMEMORY globalmente
ALTER SYSTEM SET inmemory_query=ENABLE;

-- E o controle por query pode ser modificado por sess�o, de acordo com a
-- necessidade (testes)
ALTER SESSION SET inmemory_query=DISABLE;
ALTER SESSION SET inmemory_query=ENABLE;

/*
  Algumas views importantes
 */

SELECT * 
  FROM v$im_column_level;;
  
SELECT * 
  FROM v$im_segments;

SELECT * 
  FROM v$im_user_segments;

-- Al�m das views pr�prias, as views normais do dicion�rio cont�m colunas
-- *_INMEMORY ou INMEMORY_* que referenciam propriedades desta option. Ex.:

SELECT table_name, 
       inmemory, 
       inmemory_compression
  FROM user_tables;
  
/*
  Abaixo vamos ver como funciona a cria��o de objetos INMEMORY e os tipos de
  controles que temos sobre eles.
 */
 
-- Para come�ar vamos criar 3 tabelas

-- Especificando INMEMORY j� na cria��o 
CREATE TABLE im_tab (
  ID  NUMBER
) inmemory;

-- Tabela sem INMEMORY (default)
CREATE TABLE noim_tab (
  ID  NUMBER
) NO inmemory;

-- Tabela sem INMEMORY (default)
CREATE TABLE default_tab (
  ID  NUMBER
);

COLUMN table_name format a20

-- A consulta abaixo mostra as novas colunas da USER_TABLES que tratam
-- das propriedades de INMEMORY (v�lido para qualquer view *_TABLES)
SELECT table_name,
       inmemory,
       inmemory_priority,
       inmemory_distribute,
       inmemory_compression,
       inmemory_duplicate  
FROM   user_tables
ORDER BY table_name;

-- Alterando objetos que j� existem com ALTER TABLE
ALTER TABLE im_tab NO inmemory;
ALTER TABLE noim_tab inmemory memcompress FOR capacity low;
ALTER TABLE default_tab inmemory priority HIGH;

SELECT table_name,
       inmemory,
       inmemory_priority,
       inmemory_distribute,
       inmemory_compression,
       inmemory_duplicate  
FROM   user_tables
ORDER BY table_name;

-- Criando uma tabela em que nem todas as colunas s�o inmemory
-- e as que s�o tem tipos de compress�o diferente
CREATE TABLE im_col_tab (
  ID   NUMBER,
  col1 NUMBER,
  col2 NUMBER,
  col3 NUMBER,
  col4 NUMBER
) inmemory
inmemory memcompress FOR QUERY HIGH (col1, col2)
inmemory memcompress FOR capacity HIGH (col3)
NO inmemory (ID, col4);

-- A view v$im_column_level permite ver os detalhes das colunas
SELECT table_name,
       segment_column_id,
       column_name,
       inmemory_compression
FROM   v$im_column_level
WHERE  owner = USER
AND    table_name = 'IM_COL_TAB'
ORDER BY segment_column_id;

-- Tamb�m � poss�vel modificar com ALTER TABLE
ALTER TABLE im_col_tab 
NO inmemory (col1, col2)
inmemory memcompress FOR capacity HIGH (col3)
NO inmemory (ID, col4);

SELECT table_name,
       segment_column_id,
       column_name,
       inmemory_compression
FROM   v$im_column_level
WHERE  owner = USER
AND    table_name = 'IM_COL_TAB';

/*
  Views Materializadas
 */

-- Views materializadas s�o na pr�tica tabelas com algumas condi��es especiais,
-- conforme j� comentamos na teoria.

-- Esta tabela simula uma tabela do nosso sistema
DROP TABLE t10;
CREATE TABLE t10 AS
  SELECT * FROM all_objects;

-- E criamos uma view materializada INMEMORY em cima da tabela T10
CREATE MATERIALIZED VIEW t1_mv inmemory 
  AS SELECT * FROM t1;

SELECT table_name,
       inmemory,
       inmemory_priority,
       inmemory_distribute,
       inmemory_compression,
       inmemory_duplicate  
FROM   user_tables
WHERE  table_name = 'T1_MV';

-- Alterando a propriedade da MV
ALTER MATERIALIZED VIEW t1_mv
  inmemory memcompress FOR capacity HIGH priority HIGH;

SELECT table_name,
       inmemory,
       inmemory_priority,
       inmemory_distribute,
       inmemory_compression,
       inmemory_duplicate  
FROM   user_tables
WHERE  table_name = 'T1_MV';

-- Removendo a propriedade INMEMORY
ALTER MATERIALIZED VIEW t1_mv NO inmemory;

SELECT table_name,
       inmemory,
       inmemory_priority,
       inmemory_distribute,
       inmemory_compression,
       inmemory_duplicate  
FROM   user_tables
WHERE  table_name = 'T1_MV';

/*
  Tablespaces
 */
 
-- Finalmente, assim como outras propriedades de tabelas, n�s conseguimos
-- controlar o uso do INMEMORY por tablespace.
--
-- Lembrando, no entanto, que colocar um tablespace INMEMORY ***N�O*** quer
-- dizer que todos os objetos dele v�o ocupar a IN-MEMORY COLUMN STORE.
--
-- Setar a cl�usula INMEMORY num tablespace apenas quer dizer que aquela
-- cl�usula ser� considerada por PADR�O quando um objeto for criado nele, quando
-- n�o espeficada.

SELECT file#, 
       ts#, 
       NAME 
  FROM v$datafile;
 
-- � por isso que o nome do par�metro � DEFAULT INMEMORY
-- Para lembrarmos que � apenas uma padroniza��o de que os objetos sejam
-- inmemory
CREATE TABLESPACE new_ts
   DATAFILE '/u01/app/oracle/oradata/orcl12c/orcl/new_ts.dbf' SIZE 10M 
   DEFAULT inmemory;

SELECT tablespace_name, 
       def_inmemory,
       def_inmemory_priority,
       def_inmemory_distribute,
       def_inmemory_compression,
       def_inmemory_duplicate
FROM   dba_tablespaces
ORDER BY tablespace_name;

-- Assim como todos os comandos acima, � poss�vel emitir um alter tablespace
-- para modificar o valor de cria��o
ALTER TABLESPACE new_ts
  DEFAULT inmemory memcompress FOR capacity HIGH;

SELECT tablespace_name, 
       def_inmemory,
       def_inmemory_priority,
       def_inmemory_distribute,
       def_inmemory_compression,
       def_inmemory_duplicate
FROM   dba_tablespaces
ORDER BY tablespace_name;

-- Desativando...
ALTER TABLESPACE new_ts
  DEFAULT NO inmemory;

SELECT tablespace_name, 
       def_inmemory,
       def_inmemory_priority,
       def_inmemory_distribute,
       def_inmemory_compression,
       def_inmemory_duplicate
FROM   dba_tablespaces
ORDER BY tablespace_name;

-- Refer�ncia: https://oracle-base.com/articles/12c/in-memory-column-store-12cr1