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
  Nesta aula vamos explorar as estatísticas de sessão e o Buffer Cache.
*/


/*
  Primeiro, vamos apresentar as principais views de estatísticas.
  
  A v$mystat é a view que mostra apenas estatísticas do usuário atual.
  
  A v$sesstat mostra estatísticas de todas as sessões (que o usuário estiver
  autorizado a ver).
 */

select *
  from v$mystat;
 
select *
  from v$sesstat;

/*
  Para entender melhor o que cada estatística representa, precisamos ligar
  qualquer uma destas views à view v$statname:
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
  O cache hit ratio é uma métrica importante de performance do banco de dados.
  Os DBAs costumam se esforçar para mantê-la próxima de 1 (100%). Quando maior
  o cache hit, mais dados são acessados diretamente da memóra e menos dados
  precisam ser recuperados do disco. É uma métrica da eficiencia do I/O
  lógico.
 */

-- cache hit ratio
select name, value
  from v$sysstat
 where name in ('db block gets from cache', 
                'consistent gets from cache', 
                'physical reads cache');

/*
  A formula para o cache hit ratio é a seguinte:
  CHR = 1 - (('physical reads cache') / ('consistent gets from cache' + 
                                                    'db block gets from cache'))
 */

-- A query abaixo utiliza uma transposição de colunas para linhas para realizar
-- o cálculo do cache hit ratio
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
 
-- Anote o cache hit ratio antes de prosseguir para a próxima etapa.

/*
  Agora, vamos tentar influenciar a métrica do cache hit ratio com duas
  abordagens:
  
  1. Executando múltiplos full table scan
  2. Executando múltiplos index range scan
 */
 
/*
  Vamos utilizar a tabela t3 da prática anterior como referência. Caso
  precise, abaixo está o script de criação:
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
-- Houve alguma alteração?
-- E se fossem 1 milhão de table scans?

-- Agora vamos criar uma nova tabela para fazer a comparação com o acesso por
-- índices
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

-- Apenas para nos situarmos no modelo, algumas informações:

-- Note que recém criada, a T4 parece dominar todo o cache... por quê?
select name, count(*)
  from v$cache
 where name in ('T3','T4')
 group by name
 order by 1;

-- Não foi a criação da tabela em si... mas a criação do índice!
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

-- Este bloco executa aleatoriamente 100.000 acessos a tabela t4 por índice (pk)
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
  
  Para fazer esta etapa da prática, você terá que acessar como SYS do ORCL.
  
  Assim como existem as views v$, existem as tabelas x$. As views v$ geralmente
  são baseadas no conteúdo das tabelas x$, organizadas de uma forma mais fácil
  de consumir.
  
  Já vimos na aula passada que a v$cache é a view que permite observar quantos
  blocos de cada objeto estão no buffer cache. Para relembrar:
*/

desc v$cache

select *
  from v$cache;
  
/*
  A view v$bh vai um pouco mais além, exibindo mais algumas informações 
  internas do buffer cache. Observe que ela não possui uma coluna com o nome
  do objeto, mas sim a coluna OBJD.
  
  A documentação para todas as colunas desta view segue no link abaixo:
  http://docs.oracle.com/database/121/REFRN/GUID-A8230335-47C4-4707-A866-678DD8D322A8.htm#REFRN30029
 */

desc v$bh
select * from v$bh;

/*
  Para saber quem é quem, vamos precisar ligar com a dba_objects:
  
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
  A vantagem de ter acesso a v$bh é que podemos ver como o buffer está se
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
  A tabela x$bh nos dá acesso a coluna TCH (touch count) que é parte do
  mecanismo de LRU. Quanto mais touches, mais usado é o objeto e menos chance
  ele tem de ser removido do cache.
 */

select do.object_name, bh.tch, bh.*
  from dba_objects do,
       x$bh        bh
 where do.object_id = bh.obj
   and do.owner = 'CURSO'
  order by 1, 2 desc;

-- o código abaixo vai acessar 1000 vezes os mesmos 10 blocos
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