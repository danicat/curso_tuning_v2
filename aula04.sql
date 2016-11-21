/* aula04.sql: Buffer Cache
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
  Nesta aula vamos explorar as estat�sticas de sess�o e o Buffer Cache.
*/


/*
  Primeiro, vamos apresentar as principais views de estat�sticas.
  
  A v$mystat � a view que mostra apenas estat�sticas do usu�rio atual.
  
  A v$sesstat mostra estat�sticas de todas as sess�es (que o usu�rio estiver
  autorizado a ver).
 */

select *
  from v$mystat;
 
select *
  from v$sesstat;

/*
  Para entender melhor o que cada estat�stica representa, precisamos ligar
  qualquer uma destas views � view v$statname:
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
  O cache hit ratio � uma m�trica importante de performance do banco de dados.
  Os DBAs costumam se esfor�ar para mant�-la pr�xima de 1 (100%). Quando maior
  o cache hit, mais dados s�o acessados diretamente da mem�ra e menos dados
  precisam ser recuperados do disco. � uma m�trica da eficiencia do I/O
  l�gico.
 */

-- cache hit ratio
select name, value
  from v$sysstat
 where name in ('db block gets from cache', 
                'consistent gets from cache', 
                'physical reads cache');

/*
  A formula para o cache hit ratio � a seguinte:
  CHR = 1 - (('physical reads cache') / ('consistent gets from cache' + 
                                                    'db block gets from cache'))
 */

-- A query abaixo utiliza uma transposi��o de colunas para linhas para realizar
-- o c�lculo do cache hit ratio
with stats as (
select name, value
  from v$sysstat
 where name IN ('db block gets from cache', 
                'consistent gets from cache', 
                'physical reads cache')
)
select round(1 - (physical_reads / 
                 (consistent_gets + block_gets)),4) as "Cache Hit Ratio"
  from stats
 pivot
 (
  sum(value) 
  for name in ('db block gets from cache'    AS block_gets, 
                'consistent gets from cache' AS consistent_gets, 
                'physical reads cache'       AS physical_reads)
 );
 
-- Anote o cache hit ratio antes de prosseguir para a pr�xima etapa.

/*
  Agora, vamos tentar influenciar a m�trica do cache hit ratio com duas
  abordagens:
  
  1. Executando m�ltiplos full table scan
  2. Executando m�ltiplos index range scan
 */
 
/*
  Vamos utilizar a tabela t3 da pr�tica anterior como refer�ncia. Caso
  precise, abaixo est� o script de cria��o:
 */
 
drop table t3;
create table t3 
pctfree 99
pctused 1
as
 select level id, rpad('*',4000,'*') data, rpad('*',3000,'*') data2
   from dual
connect by level <= 2000;
 
-- Este bloco executa 100.000 full table scans na tabela t3
declare
 a number := 0;
begin
  for r0 in (select rownum from dual connect by level <= 100000)
  loop
    execute immediate 'select count(*) from t3';
  end loop;
end;
/

-- Execute novamente a query do cache hit ratio e compare...
-- Houve alguma altera��o?
-- E se fossem 1 milh�o de table scans?

-- Agora vamos criar uma nova tabela para fazer a compara��o com o acesso por
-- �ndices
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

-- Apenas para nos situarmos no modelo, algumas informa��es:

-- Note que rec�m criada, a T4 parece dominar todo o cache... por qu�?
select name, count(*)
  from v$cache
 where name in ('T3','T4')
 group by name
 order by 1;

-- N�o foi a cria��o da tabela em si... mas a cria��o do �ndice!
select *
  from user_indexes;

select segment_name, 
       bytes / 1048576 mbytes
  from dba_segments
 where segment_name in ('T3', 'T4')
   and owner = user
 order by 1;

-- Vamos executar novamente a query do CHR:
with stats as (
select name, value
  from v$sysstat
 where name IN ('db block gets from cache', 
                'consistent gets from cache', 
                'physical reads cache')
)
select round(1 - (physical_reads / 
                 (consistent_gets + block_gets)),4) as "Cache Hit Ratio"
  from stats
 pivot
 (
  sum(value) 
  for name in ('db block gets from cache'    AS block_gets, 
                'consistent gets from cache' AS consistent_gets, 
                'physical reads cache'       AS physical_reads)
 );

-- Anote o valor!

-- Este bloco executa aleatoriamente 100.000 acessos a tabela t4 por �ndice (pk)
declare
 a number := 0;
begin
  for r0 in (select dbms_random.value * 30000 + 1 id 
               from dual connect by level <= 100000)
  loop
    for r1 in (select id, data, data2 from curso.t4 where id = r0.id)
    loop
      a := a + r1.id;
    end loop;
  end loop;
end;
/

-- Qual foi o impacto na CHR?

/* 
  Touch count
  
  Para fazer esta etapa da pr�tica, voc� ter� que acessar como SYS do ORCL.
  
  Assim como existem as views v$, existem as tabelas x$. As views v$ geralmente
  s�o baseadas no conte�do das tabelas x$, organizadas de uma forma mais f�cil
  de consumir.
  
  J� vimos na aula passada que a v$cache � a view que permite observar quantos
  blocos de cada objeto est�o no buffer cache. Para relembrar:
*/

desc v$cache

select *
  from v$cache;
  
/*
  A view v$bh vai um pouco mais al�m, exibindo mais algumas informa��es 
  internas do buffer cache. Observe que ela n�o possui uma coluna com o nome
  do objeto, mas sim a coluna OBJD.
  
  A documenta��o para todas as colunas desta view segue no link abaixo:
  http://docs.oracle.com/database/121/REFRN/GUID-A8230335-47C4-4707-A866-678DD8D322A8.htm#REFRN30029
 */

desc v$bh
select * from v$bh;

/*
  Para saber quem � quem, vamos precisar ligar com a dba_objects:
  
  http://docs.oracle.com/database/121/REFRN/GUID-AA6DEF8B-F04F-482A-8440-DBCB18F6C976.htm#REFRN20146
 */
desc dba_objects
select * from dba_objects;

-- Unindo as duas:
select do.object_name, count(*)
  from dba_objects do,
       v$bh        bh
 where do.object_id = bh.objd
   and do.owner = 'CURSO'
 group by do.object_name
 order by 1;

-- Compare com a seguinte query:
select vc.name, count(*)
  from v$cache   vc,
       dba_users du
 where vc.owner# = du.user_id
   and du.username = 'CURSO'
 group by vc.name
 order by 1;
  
/*
  A vantagem de ter acesso a v$bh � que podemos ver como o buffer est� se
  comportando internamente. Por exemplo, a coluna 'status' mostra o tipo
  de bloco:
  
  free: livre
  xcur: exclusive (current)
  scur: shared current
  cr  : consistent read
  read: sendo lido do disco
  mrec: media recovery
  irec: instance recovery
 */

select do.object_name, bh.status, count(*)
  from dba_objects do,
       v$bh        bh
 where do.object_id = bh.objd
   and do.owner = 'CURSO'
 group by do.object_name, bh.status
 order by 1;
 
select * from curso.t4 for update;

update curso.t4
   set data = NULL
 where mod(id, 100) = 1;

rollback;

/*
  A tabela x$bh nos d� acesso a coluna TCH (touch count) que � parte do
  mecanismo de LRU. Quanto mais touches, mais usado � o objeto e menos chance
  ele tem de ser removido do cache.
 */

select do.object_name, bh.tch, bh.*
  from dba_objects do,
       x$bh        bh
 where do.object_id = bh.obj
   and do.owner = 'CURSO'
  order by 1, 2 desc;

-- o c�digo abaixo vai acessar 1000 vezes os mesmos 10 blocos
declare
 a number := 0;
begin
  for r0 in (select mod(rownum,10) id from dual connect by level <= 1000)
  loop
    for r1 in (select id, data, data2 from curso.t4 where id = r0.id)
    loop
      a := a + r1.id;
    end loop;
  end loop;
end;
/

-- Note que o touch count incrementa por processo, tanto no indice como na
-- tabela.