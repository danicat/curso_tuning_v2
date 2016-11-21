/* aula02.sql: Estruturas de Mem�ria
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
  O objetivo desta pr�tica � demonstrar como as estruturas de mem�ria 
  apresentadas na aula est�o configuradas no banco atrav�s da investiga��o
  de par�metros e views de performance.
*/
 
/*
  O comando 'show parameter' � uma das formas mais pr�ticas de visualizar
  os par�metros. Ele � um comando SQL*Plus, por�m algumas outras ferramentas
  tamb�m suportam ele, como por exemplo o SQL Developer.
  
  Veja abaixo o exemplo:
*/

show parameter memory;
show parameter sga;

/*
  Note que n�o � preciso passar o nome completo do par�metro, apenas uma
  palavra que faz parte do nome � suficiente.
*/

/*
  O comando show parameter � equivalente a executar uma consulta na view
  v$parameter filtrando pela coluna name.
 */
 
-- Comparar com a sa�da do show parameter memory
select name, 
       decode(type, 1, 'Boolean',
                    2, 'String',
                    3, 'Integer',
                    4, 'Parameter File',
                    5, 'Reserved',
                    6, 'Big Integer') type,
       display_value value
  from v$parameter
 where name like '%memory%'
 order by name;
 
-- Comparar com a sa�da do show parameter sga
select name, 
       decode(type, 1, 'Boolean',
                    2, 'String',
                    3, 'Integer',
                    4, 'Parameter File',
                    5, 'Reserved',
                    6, 'Big Integer') type,
       display_value value
  from v$parameter
 where name like '%sga%'
 order by 1;
 
/*
  A view v$parameter tamb�m possui outras informa��es que podem
  ser �teis e n�o est�o dispon�veis atrav�s do comando show parameter:
 */

describe v$parameter

/*
  Algumas das colunas mais importantes s�o:
  
  ISDEFAULT       : indica se o par�metro est� com o valor padr�o de instala��o
  ISSES_MODIFIABLE: indica se o par�metro pode ser modificado por sess�o
  ISDEPRECATED    : indica se o par�metro � obsoleto
  
  A descri��o completa da view pode ser encontrada no link abaixo:
  http://docs.oracle.com/database/121/REFRN/GUID-C86F3AB0-1191-447F-8EDF-4727D8693754.htm#REFRN30176
 */
 
/*
  Nota: a v$parameter apresenta os par�metros atualmente v�lidos para a sess�o.
  Caso voc� deseje ver os par�metros v�lidos para a inst�ncia, pode consultar
  a view v$system_parameter. 
  
  Nota 2: como esta � uma inst�ncia CDB e estamos conectados num PDB (orcl),
  a v$parameter ir� mostrar todos os par�metros referentes ao PDB ativo. Por
  outro lado, a v$system_parameter cont�m os par�metros separados por CON_ID.
  
  A query abaixo mostra uma forma de explorar estas diferen�as:
 */
 
 -- Mostra o ID do PDB atual
 show con_id
 
 -- Mostra os par�metros da sess�o atual que s�o diferentes da inst�ncia
 select name, 
        type, 
        value 
   from v$parameter 
  where con_id = 3 -- colocar o con_id acima
 minus 
 (
   select name, 
          type, 
          value 
     from v$system_parameter 
    where con_id = 0 -- 0 = CDB
   union all
   select name, 
          type, 
          value 
     from v$system_parameter 
    where con_id = 3 -- colocar o con_id acima
 )
 order by 1,2,3;
 
/*
  A query acima foi exposta apenas a t�tulo de informa��o. Para o restante 
  deste curso usaremos a v$parameter diretamente.
  
  Voltando aos par�metros, voc� deve ter reparado que os par�metros 
  memory_target e memory_max_target est�o diferentes de zero, logo esta
  inst�ncia est� utilizando o AMM, gerenciamento autom�tico de mem�ria.
 */

-- Relembrando
show parameter memory_max_target
show parameter memory_target

/*
  Isso quer dizer que todos os componentes de mem�ria est�o sendo 
  automaticamente dimensionados pelo banco de acordo com a demanda, dentro do
  limite estabelecido por estes par�metros.
  
  Por este motivo, os demais componentes de mem�ria n�o precisam ser 
  configurados pelos demais par�metros. Por�m, se voc� modificar algum par�metro
  individualmente, por exemplo, o shared_pool_size, o valor que voc� informar
  ser� respeitado como *m�nimo* para aquela estrutura.
 */

show parameter shared_pool;

-- Se voc� quisesse setar como m�nimo de 100M para a shared_pool, poderia
-- executar o comando abaixo:
alter system set shared_pool_size = 100M;

-- Por�m este comando *n�o* vai funcionar porque n�o estamos conectados no root!

/*
  Logo, sabemos que os par�metros de mem�ria que estiverem configurados na
  v$parameter s�o os seus valores m�nimos, mas como saber os seus valores
  atuais? Para isto existem outras views como veremos abaixo.
 */

/*
  A view v$sga mostra informa��es b�sicas sobre o tamanho dos componentes
  da SGA. A query abaixo utiliza o recurso de grouping sets para mostrar
  uma linha de total com a soma de todos os componentes.
 */

-- http://docs.oracle.com/database/121/REFRN/GUID-4E216A4C-5C7E-43F6-8E2C-CDE442A1CEEC.htm#REFRN30233
desc v$sga
 
-- SGA na inst�ncia ativa
select nvl(name, 'TOTAL:') name, 
       sum(round(value / 1048576, 2)) mbytes
  from v$sga
 group by grouping sets((),(name, value));

/*
  A view v$sgainfo apresenta o mesmo tipo de informa��o que a v$sga, por�m
  com mais detalhes de cada componente.
 */
 
-- http://docs.oracle.com/database/121/REFRN/GUID-27672126-D7BF-46DB-9A27-0AD2AA94F2AE.htm#REFRN30314
desc v$sgainfo

-- Mais detalhes
select name, round(bytes / 1048576, 2) mbytes, resizeable
  from v$sgainfo
 order by name, mbytes desc;

/*
  Finalmente, a v$sgastat tr�s informa��es detalhadas da SGA por pool
  de mem�ria.
 */

-- http://docs.oracle.com/database/121/REFRN/GUID-60D2578E-2293-45F5-91C1-35FDF047E520.htm#REFRN30238
desc v$sgastat

select *
  from v$sgastat
 order by pool, bytes desc;

-- Agrupado por pool  
select pool, round(sum(bytes)/1048576, 2) mbytes
  from v$sgastat
 group by pool;

/*
  Como o par�metro memory_target est� configurado, o Oracle est� utilizando 
  o gerenciamento autom�tico de mem�ria. As views abaixo nos ajudam a visualizar
  as opera��es de redimensionamento que ocorrem automaticamente.
 */

-- http://docs.oracle.com/database/121/REFRN/GUID-FA6BA5FD-78BB-4371-9F98-4D1197CDCE4C.htm#REFRN30235
desc v$sga_dynamic_components

-- Componentes din�micos da SGA
select * 
  from v$sga_dynamic_components;

-- Mem�ria livre para ser distribu�da
select *
  from v$sga_dynamic_free_memory;

-- Sum�rio das �ltimas 100 opera��es de rebalanceamento
select *
  from v$sga_resize_ops;

-- Opera��es ocorrendo agora
select *
  from v$sga_current_resize_ops;

/*
  Assim como para a SGA, n�s temos v�rias views de performance que nos
  auxiliam a entender e diagnosticar a PGA. Apenas para relembrar, a PGA
  cont�m a �rea privada de mem�ria dos processos, e � importante para
  a execu��o dos seguintes tipos de opera��es:
  
  - Subprogramas PL/SQL
  - Subprogramas Java
  - Opera��es de ordena��o (ORDER BY, GROUP BY, ROLLUP)
  - Opera��es anal�ticas (janelas)
  - Hash-join
  - Bitmap merge
  - Cria��o de bitmap
  - Buffer de grava��o para carga em massa
  
  S�o estruturas de mem�ria importantes:
  - sort_work_area
  - hash_work_area
 
  O sizing global da PGA � controlado pelo par�metro PGA_AGGREGATE_TARGET. O
  gerenciamento autom�tico da PGA pode ser desabilitado configurando este
  par�metro para zero.
  
  No entanto, como estamos falando de uma inst�ncia com gerenciamento autom�tico
  de mem�ria (AMM), este par�metro est� zerado porque o sistema est� fazendo
  gerenciamento da PGA e SGA atrav�s do par�metro memory_target.
  
  Neste cen�rio (memory_target <> 0), os par�metros pga_aggregate_target e
  sga_target s�o respeitados como m�nimos, caso estejam configurados.
  
  Para fins deste curso n�s n�o vamos nos preocupar com o gerenciamento de 
  mem�ria, mas este conhecimento pode ser �til em inst�ncias da vida real.
  
  Apenas por refer�ncia, em sistemas OLTP � comum alocar 20% da mem�ria 
  dispon�vel para o banco para a PGA. Em sistemas DSS, alocamos 50% da mem�ria
  dispon�vel. Isto se deve ao fato que sistemas DSS realizam muito mais querys
  anal�ticas e, portanto, precisam de sort e hash areas maiores.
  
 */
 
 show parameter pga_aggregate_target
 show parameter sga_target
 show parameter memory_target

/*
  Para visualizar estat�sticas de uso da PGA, n�s podemos consultar a view
  v$pgastat.
 */

desc v$pgastat 

select name, 
       case when unit = 'bytes' 
            then round(value / 1048576, 2)
            else value
       end value,
       decode(unit, 'bytes', 'mbytes', unit) unit
  from v$pgastat
 order by unit, value desc;
 
/*
  Algumas estat�sticas relevantes:
  
  total PGA allocated      : quantidade total de mem�ria alocada para a PGA 
                             atualmente por toda a inst�ncia
  aggregate PGA auto target: quantidade de mem�ria utilizada para work areas
                             em modo autom�tico
  global memory bound      : o maior tamanho poss�vel para uma work area em
                             modo autom�tico. N�o deve ficar abaixo de 1 MB
  
  total PGA used for auto workareas: indica quanto est� sendo ocupado de
                             mem�ria para auto workareas. Desta m�trica e
                             da m�trica 'total PGA allocated' podemos derivar
                             quanta mem�ria est� sendo destinada para outros
                             processos (ex.: java e PL/SQL):
                             
    PGA other = total PGA allocated - total PGA used for auto workareas
  
    
  Para ver o significado das demais estat�sticas:
  http://docs.oracle.com/database/121/TGDBA/tune_pga.htm#TGDBA472                           
 */

-- Abaixo vamos fazer a conta de quanto 'PGA other' est� sendo alocado para
-- o sistema. Repare no uso da cl�usula PIVOT para transpor linhas e colunas.

with pgastats as (
select name, value
  from v$pgastat
 where name IN ('total PGA allocated', 
                'total PGA used for auto workareas')
)
select round((total_pga - total_workarea) / 1048576,4) "PGA other"
  from pgastats
 pivot
 (
  sum(value) 
  for name in ('total PGA allocated'               as total_pga, 
               'total PGA used for auto workareas' as total_workarea)
 );


/*
  A PGA � alocada por processo. A v$process pode nos ajudar a ter
  uma id�ia do consumo individual.
*/

-- http://docs.oracle.com/database/121/REFRN/GUID-BBE32620-1043-4345-9448-51DB21547FEB.htm#REFRN30186
desc v$process

select addr, 
       pid, 
       spid, 
       pname, 
       username, 
       pga_used_mem,
       pga_alloc_mem,
       pga_freeable_mem,
       pga_max_mem
  from v$process;
  
-- Top 10 processos que consomem mais mem�ria
-- Nota: observar a nova sintaxe do 12c para consultas Top-N
select addr, 
       pid, 
       spid, 
       pname, 
       username, 
       pga_used_mem,
       pga_alloc_mem,
       pga_freeable_mem,
       pga_max_mem
  from v$process
 order by pga_used_mem
 fetch first 10 rows only;

-- Total de pga em uso por processos:  
select round(sum(pga_used_mem) / 1048576, 2) mbytes 
  from v$process;

/*
  Para ver no detalhe como est� sendo utilizada a mem�ria por cada processo
  n�s dispomos da view v$process_memory.
  
  Ela pode conter at� 6 linhas para processo, uma para cada tipo de uso de
  mem�ria:
    
    - Java
    - PL/SQL
    - OLAP
    - SQL
    - Freeable
    - Other
 */

desc v$process_memory 

select *
  from v$process_memory;
  
-- Como exerc�cio, voc� pode unir a v$process com a v$process_memory para
-- descobrir o nome de cada processo



/*
  Com rela��o �s estruturas de mem�ria e o tamanho dos processos, elas podem
  ser classificadas como:
  - Optimal   : Tamanho ideal para executar o processo. Geralmente este tamanho
                � um pouco maior que o volume de dados a ser processado. Por
                exemplo, para ordenar 1 GB de dados o tamanho �timo � pouco
                maior que 1 GB.
  - One-pass  : Tamanho suficiente para executar o processo com uma passada 
                extra [duas no total]. Este tipo de execu��o normalmente n�o
                exige muita mem�ria. Para ordenar 1 GB de dados desta forma �
                necess�rio 22 MB de mem�ria.
  - Multi-pass: v�rias passagens pelos dados s�o necess�rias para concluir a 
                opera��o. Execu��es multi-pass podem degradar a performance de 
                maneira acentuada.

  O sizing ideal das work areas permite que 90 a 100% das opera��es sejam
  realizadas como Optimal e 0 a 10% como one-pass.

  A view v$sql_workarea_histogram nos mostra o n�mero de workareas executadas 
  com as classifica��es optimal, one-pass e multi-pass.
 */
 
desc v$sql_workarea_histogram

select low_optimal_size/1024 low_kb,
       (high_optimal_size+1)/1024 high_kb,
       optimal_executions, onepass_executions, multipasses_executions
  from v$sql_workarea_histogram
 where total_executions != 0;

select optimal_count,   round(optimal_count*100/total, 2)   optimal_perc, 
       onepass_count,   round(onepass_count*100/total, 2)   onepass_perc,
       multipass_count, round(multipass_count*100/total, 2) multipass_perc
from
 (select decode(sum(total_executions), 0, 1, sum(total_executions)) total,
         sum(optimal_executions)     optimal_count,
         sum(onepass_executions)     onepass_count,
         sum(multipasses_executions) multipass_count
    from v$sql_workarea_histogram
   where low_optimal_size >= 64*1024);

/*
  Al�m da v$sql_workarea_histogram, tamb�m temos a v$sql_workarea_active que
  mostra workareas em uso atualmente.
 */

-- Guarde esta query para a pr�xima vez que fizer um order by ou group by :)
select to_number(decode(sid, 65535, null, sid)) sid,
       operation_type operation,
       trunc(expected_size/1024) esize,
       trunc(actual_mem_used/1024) mem,
       trunc(max_mem_used/1024) "max mem",
       number_passes pass,
       trunc(tempseg_size/1024) tsize
  from v$sql_workarea_active
 order by 1,2;
 
/*
  Para mais detalhes sobre as work areas e consultas interessantes sobre
  ela podem ser encontradas na seguinte p�gina do manual de tuning:
  http://docs.oracle.com/database/121/TGDBA/tune_pga.htm#TGDBA487

  Como o gerenciamento autom�tico de mem�ria (AMM) se encarrega de configurar
  a SGA e a PGA ao mesmo tempo, n�s dispomos de uma view que exibe todas as
  opera��es de rebalanceamento de mem�ria, assim como a view
  v$sga_dynamic_components faz com a SGA apenas, mas mostrando opera��es que
  englobam a SGA e a PGA. Trata-se da v$memory_dynamic_components:
  
 */
desc v$memory_dynamic_components

select *
  from v$memory_dynamic_components;
 
/*
  Finalmente, algumas querys para mostrar a configura��o dos shared servers
  e dos buffers adicionais, KEEP e RECYCLE:
 */

-- N�mero *m�nimo* de shared servers (m�ximo � autom�tico)
-- Tipicamente a propor��o � 1 shared server para cada 10 usu�rios
select *
  from v$parameter
 where name like '%shared_server%';

-- Buffer cache, KEEP e RECYCLE
select *
  from v$parameter
 where name in ('db_cache_size',
                'db_keep_cache_size', 
                'db_recycle_cache_size');

-- Outra forma de ver os par�metros
show parameter cache_size

/*
  Os buffers KEEP e RECYCLE n�o est�o sendo utilizados por esta inst�ncia
  atualmente. N�s vamos explorar um pouco mais estes buffers na aula
  sobre Cache Hit Ratio.
  
  Vale lembrar que o db_cache_size tamb�m est� zerado, mas ele definitivamente
  est� sendo usado. Isto porque, mais uma vez, o Oracle est� gerenciando
  automaticamente a mem�ria.
 */

-- Quantos objetos est�o configurados na buffer pool
select buffer_pool, count(*)
  from dba_segments d
 group by buffer_pool;

-- Algumas informa��es sobre a buffer pool 
select *
  from v$buffer_pool;

-- E estat�sticas 
select *
  from v$buffer_pool_statistics;

-- v$cache � a vis�o de todos os objetos que est�o em cache atualmente  
select *
  from v$cache;

-- v$bh � um pouco menos user-friendly do que a v$cache, mas tr�s muito 
-- mais informa��es
select *
  from v$bh;
  
-- E finalmente, x$bh, � a view de mais baixo n�vel. Voc� s� conseguir�
-- consult�-la como SYS em fun��o das permiss�es
select *
  from x$bh;
  
/*
  Por enquanto n�o entraremos nos detalhes destas views do buffer cache,
  mas j� � importante irmos nos acostumando com elas. Voltaremos a falar
  delas no futuro.
 */