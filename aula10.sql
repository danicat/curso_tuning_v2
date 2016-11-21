/* aula10.sql: Estat�sticas I
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
  O objetivo desta pr�tica � mostrar os principais tipos de estat�stica que
  o CBO utiliza para a tomada de decis�o.
*/

-----------
-- VIEWS --
-----------

/*
  Para come�ar, vamos ver as principais views. Lembrando que views all_* e
  dba_* mostram todos os objetos, enquanto as views user_* mostram apenas os
  objetos do usu�rio atual.
 */

-- Estat�sticas de tabelas
SELECT * FROM all_tab_statistics;
SELECT * FROM user_tab_statistics;

-- Estat�sticas de �ndices
SELECT * FROM all_ind_statistics;
SELECT * FROM user_ind_statistics;

-- Estat�sticas de colunas
SELECT * FROM all_tab_col_statistics;
SELECT * FROM user_tab_col_statistics;

-- Algumas consultas para ilustrar:

-- Estat�sticas de uma tabela
SELECT num_rows, avg_row_len, BLOCKS, last_analyzed
FROM   dba_tab_statistics
WHERE  owner='SH'
AND    table_name='CUSTOMERS';

----------------
-- DBMS_STATS --
----------------

-- Coleta de estat�sticas de tabela
BEGIN
  dbms_stats.gather_table_stats('SH','CUSTOMERS');
END;
/

SELECT num_rows, avg_row_len, BLOCKS, last_analyzed
FROM   dba_tab_statistics
WHERE  owner='SH'
AND    table_name='CUSTOMERS';


-- M�tricas de �ndices
SELECT index_name, blevel, leaf_blocks AS "LEAFBLK", distinct_keys AS "DIST_KEY",
       avg_leaf_blocks_per_key AS "LEAFBLK_PER_KEY",
       avg_data_blocks_per_key AS "DATABLK_PER_KEY",
       last_analyzed
FROM   dba_ind_statistics
WHERE  owner = 'SH'
AND    index_name IN ('CUST_LNAME_IX','CUSTOMERS_PK');

-- Coleta de estat�sticas de �ndices
BEGIN
  dbms_stats.gather_index_stats('SH','CUSTOMERS_PK');
END;
/

SELECT index_name, blevel, leaf_blocks AS "LEAFBLK", distinct_keys AS "DIST_KEY",
       avg_leaf_blocks_per_key AS "LEAFBLK_PER_KEY",
       avg_data_blocks_per_key AS "DATABLK_PER_KEY",
       last_analyzed
FROM   dba_ind_statistics
WHERE  owner = 'SH'
AND    index_name IN ('CUST_LNAME_IX','CUSTOMERS_PK');

-- N�s podemos combinar a coleta de estat�sticas de tabelas e indices no mesmo
-- comando atrav�s do par�metro cascade

-- Observe a coluna LAST_ANALYZED
SELECT index_name, last_analyzed
  FROM all_ind_statistics
 WHERE table_name = 'SALES'
   AND owner = 'SH';

-- Mesmo sendo um gather_TABLE_stats, vai coletar tamb�m estat�sticas dos
-- �ndices por causa do cascade = TRUE:
BEGIN
  dbms_stats.gather_table_stats(
    ownname => 'SH',
    tabname => 'SALES',
    CASCADE => TRUE
  );
END;
/

-- Observe a coluna LAST_ANALYZED
SELECT index_name, last_analyzed
  FROM all_ind_statistics
 WHERE table_name = 'SALES'
   AND owner = 'SH';


-- O valor padr�o para CASCADE � DBMS_STATS.AUTO_CASCADE, o que significa
-- que o Oracle decide automaticamente quando coletar estat�sticas dos �ndices
-- quando o m�todo DBMS_STATS.GATHER_TABLE_STATS � chamado.

SELECT dbms_stats.get_prefs('CASCADE') FROM dual;

/*
  Voc� pode modificar esta (ou qualquer outra) prefer�ncia por objeto ou 
  globalmente com os m�todos SET_*_PREFS e SET_GLOBAL_PREFS.
*/

-- Modificando prefer�ncia global
BEGIN
  dbms_stats.set_global_prefs('CASCADE', 'FALSE');
END;
/

SELECT dbms_stats.get_prefs('CASCADE') FROM dual;

-- Modificando prefer�ncia por objeto
BEGIN
  dbms_stats.set_table_prefs('HR', 'EMPLOYEES', 'CASCADE', 'TRUE');
END;
/

-- Comparando as duas lado a lado
SELECT 'GLOBAL' escopo, 
       dbms_stats.get_prefs('CASCADE') 
  FROM dual
 UNION ALL
SELECT 'HR.EMPLOYEES', 
       dbms_stats.get_prefs('CASCADE', 'HR', 'EMPLOYEES') 
  FROM dual;

-- Restaurando o padr�o
BEGIN
  dbms_stats.delete_table_prefs('HR', 'EMPLOYEES', 'CASCADE');
  dbms_stats.reset_global_pref_defaults;
END;
/

-- Comparando as duas lado a lado
SELECT 'GLOBAL' escopo, 
       dbms_stats.get_prefs('CASCADE') 
  FROM dual
 UNION ALL
SELECT 'HR.EMPLOYEES', 
       dbms_stats.get_prefs('CASCADE', 'HR', 'EMPLOYEES') 
  FROM dual;
  
-----------------------
-- CLUSTERING FACTOR --
-----------------------

/*
  Clustering Factor � uma estat�stica de �ndices que mede a proximidade f�sica
  das linhas em rela��o a um valor do �ndice. Um valor baixo de clustering
  factor indica para o otimizador que valores pr�ximos da chave est�o pr�ximos 
  uns aos outros fisicamente, e favorece que o otimizador escolha o acesso por
  �ndice.
  
  Um clustering factor que � pr�ximo do n�mero de *blocos* da tabela indica que
  as linhas est�o fisicamente ordenadas nos blocos da tabela pela chave do 
  �ndice.
  
  Um clustering factor que � pr�ximo do n�mero de "linhas" da tabela indica que
  as linhas est�o espalhadas aleatoriamente nos blocos da tabela, com rela��o
  � chave do �ndice.
  
  O clustering factor � uma propriedade do �ndice e n�o da tabela, pois para
  medir o grau de "ordena��o" precisamos de uma refer�ncia - que � a chave do
  �ndice. Dois indices na mesma tabela podem ter clustering factors 
  completamente diferentes.
  
  Por exemplo: uma tabela de funcion�rio, com colunas nome e sobrenome, e dois
  �ndices, um em cada coluna. Se a tabela f�sica estiver ordenada por nome,
  o �ndice no nome vai ter um baixo clustering factor e o �ndice no sobrenome
  vai ter um alto clustering factor. Se o dado f�sico estiver ordenado por
  sobrenome, a situa��o se inverte.
  
  Logo, na maioria dos casos voc� n�o vai se preocupar em otimizar o clustering
  factor, ele � apenas uma consequencia da estrutura atual e mais uma m�trica
  para o otimizador tomar decis�es.
  
  Abaixo, vamos ver como o clustering factor de um �ndice pode influenciar a
  decis�o do CBO:
 */

-- Para este exemplo vamos utilizar a tabela SH.CUSTOMERS
-- Repare no n�mero de linhas e n�mero de blocos
SELECT table_name, num_rows, BLOCKS
  FROM all_tables
 WHERE table_name='CUSTOMERS'
   AND owner = 'SH';

-- Vamos criar um �ndice na coluna cust_last_name
CREATE INDEX customers_last_name_idx ON sh.customers(cust_last_name);

-- Observe o clustering factor... ele est� mais pr�ximo do n�mero de blocos
-- ou do n�mero de linhas?
SELECT index_name, blevel, leaf_blocks, CLUSTERING_FACTOR
FROM   user_indexes
WHERE  table_name = 'CUSTOMERS'
AND    index_name = 'CUSTOMERS_LAST_NAME_IDX';

-- Embora numericamente ele esteja mais perto do n�mero de blocos do que do
-- n�mero de linhas, ele � aproximadamente 8x maior que o n�mero de blocos
-- sugerindo um grau de desordena��o

-- Vamos criar agora uma tabela com as linhas ordenadas por cust_last_name
DROP TABLE customers3 PURGE;
CREATE TABLE customers3 AS 
 SELECT * 
   FROM sh.customers 
  ORDER BY cust_last_name;

-- Coleta de estat�sticas da tabela
exec dbms_stats.gather_table_stats(USER,'CUSTOMERS3');

-- Conferindo
SELECT table_name, num_rows, BLOCKS
  FROM user_tables
 WHERE table_name='CUSTOMERS3';

-- Mesmo �ndice, na nova tabela
CREATE INDEX customers3_last_name_idx ON customers3(cust_last_name);

-- Repare o clustering_factor... compare com o �ndice na tabela desordenada
SELECT index_name, blevel, leaf_blocks, CLUSTERING_FACTOR
  FROM user_indexes
 WHERE table_name = 'CUSTOMERS3'
   AND index_name = 'CUSTOMERS3_LAST_NAME_IDX';

-- Uma consulta
SELECT cust_first_name, cust_last_name
  FROM sh.customers
 WHERE cust_last_name BETWEEN 'Puleo' AND 'Quinn';

-- Qual � o plano?
SELECT * FROM TABLE(dbms_xplan.display_cursor());

-- Mesma consulta, agora na tabela ordenada
SELECT cust_first_name, cust_last_name
  FROM customers3
 WHERE cust_last_name BETWEEN 'Puleo' AND 'Quinn';

-- Compare os planos... e o custo?
SELECT * FROM TABLE(dbms_xplan.display_cursor());

-- E se n�s for�assemos o acesso por �ndice?
SELECT /*+ index (Customers CUSTOMERS_LAST_NAME_IDX) */ 
       cust_first_name, 
       cust_last_name 
  FROM sh.customers 
 WHERE cust_last_name BETWEEN 'Puleo' AND 'Quinn';

-- Compare o custo
SELECT * FROM TABLE(dbms_xplan.display_cursor());

---------------------
-- Tipos de Coleta --
---------------------

/*
  N�s vimos anteriormente a coleta de estat�sticas de tabelas e �ndices.
  Agora vamos ver alguns tipos adicionais de coleta.
 */

-- Para uma tabela
exec dbms_stats.gather_table_stats('HR','EMPLOYEES');

SELECT index_name
  FROM all_indexes
 WHERE owner = 'HR'
   AND table_name = 'EMPLOYEES';

-- De um �ndice isolado
exec dbms_stats.gather_index_stats('HR','EMP_NAME_IX');

-- GATHER_SCHEMA_STATS: Coleta estat�sticas de todas as tabelas do esquema e,
-- opcionalmente, de todos os �ndices, a depender do par�metro cascade [ou da
-- prefer�ncia cascade]
exec dbms_stats.gather_schema_stats('HR');


-- GATHER_DATABASE_STATS: Coleta estat�sticas de todos os esquemas
-- Aten��o: este comando pode demorar bastante dependendo da sua m�quina,
-- e n�o � necess�rio para a conclus�o desta pr�tica, portanto sua execu��o
-- � opcional.
exec dbms_stats.gather_database_stats;

-- Estat�sticas da tabela agora
SELECT num_rows, empty_blocks, avg_row_len, BLOCKS, last_analyzed
  FROM dba_tab_statistics d
 WHERE owner='HR'
   AND table_name='EMPLOYEES';

-- Estat�sticas de coluna
SELECT column_name, 
       num_distinct,
       low_value,
       high_value,
       density,
       num_nulls,
       num_buckets,
       histogram
  FROM dba_tab_col_statistics d
 WHERE owner='HR'
   AND table_name='EMPLOYEES';

-- Esta fun��o vai nos ajudar a entender as colunas HIGH_VALUE e LOW_VALUE
-- da view acima
CREATE OR REPLACE FUNCTION raw_to_num(i_raw RAW) 
RETURN NUMBER 
AS 
    m_n NUMBER; 
BEGIN
    dbms_stats.convert_raw_value(i_raw,m_n); 
    RETURN m_n; 
END; 
/     

-- A dbms_stats tem uma procedure de convers�o para cada tipo de representa��o
-- interna. Os tipos de dados varchar, number, float e date s�o convertidos com 
-- varia��es da procedure dbms_stats.convert_raw_value [overload]
--
-- Existem duas procedures extras para nvarchar e rowid:
-- dbms_stats.convert_raw_value_nvarchar
-- dbms_stats.convert_raw_value_rowid

SELECT column_name, 
       raw_to_num(low_value)  low_value,
       raw_to_num(high_value) high_value,
       density,
       num_nulls,
       num_distinct,
       num_buckets,
       histogram
  FROM dba_tab_col_statistics d
 WHERE owner='HR'
   AND table_name='EMPLOYEES'
   AND column_name IN ('SALARY','EMPLOYEE_ID','DEPARTMENT_ID');

/*
  Histogramas
 */

-- A cria��o de histogramas n�s comandamos com o par�metro method_opt:
exec dbms_stats.gather_table_stats('HR','EMPLOYEES',method_opt => 'FOR ALL COLUMNS SIZE AUTO');

SELECT column_name, num_distinct, num_buckets, histogram
  FROM dba_tab_col_statistics
 WHERE owner = 'HR'
   AND table_name = 'EMPLOYEES'
   AND histogram != 'NONE';

-- O par�metro size indica o tamanho do bucket
-- e a rela��o entre o tamanho do bucket e o n�mero de distintos � o que
-- determina o tipo de histograma
BEGIN 
  dbms_stats.gather_table_stats(
      'HR',
      'EMPLOYEES',
      method_opt => 'FOR COLUMNS EMPLOYEE_ID SIZE 10');
END;
/

SELECT column_name, num_distinct, num_buckets, histogram
  FROM dba_tab_col_statistics
 WHERE owner = 'HR'
   AND table_name = 'EMPLOYEES'
   AND histogram != 'NONE';

-- O tipo de histograma escolhido depende do perfil do dado. Neste caso, a
-- distribui��o do DEPARTMENT_ID favorece a cria��o do histograma TOP-FREQUENCY
BEGIN
  dbms_stats.gather_table_stats(
      'HR',
      'EMPLOYEES',
      method_opt => 'FOR COLUMNS DEPARTMENT_ID SIZE 5');
END;
/

-- De modo geral n�s n�o precisamos controlar a cria��o de histogramas, o Oracle
-- decide automaticamente de acordo com o perfil dos dados, mas em situa��es
-- espec�ficas podemos for�ar a sua cria��o conforme a estrat�gia mostrada acima

/*
  Estat�sticas estendidas
 */
 
/*
  Grupos de colunas
 */

SET serveroutput ON

-- Cria estat�sticas para um grupo de colunas e retorna o nome do grupo
DECLARE
  l_cg_name VARCHAR2(30);
BEGIN
  l_cg_name := dbms_stats.create_extended_stats(ownname   => 'SCOTT',
                                                tabname   => 'EMP',
                                                extension => '(JOB,DEPTNO)');
  dbms_output.put_line('l_cg_name=' || l_cg_name);
END;
/

-- Outra forma de ver o nome do grupo
SELECT dbms_stats.show_extended_stats_name(ownname   => 'SCOTT',
                                           tabname   => 'EMP',
                                           extension => '(JOB,DEPTNO)') AS cg_name
FROM dual;

-- Para deletar o grupo
BEGIN
  dbms_stats.drop_extended_stats(ownname   => 'SCOTT',
                                 tabname   => 'EMP',
                                 extension => '(JOB,DEPTNO)');
END;
/

-- A coleta com method_opt autom�tico inclui coleta para grupos:
BEGIN
  dbms_stats.gather_table_stats(
    'SCOTT',
    'EMP',
    method_opt => 'for all columns size auto');
END;
/

-- Voc� tamb�m pode especificar um grupo que ainda n�o existe e ele ser�
-- criado automaticamente para voc�
BEGIN
  dbms_stats.gather_table_stats(
    'SCOTT',
    'EMP',
    method_opt => 'for columns (job,mgr)');
END;
/

COLUMN extension format a30

-- Extens�es atuais
SELECT extension_name, extension
FROM   dba_stat_extensions
WHERE  table_name = 'EMP';

-- As estat�sticas estendidas s�o consideradas "colunas" na *_tab_col_statistics
SELECT e.extension col_group,
       t.num_distinct,
       t.histogram
FROM   dba_stat_extensions e,
       dba_tab_col_statistics t 
WHERE  e.extension_name=t.column_name
AND    t.table_name = 'EMP';

/*
  Express�es
 */

DECLARE
  l_cg_name VARCHAR2(30);
BEGIN
  -- Explicitly created.
  l_cg_name := dbms_stats.create_extended_stats(ownname   => 'SCOTT',
                                                tabname   => 'EMP',
                                                extension => '(LOWER(ENAME))');

  -- Implicitly created.
  dbms_stats.gather_table_stats(
    'SCOTT',
    'EMP',
    method_opt => 'for columns (upper(ename))');
END;
/

BEGIN
  dbms_stats.gather_table_stats(
    'SCOTT',
    'EMP',
    method_opt => 'for all columns size auto');
END;
/

SELECT extension_name, extension
FROM   dba_stat_extensions
WHERE  table_name = 'EMP';

COLUMN col_group format a30

SELECT e.extension col_group,
       t.num_distinct,
       t.histogram
FROM   dba_stat_extensions e,
       dba_tab_col_statistics t 
WHERE  e.extension_name=t.column_name
AND    t.table_name = 'EMP';

