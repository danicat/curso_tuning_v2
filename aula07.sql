/* aula07.sql: Planos de Execução
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
  O objetivo desta prática é demonstrar as diferentes formas de obter planos
  de execução.
*/

/*
  Para começar, vamos ver as principais views
 */

-- Cursores atualmente carregados
select * from v$sql;

-- Planos de Execução para cada child_cursor carregado na library cache
select * from v$sql_plan;

-- Exibe estatísticas de monitoramento para cada plano
-- Ex.: linhas realmente lidas, physical reads, etc
select * from v$sql_plan_monitor;

-- Estatísticas de execução
select * from v$sql_plan_statistics;

-- Exibe planos de execução gravados no repositório do AWR (workload repository)
-- CUIDADO!!! Se o seu ambiente não tiver licença para o Diagnostic Pack, 
-- acessar esta view pode causar problemas com LMS.
select * from dba_hist_sql_plan;


-- A plan_table é uma tabela especial onde o ORACLE descarrega o resultado
-- do comando EXPLAIN_PLAN
select * from plan_table;

-- Exemplo
explain plan for select 1 from dual;

select * from plan_table;

-- Você pode criar a sua própria plan_table com o script utlxplan.sql
-- Se não fizer, estará utilizando um sinônimo para uma plan_table global

-- Para especificar qual plan table gravar o plano, você pode usar a sintaxe:
explain plan into plan_table for select 1 from dual;

-- Você também pode dar um nome ao plano
explain plan set statement_id = 'select dual' for select 1 from dual;

select * from plan_table;

-- Esta tabela será usada no exemplo a seguir
drop table t7;
create table t7 as
select rownum id, dbms_random.value * 1000 valor 
  from dual connect by level <= 500;

-- Marque quantos valores
select count(*)
  from t7
 where valor < 500;

-- Grave este valor também
select count(*)
  from t7
 where valor = 1;

-- Você pode gerar o plano para um update
explain plan for
update t7
   set valor = 1
 where valor < 500;

-- Veja o último plano
select * 
  from plan_table;

-- Mas o update não é executado!
select count(*)
  from t7
 where valor < 500;
 
select count(*)
  from t7
 where valor = 1;

-- Você também pode elaborar um plano para um CREATE/ALTER index
explain plan for
create index idx11 on t7(valor);

select * 
  from plan_table;

-- Mas o índice não é criado!
select *
  from user_indexes
 where index_name = 'IDX11';
 
/*
  dbms_xplan
 */
 
/*
  A dbms_xplan fornece algumas facilidades para exibição de planos de execução,
  formatando eles de uma forma mais fácil de ser visualizada, além de dar
  controle sobre quais informações queremos. De modo geral é mais prático usar
  a dbms_xplan do que fazer consultas na plan_table.
 */

 explain plan for
 select * from t7;

 -- Formata o conteúdo da plan table. 
 select * from table(DBMS_XPLAN.DISPLAY);

 select /* meu-tag */ id, trunc(valor) from t7;
 
 -- Exibe o plano do ultimo cursor executado (nem sempre é o que você quer!)
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR);
 
 select sql_id, sql_text from v$sql where sql_text like '%meu-tag%';
 
 -- Colocar entre aspas o sql_id da query acima:
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('a5z12r6j6gs96'));
 
 -- Estatísticas de criação
 select table_name, num_rows, blocks
   from user_tables
  where table_name = 'T7';

 -- Deletando as estatísticas
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
  
 -- Plano REAL, com estatísticas de execução
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('6zwzt83p1gwr1', null, 'ALLSTATS LAST'));
 
 
 /*
   Formatos e Modificadores
  */
 
 -- Usaremos sempre a mesma query para mostrar os diferentes formatos
 select /* tag2 */ id, trunc(valor) valor
   from T7;
 
 -- Busca o sql_id
 select sql_id, sql_text from v$sql where sql_text like 'select /* tag2 %';
 
 -- Id, operação e nome
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
 -- Última execução
 select * from table(DBMS_XPLAN.DISPLAY_CURSOR('1116j7p4ba9wm', null, 'ALLSTATS LAST'));
 -- Todas as execuções
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

-- NOTA: para não executar a mesma query todas as vezes, o comando '/' (barra)
-- repete o último SQL executado
--
-- Você pode modificar o autotrace normalmente e na linha de comando, ao invés
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
-- minúscula, de "list".
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