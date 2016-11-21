/* aula05.sql: Padr�es de Codifica��o
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
  Nesta aula vamos explorar o impacto de padr�es de codifica��o no banco de
  dados.
*/

/*
  N�s vamos utilizar as estat�sticas de sess�o para entender o que est�
  acontecendo por debaixo dos panos. Relembrando, a v$mystat � a view que 
  mostra apenas estat�sticas do usu�rio atual.
 */

desc v$mystat;

select *
  from v$mystat;
 
/*
  E a v$statname descreve cada uma das estat�sticas.
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
  Nesta aula, estamos interessados nas estat�sticas de hard parse e total parse.
*/

-- Este comando limpa todos os cursores da shared pool
alter system flush shared_pool;

-- a partir de agora todas as primeiras execu��es de querys s�o hard parse!

-- Este comando vai exibir as estat�sticas atuais de parse
select vs.statistic#, display_name, value
  from v$mystat   vm,
       v$statname vs
 where vm.statistic# = vs.statistic#
   and display_name like 'parse%';
   
-- Anote no n�mero de total parse e hard parse
-- Total parse:
-- Hard parse :
   
-- execute as querys abaixo, por�m entre cada uma delas observe o n�mero
-- de hard parses reexecutando a query acima

select * from dual;
select *  from dual;
select  * from dual;

/*
  Fa�a experimentos com o n�mero de espa�os, capitaliza��o e etc
  voc� ver� que sempre que o cursor gerar um texto novo ele ativa um hard
  parse.
 */
 
-- A consulta abaixo adiciona espa�os ao final da query, gerando 100 querys
-- "diferentes"
begin
  for r0 in (select rpad('select * from dual', 20 + rownum, ' ') query 
               from dual connect by level <= 100)
  loop
    execute immediate r0.query;
  end loop;
end;
/

-- Como o bloco anonimo impactou a estat�stica? Execute a query abaixo e
-- compare com a �ltima contagem de hard parses:
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
   
-- Vamos limpar a shared pool novamente antes do pr�ximo teste
alter system flush shared_pool;

/*
  Blocos PL/SQL tem algumas particularidades:
  
  - Todo SQL puro dentro do PL/SQL � convertido para UPPERCASE
  - O PL/SQL tamb�m remove as sobras de whitespace e coment�rios
  - Finalmente, toda vari�vel � convertida automaticamente em bind variable
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

-- Observe que mesmo os blocos an�nimos acima referenciando querys textualmente
-- diferentes, o PL/SQL teve intelig�ncia para compartilhar os seus cursores.
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

  O par�metro s= seleciona o tipo de estat�sticas que queremos medir, podendo
  assumir os seguintes par�metros:
  
  s = estat�sticas
  l = latches
  t = timing

  Logo, com s=s queremos apenas estat�sticas:
*/

@mystats start s=s

-- Este � o mesmo bloco an�nimo que executou 100 hard parses l� em cima
begin
  for r0 in (select rpad('select * from dual', 20 + rownum, '  ') query 
               from dual connect by level <= 100)
  loop
    execute immediate r0.query;
  end loop;
end;
/
/*
  O comando de parada do mystats tamb�m aceita par�metros:

  t = threshould: � a diferen�a minima entre a estat�stica final e a inicial 
                  que � exibida no relat�rio. Ex.: t=10 quer dizer que no 
                  m�nimo a diferen�a entre a estat�stica final e a inicial tem
                  que ser 10 para ela ser impressa no relat�rio
  l = like      : exibe estat�sticas que tem a palavra chave depois do igual.
                  Ex.: l=parse exibe todas as estat�sticas que tem a palavra
                  'parse'
*/
@mystats stop t=10

/*
  Agora vamos ver um cen�rio um pouco mais realista...
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
 
-- Como corrigir este c�digo?
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

-- Estat�sticas destes cursores 
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