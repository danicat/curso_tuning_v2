/* aula07.sql: Planos de Execu��o
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
  O objetivo desta pr�tica � demonstrar as diferentes formas de obter planos
  de execu��o.
*/

/*
  Para come�ar, vamos ver as principais views
 */

-- Cursores atualmente carregados
select * from v$sql;

-- Planos de Execu��o para cada child_cursor carregado na library cache
select * from v$sql_plan;

-- Exibe estat�sticas de monitoramento para cada plano
-- Ex.: linhas realmente lidas, physical reads, etc
select * from v$sql_plan_monitor;

-- Estat�sticas de execu��o
select * from v$sql_plan_statistics;

-- Exibe planos de execu��o gravados no reposit�rio do AWR (workload repository)
-- CUIDADO!!! Se o seu ambiente n�o tiver licen�a para o Diagnostic Pack, 
-- acessar esta view pode causar problemas com LMS.
select * from dba_hist_sql_plan;


-- A plan_table � uma tabela especial onde o ORACLE descarrega o resultado
-- do comando EXPLAIN_PLAN
select * from plan_table;

-- Exemplo
explain plan for select 1 from dual;

select * from plan_table;

-- Voc� pode criar a sua pr�pria plan_table com o script utlxplan.sql
-- Se n�o fizer, estar� utilizando um sin�nimo para uma plan_table global

-- Para especificar qual plan table gravar o plano, voc� pode usar a sintaxe:
explain plan into plan_table for select 1 from dual;

-- Voc� tamb�m pode dar um nome ao plano
explain plan set statement_id = 'select dual' for select 1 from dual;

select * from plan_table;

-- Esta tabela ser� usada no exemplo a seguir
drop table t7;
create table t7 as
select rownum id, dbms_random.value * 1000 valor 
  from dual connect by level <= 500;

-- Marque quantos valores
select count(*)
  from t7
 where valor < 500;

-- Grave este valor tamb�m
select count(*)
  from t7
 where valor = 1;

-- Voc� pode gerar o plano para um update
explain plan for
update t7
   set valor = 1
 where valor < 500;

-- Veja o �ltimo plano
select * 
  from plan_table;

-- Mas o update n�o � executado!
select count(*)
  from t7
 where valor < 500;
 
select count(*)
  from t7
 where valor = 1;

-- Voc� tamb�m pode elaborar um plano para um CREATE/ALTER index
explain plan for
create index idx11 on t7(valor);

select * 
  from plan_table;

-- Mas o �ndice n�o � criado!
select *
  from user_indexes
 where index_name = 'IDX11';
 
/*
  dbms_xplan
 */
 
/*
  A dbms_xplan fornece algumas facilidades para exibi��o de planos de execu��o,
  formatando eles de uma forma mais f�cil de ser visualizada, al�m de dar
  controle sobre quais informa��es queremos. De modo geral � mais pr�tico usar
  a dbms_xplan do que fazer consultas na plan_table.
 */

 explain plan for
 select * from t7;

 -- Formata o conte�do da plan table. 
 select * from table(DBMS_XPLAN.DISPLAY);

 select /* meu-tag */ id, trunc(valor) from t7;
 
 -- Exibe o plano do ultimo cursor executado (nem sempre � o que voc� quer!)
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR);
 
 select sql_id, sql_text from v$sql where sql_text like '%meu-tag%';
 
 -- Colocar entre aspas o sql_id da query acima:
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('a5z12r6j6gs96'));
 
 -- Estat�sticas de cria��o
 select table_name, num_rows, blocks
   from user_tables
  where table_name = 'T7';

 -- Deletando as estat�sticas
 exec dbms_stats.delete_table_stats(user, 'T7');
 
 -- Gera um plano
 explain plan for
 select --+ dynamic_sampling(0) gather_plan_statistics
        id, trunc(valor) valor
   from T7;
 
 -- Plano ESTIMADO  
 select * from table(DBMS_XPLAN.DISPLAY);
 
 -- Executa a query
 select --+ dynamic_sampling(0) gather_plan_statistics
        id, trunc(valor) valor
   from T7;
 
 -- Busca o sql_id
 select sql_id, sql_text from v$sql where sql_text like 'select --+ dyn%';
  
 -- Plano REAL, com estat�sticas de execu��o
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('6zwzt83p1gwr1', null, 'ALLSTATS LAST'));
 
 
 /*
   Formatos e Modificadores
  */
 
 -- Usaremos sempre a mesma query para mostrar os diferentes formatos
 select /* tag2 */ id, trunc(valor) valor
   from T7;
 
 -- Busca o sql_id
 select sql_id, sql_text from v$sql where sql_text like 'select /* tag2 %';
 
 -- Id, opera��o e nome
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('4suk9kmn1wjh5', null, 'BASIC'));
 
 -- BASIC + ROWS, BYTES e COST
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('4suk9kmn1wjh5', null, 'TYPICAL'));
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('4suk9kmn1wjh5', null, 'BASIC +ROWS +BYTES +COST'));
 
 -- Igual a BASIC
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('4suk9kmn1wjh5', null, 'SERIAL'));
 
 -- ALL = TYPICAL + PROJECTION + ALIAS + REMOTE
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('4suk9kmn1wjh5', null, 'ALL'));
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('4suk9kmn1wjh5', null, 'TYPICAL +PROJECTION +ALIAS +REMOTE'));
 
 -- ADVANCED = ALL + OUTLINE
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('4suk9kmn1wjh5', null, 'ADVANCED'));
  
 -- Personalizado
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('4suk9kmn1wjh5', null, 'ADVANCED -OUTLINE -NOTE'));
 
 -- Outros
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('4suk9kmn1wjh5', null, 'ALLSTATS LAST'));
 
 -- Usaremos sempre a mesma query para mostrar os diferentes formatos
 select /*+ gather_plan_statistics tag3 */ id, trunc(valor) valor
   from T7;
 
 -- Busca o sql_id
 select sql_id, sql_text from v$sql where sql_text like 'select /*+ gat%';

 -- Execute 3 vezes a query 'tag3' e compare:
 -- �ltima execu��o
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('1116j7p4ba9wm', null, 'ALLSTATS LAST'));
 -- Todas as execu��es
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('1116j7p4ba9wm', null, 'ALLSTATS ALL'));
 
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('1116j7p4ba9wm', null, 'IOSTATS ALL'));
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('1116j7p4ba9wm', null, 'MEMSTATS ALL'));
 
 /*
   Autotrace
  */
  
-------------------------
-- Executar no sqlplus --
-------------------------

show autotrace
set autotrace on

show autotrace

select id, trunc(valor) valor from T7 where rownum < 3;

-- NOTA: para n�o executar a mesma query todas as vezes, o comando '/' (barra)
-- repete o �ltimo SQL executado
--
-- Voc� pode modificar o autotrace normalmente e na linha de comando, ao inv�s
-- de digitar (ou colar) a query novamente, basta digitar / e [enter]
--
-- Exemplo:
--
-- > select 1 from dual;
-- > set autotrace on
-- > /
-- >
--
-- A barra na terceira linha do exemplo executa novamente a query da linha 1
--
-- Para ver qual comando o sqlplus vai executar, use o comando 'l' (letra L
-- min�scula, de "list".
--

set autotrace traceonly
select id, trunc(valor) valor from T7 where rownum < 3;

set autotrace traceonly explain
select id, trunc(valor) valor from T7 where rownum < 3;

set autotrace traceonly statistics
select id, trunc(valor) valor from T7 where rownum < 3;

set autotrace on explain
select id, trunc(valor) valor from T7 where rownum < 3;

set autotrace on statistics
select id, trunc(valor) valor from T7 where rownum < 3;

set autotrace off
select id, trunc(valor) valor from T7 where rownum < 3;