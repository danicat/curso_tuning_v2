/* aula05.sql: Padrões de Codificação
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
  Nesta aula vamos explorar o impacto de padrões de codificação no banco de
  dados.
*/

/*
  Nós vamos utilizar as estatísticas de sessão para entender o que está
  acontecendo por debaixo dos panos. Relembrando, a v$mystat é a view que 
  mostra apenas estatísticas do usuário atual.
 */

desc v$mystat;

select *
  from v$mystat;
 
/*
  E a v$statname descreve cada uma das estatísticas.
 */

desc v$statname
  
select *
  from v$statname;

select vs.statistic#, display_name, value
  from v$mystat   vm,
       v$statname vs
 where vm.statistic# = vs.statistic#
   and vm.value != 0;

/*
  Nesta aula, estamos interessados nas estatísticas de hard parse e total parse.
*/

-- Este comando limpa todos os cursores da shared pool
alter system flush shared_pool;

-- a partir de agora todas as primeiras execuções de querys são hard parse!

-- Este comando vai exibir as estatísticas atuais de parse
select vs.statistic#, display_name, value
  from v$mystat   vm,
       v$statname vs
 where vm.statistic# = vs.statistic#
   and display_name like 'parse%';
   
-- Anote no número de total parse e hard parse
-- Total parse:
-- Hard parse :
   
-- execute as querys abaixo, porém entre cada uma delas observe o número
-- de hard parses reexecutando a query acima

select * from dual;
select *  from dual;
select  * from dual;

/*
  Faça experimentos com o número de espaços, capitalização e etc
  você verá que sempre que o cursor gerar um texto novo ele ativa um hard
  parse.
 */
 
-- A consulta abaixo adiciona espaços ao final da query, gerando 100 querys
-- "diferentes"
begin
  for r0 in (select rpad('select * from dual', 20 + rownum, ' ') query 
               from dual connect by level <= 100)
  loop
    execute immediate r0.query;
  end loop;
end;
/

-- Como o bloco anonimo impactou a estatística? Execute a query abaixo e
-- compare com a última contagem de hard parses:
select vs.statistic#, display_name, value
  from v$mystat   vm,
       v$statname vs
 where vm.statistic# = vs.statistic#
   and display_name like 'parse%';

-- Quantas querys que fazem select * from dual temos agora na shared pool?

select count(*)
  from v$sql
 where lower(sql_text) like '%dual%';
 
select *
  from v$sql
 where lower(sql_text) like '%dual%';
   
-- Vamos limpar a shared pool novamente antes do próximo teste
alter system flush shared_pool;

/*
  Blocos PL/SQL tem algumas particularidades:
  
  - Todo SQL puro dentro do PL/SQL é convertido para UPPERCASE
  - O PL/SQL também remove as sobras de whitespace e comentários
  - Finalmente, toda variável é convertida automaticamente em bind variable
*/
declare
  cursor cDual is
  select * from dual;

  vchar varchar2(1);
begin
  open  cDual;
  fetch cDual into vchar;
  close cDual;
end;
/

declare
  cursor cDual is
  select /* teste_plsql */ * from dual;

  vchar varchar2(1);
begin
  open  cDual;
  fetch cDual into vchar;
  close cDual;
end;
/

-- Observe que mesmo os blocos anônimos acima referenciando querys textualmente
-- diferentes, o PL/SQL teve inteligência para compartilhar os seus cursores.
-- Isso porque ele reescreveu a query do cursor como uma query recursiva.
select sql_text,
       sql_id,
       LOADS, 
       PARSE_CALLS, 
       FETCHES, 
       EXECUTIONS
  from v$sql
 where sql_text = 'SELECT * FROM DUAL';

select sql_text,
       sql_id,
       LOADS, 
       PARSE_CALLS, 
       FETCHES, 
       EXECUTIONS
  from v$sql
 where sql_text like '%teste_plsql%';


/*
  Aprendendo a usar o mystats.sql

  O parâmetro s= seleciona o tipo de estatísticas que queremos medir, podendo
  assumir os seguintes parâmetros:
  
  s = estatísticas
  l = latches
  t = timing

  Logo, com s=s queremos apenas estatísticas:
*/

@mystats start s=s

-- Este é o mesmo bloco anônimo que executou 100 hard parses lá em cima
begin
  for r0 in (select rpad('select * from dual', 20 + rownum, '  ') query 
               from dual connect by level <= 100)
  loop
    execute immediate r0.query;
  end loop;
end;
/
/*
  O comando de parada do mystats também aceita parâmetros:

  t = threshould: é a diferença minima entre a estatística final e a inicial 
                  que é exibida no relatório. Ex.: t=10 quer dizer que no 
                  mínimo a diferença entre a estatística final e a inicial tem
                  que ser 10 para ela ser impressa no relatório
  l = like      : exibe estatísticas que tem a palavra chave depois do igual.
                  Ex.: l=parse exibe todas as estatísticas que tem a palavra
                  'parse'
*/
@mystats stop t=10

/*
  Agora vamos ver um cenário um pouco mais realista...
 */
 
-- Relembrando a tabela t4
desc t4

-- Primeiras 5 linhas
select *
  from t4
fetch first 5 rows only;

select count(*) from t4;

-- Este bloco executa 100 lookups na tabela t4 com 100 valores diferentes.
-- Destaque para o execute immediate concatenando o valor do id.
@mystats start s=s
declare
  vdata varchar2(32000);
begin
  for r0 in (select rownum meu_id 
               from dual connect by level <= 100)
  loop
    execute immediate 'select data from t4 where id = ' || r0.meu_id into vdata;
  end loop;
end;
/
@mystats stop l=parse

-- Quantos cursores diferentes temos na SGA?
select count(*)
  from v$sql
 where sql_text like 'select data from t4 where id = %';
 
-- Como corrigir este código?
alter system flush shared_pool;

@mystats start s=s
declare
  vdata varchar2(32000);
begin
  for r0 in (select rownum meu_id 
               from dual connect by level <= 100)
  loop
    execute immediate 'select data from t4 where id = :meu_id' 
                into vdata using r0.meu_id;
  end loop;
end;
/
@mystats stop l=parse

-- Quantos cursores diferentes temos na SGA?
select count(*)
  from v$sql
 where sql_text like 'select data from t4 where id = %';

-- Estatísticas destes cursores 
select sql_text,
       sql_id,
       LOADS, 
       PARSE_CALLS, 
       FETCHES, 
       EXECUTIONS
  from v$sql
 where sql_text like 'select data from t4 where id = %'
 order by executions desc;

-- Extra: GLOBAL TEMPORARY TABLE --
truncate table gtt;
drop table gtt purge;
create global temporary table gtt
as
select rownum id, rpad('*',1000,'*') dados 
  from dual connect by level <= 100000;

insert into gtt
select rownum id, rpad('*',1000,'*') dados 
  from dual connect by level <= 100000;

select count(*) from gtt;

@mystats start s=s
declare
  val pls_integer;
begin
  for r in (select rownum from dual connect by level <= 100)
  loop
    execute immediate 'select count(*) from gtt' into val;
  end loop;
end;
/
@mystats stop t=100

-- https://asktom.oracle.com/pls/asktom/f?p=100:11:0::::p11_question_id:15826034070548
-- http://betteratoracle.com/posts/27-temporary-tables

select *
  from v$bh
 where objd in (
select object_id
  from dba_objects
 where object_name = 'GTT');