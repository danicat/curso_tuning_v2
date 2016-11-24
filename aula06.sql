/* aula06.sql: SQL e Otimizador
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
  Nesta pr�tica vamos ver como funciona a execu��o dos comandos SQL, conhecer
  algumas views de estat�sticas do otimizador e entender como funcionam as
  principais m�tricas: seletividade, cardinalidade e custo.
*/

/*
  O primeiro bloco em PL/SQL mostra como executar um SQL passo a passo. Este
  mecanismo n�o � necess�rio no dia-a-dia, exceto para desenvolvedores que
  trabalham com softwares que fazem interfaces diretas na OCI (Oracle Call
  Interface) 
  [http://www.oracle.com/technetwork/database/features/oci/index-090945.html]
  
  A dbms_sql � a package que permite este tipo de execu��o. Ela existe no 
  PL/SQL como um mecanismo legado para executar SQL din�mico. Nas vers�es mais
  recentes do banco o seu uso foi substitu�do pelo comando EXECUTE IMMEDIATE.
  
  Por�m, para fiz de compatibilidade reversa com c�digo legado ela � mantida
  at� hoje, e serve aqui para mostrar cada uma das etapas do processamento SQL.
 */

-- Ativa sa�da de texto
set serveroutput on

-- Execu��o SQL passo a passo
declare
  cur1  number;
  num1  number := 10;
  saida number;
  ret1  number;
begin
  -- Passo 1: Open Cursor (create)
  cur1 := dbms_sql.open_cursor;
  
  -- Passo 2: Parse
  dbms_sql.parse(cur1, 
                 'select rownum n from dual connect by level <= :num', 
                 dbms_sql.native);
  
  -- Passo 4: Define
  dbms_sql.define_column(cur1, 1, saida);

  -- Passo 5: Bind
  dbms_sql.bind_variable(cur1, ':num', num1);
  
  -- Passo 7: Execute
  ret1 := dbms_sql.execute(cur1);
  loop
    -- Passo 8: Fetch
    exit when dbms_sql.fetch_rows(cur1) = 0;
    
    dbms_sql.column_value(cur1, 1, saida);
    
    dbms_output.put_line('saida = ' || saida);
  end loop;
  
  -- Passo 9: Close
  dbms_sql.close_cursor(cur1);
end;
/

/*
  Para a pr�xima etapa, n�s vamos estimar algumas m�tricas do otimizador,
  incluindo cardinalidade, seletividade e custo. Para isso, vamos trabalhar
  em cima de uma das tabelas do esquema HR: a EMPLOYEES.
  
  Para n�o perder o costume, vamos come�ar explorando algumas views.
 */
 
-- A view dba_tables mostra as informa��es b�sicas dos objetos tabela,
-- incluindo algumas estat�sticas e as suas configura��es de armazenamento
select *
  from dba_tables
 where table_name  = 'EMPLOYEES'
   and owner       = 'HR';

-- A view dba_tab_statistics consolida as principais estat�sticas das tabelas
select *
  from dba_tab_statistics
 where table_name = 'EMPLOYEES'
   and owner      = 'HR';

-- Finalmente, a dba_tab_col_statistics cont�m informa��es sobre as colunas
-- da tabela
select *
  from dba_tab_col_statistics
 where table_name  = 'EMPLOYEES'
   and owner       = 'HR'; 
   
-- Caso as consultas acima estejam vazias, execute uma coleta de estat�sticas
-- com o comando abaixo e tente de novo:
exec dbms_stats.gather_table_stats('HR','EMPLOYEES');

-- Uma outra view importante com estat�sticas sobre as tabelas � a 
-- all_tab_modifications. Ela cont�m o hist�rico de modifica��es de cada tabela
-- desde a �ltima coleta de estat�sticas.

-- Mostra todas as modifica��es desde a �ltima coleta de estat�sticas
select * from all_tab_modifications;

-- Mostra as modifica��es para os objetos do usu�rio atual apenas
select * from user_tab_modifications;

-- Vamos fazer um teste com a tabela t4, criada na aula anterior
-- Caso precise recri�-la, segue abaixo o DDL:
drop table t4;
create table t4 (
  id, 
  data, 
  data2,
  constraint pk_t4 primary key(id)
)
pctfree 99
pctused 1
as
 select level id, rpad('*',4000,'*') data, rpad('*',3000,'*') data2
   from dual
connect by level <= 30000;

-- Apenas para relembrar a estrutura
desc t4;

-- For�a uma coleta de estat�sticas nesta tabela
exec dbms_stats.gather_table_stats(user, 'T4');

-- Insere 1000 novas linhas
insert into t4
select rownum + 50000 id, 'X', 'Y'
  from dual connect by level <= 1000;
commit;

-- A consulta abaixo provavelmente vai retornar em branco...
select * from user_tab_modifications;

-- Isto acontece porque o Oracle ainda n�o descarregou as informa��es de
-- monitoramento (ele faz isso em background). Ent�o vamos for�ar um flush
exec dbms_stats.flush_database_monitoring_info;

-- E agora...
select * from user_tab_modifications;

-- Vamos deletar as linhas novas
delete from t4
 where id > 50000;
 
commit;

-- Mais um flush
exec dbms_stats.flush_database_monitoring_info;

-- Estat�sticas atualizadas
select * from user_tab_modifications;

-- � desta forma que o Oracle rastreia quando precisa coletar estat�sticas
-- novamente em um objeto. Veremos mais sobre isto na aula sobre Estat�sticas.

/*
  Voltando a cardinalidade e seletividade.
  
  Vamos estudar a seletividade da coluna job_id.
 */

-- Quantos registros existem para cada job_id
select job_id, count(*)
  from hr.employees
 group by grouping sets((),(job_id));

-- O n�mero de registros de cada job_id � a cardinalidade real ou calculada
select job_id,
       count(*) as cardinalidade_real
  from hr.employees
 group by grouping sets((),(job_id))
 order by 2 desc;

-- O n�mero de registros de cada job_id dividido pelo total de linhas da
-- tabela nos d� a seletividade real ou calculada
select job_id,
       round(count(*) / 
            (select count(*) total_emps
               from hr.employees), 2)    as seletividade_real
  from hr.employees
 group by grouping sets((),(job_id))
 order by 2 desc;

-- Juntando as duas m�tricas na mesma consulta
select job_id,
       round(count(*) / 
            (select count(*) total_emps
               from hr.employees), 2)    as seletividade_real,
       count(*)                          as cardinalidade_real
  from hr.employees
 group by grouping sets((),(job_id))
 order by 3 desc;

/*
  Por�m, normalmente o Oracle n�o tem tempo para fazer os c�lculos exatos
  durante a elabora��o do plano de execu��o. Por isso, muitas vezes ele
  precisa trabalhar com estimativas ao inv�s dos valores reais
 */

-- A seletividade estimada � obtida pelo n�mero de valores da tabela dividido
-- pelo n�mero de valores distintos
select round(1 / count(distinct job_id), 4) as seletividade_estimada
  from hr.employees;

-- Esta seletividade � v�lida para QUALQUER job_id, contando que n�o hajam
-- estimativas melhores (j� veremos isso)
 
-- A cardinalidade estimada � calculada multiplicando a seletividade estimada
-- pelo total de linhas

select count(distinct job_id) from hr.employees;
select round(
         (1 / count(distinct job_id)) * count(*), 
       4)                                           as cardinalidade_estimada
  from hr.employees; 

-- Este � o n�mero de linhas que esperamos que cada JOB_ID represente. 
 
-- Juntando as duas querys
select round(1 / count(distinct job_id), 4)              as seletividade_estimada,
       round((1 / count(distinct job_id)) * count(*), 4) as cardinalidade_estimada
  from hr.employees;

/*
  Para ver isso funcionando, vamos deletar as estat�sticas da tabela.
 */
 
exec dbms_stats.delete_table_stats('HR','EMPLOYEES', no_invalidate => FALSE);

-- Conferindo:
select *
  from dba_tab_statistics
 where table_name = 'EMPLOYEES'
   and owner      = 'HR';

select *
  from dba_tab_col_statistics
 where table_name  = 'EMPLOYEES'
   and owner       = 'HR'; 

explain plan for 
select /*+ FULL(e) DYNAMIC_SAMPLING(0) */ *
  from hr.employees e
 where job_id = 'SA_REP';
 
select *
  from table(dbms_xplan.display());

-- A estimativa do Oracle foi 4 linhas, mas calculamos 6, por que?

/*
  Porque n�s estimamos as m�tricas SABENDO o n�mero de valores distintos.
  Nem isso ele sabe, e o valor padr�o quando ele n�o sabe � 100 valores 
  distintos.
  
  Al�m disso, ele est� estimando que o n�mero de linhas � cerca de 400:
 */

-- sem o filtro 
explain plan for 
select /*+ FULL(e) DYNAMIC_SAMPLING(0) */ *
  from hr.employees e;
 
select *
  from table(dbms_xplan.display());

select 409 / 100 from dual; -- Esta � a cardinalidade do plano

 -- Mas s� temos 19 distinct values... 
 select count(distinct job_id) from hr.employees;
 
 -- Ajusta a estat�stica
 exec dbms_stats.set_column_stats('HR','EMPLOYEES','JOB_ID', distcnt => 19);
 
select *
  from dba_tab_col_statistics
 where table_name  = 'EMPLOYEES'
   and owner       = 'HR'; 

 -- Repare na coluna DENSITY... o valor � familiar?
 -- Pela defini��o do manual, DENSITY � uma estimativa da SELETIVIDADE
 -- Ver: https://asktom.oracle.com/pls/asktom/f?p=100:11:0::::P11_QUESTION_ID:2969235095639
 
 -- Qual o impacto da DENSITY no plano?
 
 explain plan for 
 select /*+ FULL(e) DYNAMIC_SAMPLING(0) */ *
   from hr.employees e
  where job_id = 'SA_REP';
 
 select *
   from table(dbms_xplan.display());

 -- Agora ele estimou como 22 linhas... o que est� faltando?
 -- Ajustar o n�mero de linhas da tabela
 exec dbms_stats.set_table_stats('HR','EMPLOYEES', numrows => 107);

 explain plan for 
 select /*+ FULL(e) DYNAMIC_SAMPLING(0) */ *
   from hr.employees e
  where job_id = 'SA_REP';
 
 select *
   from table(dbms_xplan.display());
   
 -- Finalmente! 6 conforme o calculado
 -- Mas est� errado :)
 
 -- Na verdade s�o 30!
 select count(*) from hr.employees where job_id = 'SA_REP';

 exec dbms_stats.gather_table_stats('HR', 'EMPLOYEES');

 explain plan for 
 select /*+ FULL(e) DYNAMIC_SAMPLING(0) */ *
   from hr.employees e
  where job_id = 'SA_REP';
 
 select *
   from table(dbms_xplan.display());

 -- Agora sim! Por qu�?
 -- A explica��o est� nas estat�sticas de coluna
select column_name, num_distinct, sample_size, num_buckets, histogram
  from dba_tab_col_statistics
 where table_name  = 'EMPLOYEES'
   and owner       = 'HR'
   and column_name = 'JOB_ID'; 

/*
  Quando o otimizador precisa de estimativas melhores de cardinalidade, ou seja,
  quando um valor de seletividade n�o � representativo para todos os dados,
  ele pode recorrer ao uso de histogramas para ter uma id�ia da distribui��o
  dos valores.
 */
 
/*
  Generator
  
  Agora vamos explorar este componente do otimizador. Para isso vamos utilizar
  algumas t�cnicas de trace. N�o se preocupe em entender o trace 100% agora,
  voltaremos neste assunto mais adiante.
 */
 
 alter session set tracefile_identifier = 'aula02';

 -- M�TODO 01: DESTRUTIVO [LIMPA SHARED_SQL_AREA]

 -- N�o fazer isso na vida real: utilizar o m�todo 2
 alter system flush shared_pool;

-- verifica se o plano est� na shared pool
select sql_id, vs.address || ',' || vs.hash_value as name
  from v$sql     vs
 where vs.sql_text like 'select /* hardparse */%';

-- Ativa o TRACE
alter session set events '10053 trace name context forever, level 1';

select /* hardparse */ *
  from hr.employees   emp, 
       hr.departments dept
 where emp.department_id = dept.department_id;

-- Desliga o TRACE
alter session set events '10053 trace name context off';

-- local f�sico do arquivo de trace
select value
  from v$diag_info
 where name = 'Default Trace File';

-- METODO 2: trace por SQL_ID
select sql_id, vs.address || ',' || vs.hash_value as name
  from v$sql     vs
 where vs.sql_text like 'select /* hardparse */%';
  
-- substituir o name pelo resultado acima [elimina o cursor da shared pool]
execute sys.dbms_shared_pool.purge('000000007279E130,1242646934','C',1);

-- substituir o sql_id pela query acima [liga o trace]
alter system set events 'trace[RDBMS.SQL_Optimizer.*][sql:7u6w4aj512kcq]';

select /* hardparse */ *
  from hr.employees   emp, 
       hr.departments dept
 where emp.department_id = dept.department_id;

-- desliga o trace
alter system set events 'trace[RDBMS.SQL_Optimizer.*][sql:7u6w4aj512kcq] off';