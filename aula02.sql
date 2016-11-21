/* aula02.sql: Estruturas de Memória
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
  O objetivo desta prática é demonstrar como as estruturas de memória 
  apresentadas na aula estão configuradas no banco através da investigação
  de parâmetros e views de performance.
*/
 
/*
  O comando 'show parameter' é uma das formas mais práticas de visualizar
  os parâmetros. Ele é um comando SQL*Plus, porém algumas outras ferramentas
  também suportam ele, como por exemplo o SQL Developer.
  
  Veja abaixo o exemplo:
*/

show parameter memory;
show parameter sga;

/*
  Note que não é preciso passar o nome completo do parâmetro, apenas uma
  palavra que faz parte do nome é suficiente.
*/

/*
  O comando show parameter é equivalente a executar uma consulta na view
  v$parameter filtrando pela coluna name.
 */
 
-- Comparar com a saída do show parameter memory
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
 
-- Comparar com a saída do show parameter sga
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
  A view v$parameter também possui outras informações que podem
  ser úteis e não estão disponíveis através do comando show parameter:
 */

describe v$parameter

/*
  Algumas das colunas mais importantes são:
  
  ISDEFAULT       : indica se o parâmetro está com o valor padrão de instalação
  ISSES_MODIFIABLE: indica se o parâmetro pode ser modificado por sessão
  ISDEPRECATED    : indica se o parâmetro é obsoleto
  
  A descrição completa da view pode ser encontrada no link abaixo:
  http://docs.oracle.com/database/121/REFRN/GUID-C86F3AB0-1191-447F-8EDF-4727D8693754.htm#REFRN30176
 */
 
/*
  Nota: a v$parameter apresenta os parâmetros atualmente válidos para a sessão.
  Caso você deseje ver os parâmetros válidos para a instância, pode consultar
  a view v$system_parameter. 
  
  Nota 2: como esta é uma instância CDB e estamos conectados num PDB (orcl),
  a v$parameter irá mostrar todos os parâmetros referentes ao PDB ativo. Por
  outro lado, a v$system_parameter contém os parâmetros separados por CON_ID.
  
  A query abaixo mostra uma forma de explorar estas diferenças:
 */
 
 -- Mostra o ID do PDB atual
 show con_id
 
 -- Mostra os parâmetros da sessão atual que são diferentes da instância
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
  A query acima foi exposta apenas a título de informação. Para o restante 
  deste curso usaremos a v$parameter diretamente.
  
  Voltando aos parâmetros, você deve ter reparado que os parâmetros 
  memory_target e memory_max_target estão diferentes de zero, logo esta
  instância está utilizando o AMM, gerenciamento automático de memória.
 */

-- Relembrando
show parameter memory_max_target
show parameter memory_target

/*
  Isso quer dizer que todos os componentes de memória estão sendo 
  automaticamente dimensionados pelo banco de acordo com a demanda, dentro do
  limite estabelecido por estes parâmetros.
  
  Por este motivo, os demais componentes de memória não precisam ser 
  configurados pelos demais parâmetros. Porém, se você modificar algum parâmetro
  individualmente, por exemplo, o shared_pool_size, o valor que você informar
  será respeitado como *mínimo* para aquela estrutura.
 */

show parameter shared_pool;

-- Se você quisesse setar como mínimo de 100M para a shared_pool, poderia
-- executar o comando abaixo:
alter system set shared_pool_size = 100M;

-- Porém este comando *não* vai funcionar porque não estamos conectados no root!

/*
  Logo, sabemos que os parâmetros de memória que estiverem configurados na
  v$parameter são os seus valores mínimos, mas como saber os seus valores
  atuais? Para isto existem outras views como veremos abaixo.
 */

/*
  A view v$sga mostra informações básicas sobre o tamanho dos componentes
  da SGA. A query abaixo utiliza o recurso de grouping sets para mostrar
  uma linha de total com a soma de todos os componentes.
 */

-- http://docs.oracle.com/database/121/REFRN/GUID-4E216A4C-5C7E-43F6-8E2C-CDE442A1CEEC.htm#REFRN30233
desc v$sga
 
-- SGA na instância ativa
select nvl(name, 'TOTAL:') name, 
       sum(round(value / 1048576, 2)) mbytes
  from v$sga
 group by grouping sets((),(name, value));

/*
  A view v$sgainfo apresenta o mesmo tipo de informação que a v$sga, porém
  com mais detalhes de cada componente.
 */
 
-- http://docs.oracle.com/database/121/REFRN/GUID-27672126-D7BF-46DB-9A27-0AD2AA94F2AE.htm#REFRN30314
desc v$sgainfo

-- Mais detalhes
select name, round(bytes / 1048576, 2) mbytes, resizeable
  from v$sgainfo
 order by name, mbytes desc;

/*
  Finalmente, a v$sgastat trás informações detalhadas da SGA por pool
  de memória.
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
  Como o parâmetro memory_target está configurado, o Oracle está utilizando 
  o gerenciamento automático de memória. As views abaixo nos ajudam a visualizar
  as operações de redimensionamento que ocorrem automaticamente.
 */

-- http://docs.oracle.com/database/121/REFRN/GUID-FA6BA5FD-78BB-4371-9F98-4D1197CDCE4C.htm#REFRN30235
desc v$sga_dynamic_components

-- Componentes dinâmicos da SGA
select * 
  from v$sga_dynamic_components;

-- Memória livre para ser distribuída
select *
  from v$sga_dynamic_free_memory;

-- Sumário das últimas 100 operações de rebalanceamento
select *
  from v$sga_resize_ops;

-- Operações ocorrendo agora
select *
  from v$sga_current_resize_ops;

/*
  Assim como para a SGA, nós temos várias views de performance que nos
  auxiliam a entender e diagnosticar a PGA. Apenas para relembrar, a PGA
  contém a área privada de memória dos processos, e é importante para
  a execução dos seguintes tipos de operações:
  
  - Subprogramas PL/SQL
  - Subprogramas Java
  - Operações de ordenação (ORDER BY, GROUP BY, ROLLUP)
  - Operações analíticas (janelas)
  - Hash-join
  - Bitmap merge
  - Criação de bitmap
  - Buffer de gravação para carga em massa
  
  São estruturas de memória importantes:
  - sort_work_area
  - hash_work_area
 
  O sizing global da PGA é controlado pelo parâmetro PGA_AGGREGATE_TARGET. O
  gerenciamento automático da PGA pode ser desabilitado configurando este
  parâmetro para zero.
  
  No entanto, como estamos falando de uma instância com gerenciamento automático
  de memória (AMM), este parâmetro está zerado porque o sistema está fazendo
  gerenciamento da PGA e SGA através do parâmetro memory_target.
  
  Neste cenário (memory_target <> 0), os parâmetros pga_aggregate_target e
  sga_target são respeitados como mínimos, caso estejam configurados.
  
  Para fins deste curso nós não vamos nos preocupar com o gerenciamento de 
  memória, mas este conhecimento pode ser útil em instâncias da vida real.
  
  Apenas por referência, em sistemas OLTP é comum alocar 20% da memória 
  disponível para o banco para a PGA. Em sistemas DSS, alocamos 50% da memória
  disponível. Isto se deve ao fato que sistemas DSS realizam muito mais querys
  analíticas e, portanto, precisam de sort e hash areas maiores.
  
 */
 
 show parameter pga_aggregate_target
 show parameter sga_target
 show parameter memory_target

/*
  Para visualizar estatísticas de uso da PGA, nós podemos consultar a view
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
  Algumas estatísticas relevantes:
  
  total PGA allocated      : quantidade total de memória alocada para a PGA 
                             atualmente por toda a instância
  aggregate PGA auto target: quantidade de memória utilizada para work areas
                             em modo automático
  global memory bound      : o maior tamanho possível para uma work area em
                             modo automático. Não deve ficar abaixo de 1 MB
  
  total PGA used for auto workareas: indica quanto está sendo ocupado de
                             memória para auto workareas. Desta métrica e
                             da métrica 'total PGA allocated' podemos derivar
                             quanta memória está sendo destinada para outros
                             processos (ex.: java e PL/SQL):
                             
    PGA other = total PGA allocated - total PGA used for auto workareas
  
    
  Para ver o significado das demais estatísticas:
  http://docs.oracle.com/database/121/TGDBA/tune_pga.htm#TGDBA472                           
 */

-- Abaixo vamos fazer a conta de quanto 'PGA other' está sendo alocado para
-- o sistema. Repare no uso da cláusula PIVOT para transpor linhas e colunas.

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
  A PGA é alocada por processo. A v$process pode nos ajudar a ter
  uma idéia do consumo individual.
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
  
-- Top 10 processos que consomem mais memória
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
  Para ver no detalhe como está sendo utilizada a memória por cada processo
  nós dispomos da view v$process_memory.
  
  Ela pode conter até 6 linhas para processo, uma para cada tipo de uso de
  memória:
    
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
  
-- Como exercício, você pode unir a v$process com a v$process_memory para
-- descobrir o nome de cada processo



/*
  Com relação às estruturas de memória e o tamanho dos processos, elas podem
  ser classificadas como:
  - Optimal   : Tamanho ideal para executar o processo. Geralmente este tamanho
                é um pouco maior que o volume de dados a ser processado. Por
                exemplo, para ordenar 1 GB de dados o tamanho ótimo é pouco
                maior que 1 GB.
  - One-pass  : Tamanho suficiente para executar o processo com uma passada 
                extra [duas no total]. Este tipo de execução normalmente não
                exige muita memória. Para ordenar 1 GB de dados desta forma é
                necessário 22 MB de memória.
  - Multi-pass: várias passagens pelos dados são necessárias para concluir a 
                operação. Execuções multi-pass podem degradar a performance de 
                maneira acentuada.

  O sizing ideal das work areas permite que 90 a 100% das operações sejam
  realizadas como Optimal e 0 a 10% como one-pass.

  A view v$sql_workarea_histogram nos mostra o número de workareas executadas 
  com as classificações optimal, one-pass e multi-pass.
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
  Além da v$sql_workarea_histogram, também temos a v$sql_workarea_active que
  mostra workareas em uso atualmente.
 */

-- Guarde esta query para a próxima vez que fizer um order by ou group by :)
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
  ela podem ser encontradas na seguinte página do manual de tuning:
  http://docs.oracle.com/database/121/TGDBA/tune_pga.htm#TGDBA487

  Como o gerenciamento automático de memória (AMM) se encarrega de configurar
  a SGA e a PGA ao mesmo tempo, nós dispomos de uma view que exibe todas as
  operações de rebalanceamento de memória, assim como a view
  v$sga_dynamic_components faz com a SGA apenas, mas mostrando operações que
  englobam a SGA e a PGA. Trata-se da v$memory_dynamic_components:
  
 */
desc v$memory_dynamic_components

select *
  from v$memory_dynamic_components;
 
/*
  Finalmente, algumas querys para mostrar a configuração dos shared servers
  e dos buffers adicionais, KEEP e RECYCLE:
 */

-- Número *mínimo* de shared servers (máximo é automático)
-- Tipicamente a proporção é 1 shared server para cada 10 usuários
select *
  from v$parameter
 where name like '%shared_server%';

-- Buffer cache, KEEP e RECYCLE
select *
  from v$parameter
 where name in ('db_cache_size',
                'db_keep_cache_size', 
                'db_recycle_cache_size');

-- Outra forma de ver os parâmetros
show parameter cache_size

/*
  Os buffers KEEP e RECYCLE não estão sendo utilizados por esta instância
  atualmente. Nós vamos explorar um pouco mais estes buffers na aula
  sobre Cache Hit Ratio.
  
  Vale lembrar que o db_cache_size também está zerado, mas ele definitivamente
  está sendo usado. Isto porque, mais uma vez, o Oracle está gerenciando
  automaticamente a memória.
 */

-- Quantos objetos estão configurados na buffer pool
select buffer_pool, count(*)
  from dba_segments d
 group by buffer_pool;

-- Algumas informações sobre a buffer pool 
select *
  from v$buffer_pool;

-- E estatísticas 
select *
  from v$buffer_pool_statistics;

-- v$cache é a visão de todos os objetos que estão em cache atualmente  
select *
  from v$cache;

-- v$bh é um pouco menos user-friendly do que a v$cache, mas trás muito 
-- mais informações
select *
  from v$bh;
  
-- E finalmente, x$bh, é a view de mais baixo nível. Você só conseguirá
-- consultá-la como SYS em função das permissões
select *
  from x$bh;
  
/*
  Por enquanto não entraremos nos detalhes destas views do buffer cache,
  mas já é importante irmos nos acostumando com elas. Voltaremos a falar
  delas no futuro.
 */