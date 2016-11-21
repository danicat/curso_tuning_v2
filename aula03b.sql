/* aula03b.sql: Estruturas de Disco
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
  O objetivo desta pr�tica � mostrar as principais views de storage e algumas
  consultas importantes.
*/

 /*
   A v$tablespace exp�e o nome dos tablespaces e o seu identificador (TS#)
  */
 desc v$tablespace;
 
 select *
   from v$tablespace;

/*
  A v$datafile mostra onde est�o os arquivos f�sicos no disco ou storage. �
  poss�vel ligar esta view com a v$tablespace pelo campo TS#.
 */
desc v$datafile

 select *
   from v$datafile;
   
/*
  A dba_segments (ou all_segments, ou user_segments) mostra os dados sobre
  armazenamento f�sico para cada objeto da base (ou do usu�rio)
 */
 
 select *
   from dba_segments;

/*
  Abaixo, algumas consultas que exploram estes relacionamentos.
 */

 -- Espa�o alocado por tablespace
 select vt.name tablespace,
        vd.name filename,
        round(vd.bytes / 1048576, 2) mbytes,
        round(sum(bytes) over (partition by vt.name) / 1048576, 2) total_tbs
   from v$tablespace vt,
        v$datafile   vd
  where vt.ts# = vd.ts#;

-- Espa�o usado em cada tablespace
 select tablespace_name, round(sum(bytes) / 1048576, 2) used_mbytes
   from dba_segments
  group by tablespace_name;

-- Usado x Alocado
 with ds as (
 select tablespace_name, round(sum(bytes) / 1048576, 2) used_mbytes
   from dba_segments
  group by tablespace_name
 )
 select distinct
        vt.name tablespace,
        used_mbytes,
        round(sum(bytes) over (partition by vt.name) / 1048576, 2) total_tbs
   from v$tablespace vt,
        v$datafile   vd,
        ds
  where vt.ts#  = vd.ts#
    and vt.name = ds.tablespace_name;

/*
  Conforme mostrado na aula te�rica, existe ainda o conceito de extents como
  uma unidade menor do segmento. Hoje � raro precisarmos investigar extents,
  mesmo porque o padr�o � que o Oracle gerencie isto manualmente, mas para
  manter o material completo, n�o poder�amos deixar de citar a view dba_extents:
 */

desc dba_extents 

select * from dba_extents;

/*
  Nesta pr�xima etapa vamos criar alguns objetos para ver como afetam as views
  de storage.
 */

/*
  Abaixo vamos criar 3 tabelas: t1, t2 e t3.
  
  Observe a sintaxe de gera��o das tabelas. Esta � uma t�cnica de gera��o de
  linhas muito �til para testes de performance.
  
  Detalhe para a forma como o modelo foi constru�do com os par�metros de
  storage:
  - pctfree: � uma clausula de storage que diz que o bloco deve ser considerado
             como candidato para inser��o de novas linhas se tiver espa�o livre
             acima deste valor (percentual)
  - pctused: � uma clausula de storage que diz que o bloco deve ser considerado
             utilizado (n�o pode receber mais linhas) se tiver percentual de
             uso acima deste valor
             
  Na pr�tica, dizendo pctfree 99 e pctused 1, estamos instruindo o Oracle a
  colocar apenas uma linha por bloco.
  
  Adicionalmente, na forma��o da linha, as colunas data e data2 ocupam 7000
  bytes, ent�o estamos garantindo que s� exista uma linha por bloco, lembrando
  que cada bloco est� configurado para conter 8192 bytes (menos o header).
 */

drop table t1;
create table t1
pctfree 99
pctused 1
as
 select level id, rpad('*',4000,'*') data, rpad('*',3000,'*') data2
   from dual
connect by level <= 500;

drop table t2;
create table t2 
pctfree 99
pctused 1
as
 select level id, rpad('*',4000,'*') data, rpad('*',3000,'*') data2
   from dual
connect by level <= 1000;

drop table t3;
create table t3 
pctfree 99
pctused 1
as
 select level id, rpad('*',4000,'*') data, rpad('*',3000,'*') data2
   from dual
connect by level <= 2000;

-- VSIZE � uma fun��o interna para determinar o tamanho ocupado no disco
-- por uma coluna
select id, 
       vsize(id), 
       vsize(data), 
       vsize(data2) 
  from t1
 order by 2 desc;

-- Validando o objeto em dba_segments
desc dba_segments

select segment_name, 
       bytes / 1048576 mbytes
  from dba_segments
 where segment_name in ('T1','T2','T3')
   and owner = user;

-- E em dba_extents
select *
  from dba_extents
 where segment_name in ('T1','T2','T3')
   and owner = user;

-- Observe o n�mero de blocos por extent
select segment_name,
       count(*)     num_extents,
       sum(blocks)  total_blocos
  from dba_extents
 where segment_name in ('T1','T2','T3')
   and owner = user
 group by segment_name
 order by 1;

-- Consegue explicar estes n�meros?

/*
  Finalmente, vamos observar o efeito do tamanho destes objetos no buffer
  cache.
 */

-- Este � o tamanho atual do buffer cache
select current_size / 1048576 mbytes
  from v$sga_dynamic_components
 where component = 'DEFAULT buffer cache';

-- Limpa o buffer cache
alter system flush buffer_cache;

-- Verifica quantos blocos existem no buffer cache de cada objeto
select name, count(*)
  from v$cache
 where name in ('T1','T2','T3')
 group by name
 order by 1;

-- Execute uma vez para cada e repita a consulta acima
select count(*) from t1;
select count(*) from t2;
select count(*) from t3;

/* Na pr�xima aula vamos explorar um pouco mais o buffer cache! */

/* 
  Vamos aproveitar a fun��o VSIZE e estudar o armazenamento de n�meros no 
  Oracle atrav�s de um fen�meno interessante:
 */

drop table t4; 
create table t4 ( x number, y number );
 
insert into t4 ( x )
select to_number(rpad('9',rownum*2,'9'))
  from all_objects
 where rownum <= 19;
 
update t4 set y = x+1;

select x, y, vsize(x), vsize(y)
  from t4 order by x;

/*
  Observe que para representar x � preciso de mais bytes do que y
  Isso porque x tem mais digitos significativos do y e o Oracle precisa
  armazenar todos eles. O armazenamento de n�meros em Oracle ocupa espa�o 
  vari�vel, assim como o VARCHAR.

  Refer�ncia para este test case e mais informa��es:
  https://asktom.oracle.com/pls/asktom/f?p=100:11:0::::P11_QUESTION_ID:1856720300346322149
*/

---------------------
-- HIGH WATER MARK --
---------------------

/*
  O pr�ximo cen�rio vai demonstrar o funcionamento da High Water Mark em
  conjunto com um direct-path insert.
 */

-- Para esta demonstra��o vamos reutilizar a tabela T3 criada acima
DESC T3

-- Vamos coletar estat�sticas desta tabela para termos os valores exatos
-- de blocos ocupados e quantidade de linhas da tabela
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'T3', ESTIMATE_PERCENT => 100);
END;
/

-- Anote o n�mero de blocos: 
SELECT NUM_ROWS, BLOCKS
  FROM DBA_TABLES D
 WHERE D.TABLE_NAME = 'T3'
   AND D.OWNER = USER;

-- Confira os valores m�ximos e m�nimos
SELECT MIN(ID), MAX(ID) FROM T3;

-- Vamos excluir todos os valores abaixo de 1000 para liberar 1000 blocos
-- relembrando que criamos esta tabela para ocupar 1 bloco por linha
DELETE FROM T3 WHERE ID <= 1000;
COMMIT;

-- Nova coleta de estat�stica para refletir as altera��es
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'T3', ESTIMATE_PERCENT => 100);
END;
/

SELECT NUM_ROWS, BLOCKS
  FROM DBA_TABLES D
 WHERE D.TABLE_NAME = 'T3'
   AND D.OWNER = USER;

-- Insert normal: deve reutilizar o espa�o em branco aberto pelo DELETE acima
INSERT INTO T3
SELECT ROWNUM AS ID, RPAD('*',4000,'*') DATA, RPAD('*',3000,'*') DATA2
  FROM DUAL CONNECT BY LEVEL <= 500;
COMMIT;

SELECT MIN(ID), MAX(ID) FROM T3;

-- Atualizando estat�sticas
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'T3', ESTIMATE_PERCENT => 100);
END;
/

-- Alguma mudan�a no n�mero de blocos alocados?
SELECT NUM_ROWS, BLOCKS
  FROM DBA_TABLES D
 WHERE D.TABLE_NAME = 'T3'
   AND D.OWNER = USER;

-- Vamos limpar as linhas inseridas mais uma vez
DELETE FROM T3 WHERE ID <= 1000;
COMMIT;

SELECT MIN(ID), MAX(ID) FROM T3;

-- Direct-path insert: sempre acima da HWM
INSERT /*+ APPEND */ INTO T3
SELECT ROWNUM AS ID, RPAD('*',4000,'*') DATA, RPAD('*',3000,'*') DATA2
  FROM DUAL CONNECT BY LEVEL <= 500;
COMMIT;

-- Atualizando estat�sticas
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'T3', ESTIMATE_PERCENT => 100);
END;
/

-- O que aconteceu com o n�mero de blocos? Compare com o valor inicial
SELECT NUM_ROWS, BLOCKS
  FROM DBA_TABLES D
 WHERE D.TABLE_NAME = 'T3'
   AND D.OWNER = USER;

-- Quer recuperar o espa�o em branco?
-- Este � um dos usos para a reorganiza��o de tabelas:
ALTER TABLE T3 MOVE;

-- ALTER TABLE MOVE sem par�metros mant�m todas as configura��es atuais de
-- storage, por�m reorganiza a tabela fazendo uma c�pia para outra �rea
-- no mesmo tablespace.

-- Atualizando estat�sticas
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'T3', ESTIMATE_PERCENT => 100);
END;
/

SELECT NUM_ROWS, BLOCKS
  FROM DBA_TABLES D
 WHERE D.TABLE_NAME = 'T3'
   AND D.OWNER = USER;
   
---------------------
-- SCN e FLASHBACK --
---------------------

/*
  Nesta �ltima sess�o vamos demonstrar a rela��o entre uma transa��o e o
  n�mero de System Change Number (SCN).
 */

-- Como fizemos um ALTER TABLE MOVE na sess�o anterior, todas as linhas
-- devem da tabela t3 estar no mesmo SCN
SELECT ORA_ROWSCN, ID
  FROM T3
 WHERE ID BETWEEN 1001 AND 1003;

-- Vamos executar algumas transa��es para ver o impacto na tabela

-- Atualiza��o de uma linha 
UPDATE T3
   SET DATA = 'XXX'
 WHERE ID = 1001;
COMMIT;

-- Remo��o de outra linha
DELETE FROM T3
 WHERE ID = 1002;
COMMIT;

-- Re-inserindo o ID 1002
INSERT INTO T3
SELECT 1002, 'ABCD', 'EFGH' FROM DUAL;
COMMIT;

-- Observe o SCN de cada ID
SELECT ORA_ROWSCN, ID
  FROM T3
 WHERE ID BETWEEN 1001 AND 1003
 ORDER BY 1;

-- A consulta abaixo vai utilizar o recurso de FLASHBACK para nos mostrar
-- lado a lado o valor atual da linha comparado com o valor anterior (5 minutos
-- atr�s)

-- Ajuste o valor que subtrai de sysdate para determinar quanto tempo atr�s
-- estamos buscando.
SELECT 'ATUAL' FLAG, ORA_ROWSCN, SYS.SCN_TO_TIMESTAMP(ORA_ROWSCN) TS, T3.ID, T3.DATA 
  FROM T3 
 WHERE ID BETWEEN 1001 AND 1003
 UNION ALL
SELECT '5 MIN ATR�S', ORA_ROWSCN, SYS.SCN_TO_TIMESTAMP(ORA_ROWSCN) TS, T3.ID, T3.DATA
  FROM T3 AS OF TIMESTAMP(SYSDATE - 5/(24*60)) -- 24 horas * 60 minutos � o n�mero de minutos em um dia
 WHERE ID BETWEEN 1001 AND 1003;