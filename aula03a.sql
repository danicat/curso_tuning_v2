/* aula03a.sql: Processos
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
  O objetivo desta prática é fixar os conceitos de arquitetura de processos
  apresentados na aula teórica. Assim como na prática anterior vamos passar
  por algumas views importantes, porém desta vez também vamos utilizar a
  linha de comando do sistema operacional (SO).
  
  Quando necessário executar uma linha no SO, será devidamente indicado no
  texto.
*/

/*
  Antes de começar a prática sobre processos precisamos verificar se o Oracle
  está utilizando o modelo de arquitetura multi-processo ou multi-thread. O
  parâmetro threaded_execution mostra justamente isso.
  
  O modelo de arquitetura multi-thread é um conceito novo do Oracle 12c. Neste
  modelo, ao invés de abrir um processo de SO para cada processo do servidor, o
  Oracle pode optar por criar threads em um processo comum. 
  
  Tecnicamente threads são mais leves em termos de processamento do que
  processos, podendo resultar em um ganho de performance. Por outro lado, ao 
  matar um processo "mãe" de várias threads, todas as threads filhas serão 
  terminadas também. Por este motivo, alguns processos mais importantes
  continuam como processos mesmo no modelo multi-thread.
  
  Trabalhar com o modelo multi-threaded exige mais cuidado pelos DBAs, porque
  estes podem estar acostumados a matar processos no SO e, neste caso, um erro
  pode derrubar centenas de usuários.
  
  Nesta aula vamos considerar a arquitetura clássica multi-processo para não
  nos preocuparmos com as complexidades do gerenciamento multi-threaded. Porém,
  caso tenha interesse em se aprofundar sobre o assunto, a referência abaixo é
  um bom ponto de partida:
  
  https://oracle-base.com/articles/12c/multithreaded-model-using-threaded_execution12cr1
 */
show parameter threaded_execution

-- False! Estamos prontos para continuar

/*
  A view mais importante para a arquitetura de processos é a v$process, a qual
  já tivemos contato quando exploramos a PGA.
 */

-- Apenas para relembrar...
desc v$process

col spid format a8
col stid format a8
select spid,   -- Identificador de processo do sistema operacional (PID)
       stid,   -- Identificador de thread do sistema operacional
       sosid,  -- Identificador único do sistema operacional (pode ser thread
               -- processo, dependendo do modelo
       program,
       execution_type
  from v$process 
 order by spid;

-- Trocar para usuário SYS do CDB
select count(*) from v$process;

-- Executar no SO da VM e comparar o resultado... pode variar +/- 2 processos 
-- porque alguns processos são criados e encerrados muito rapidamente.
> ps -ef | grep -e orcl12c | grep -v grep | wc -l

-- Para ver todos os processos no SO:
> ps -ef | grep -e orcl12c | grep -v grep

-- Voltando ao banco:
-- Server process (vinculados aos usuários)
 select *
   from v$process
  where pname is null;

-- Background process
 select pname
   from v$process
  where pname is not null;

-- Sessões ativas vinculadas ao usuário atual
-- Se você ainda estiver conectado com SYS poderá ver alguns jobs ou outros
-- processos do sistema, além da sua própria conexão.
 select *
   from v$session vs
  where vs.status = 'ACTIVE'
    and vs.username = USER;

-- Se ainda estiver como SYS, volte a conectar como CURSO@ORCL

-- Combinando informações da v$session com v$process
-- Note que a chave é o endereço do processo
 select vp.spid, vs.sid, vs.serial#, vs.program, vs.server, vs.type, vp.background, vp.pname
   from v$session vs,
        v$process vp
  where vs.status   = 'ACTIVE'
    and vs.username = USER
    and vs.paddr    = vp.addr;
    
/*
  Até agora nós vimos que uma conexão no banco gera uma sessão, mas esta
  relação nem sempre é um para um. Para a próxima demonstração, abra o sqlplus
  na VM com os seguintes comandos:
 */

> export ORACLE_SID=orcl
> sqlplus curso/curso

/*
  No sqlplus, execute os seguintes comandos:
 */

-- Esta é a mesma query que vimos acima, vai mostrar a sessão recém criada
-- do sqlplus, além de outras que já existam (ex.: SQL developer)
select sid, serial#, paddr, program from v$session where username = user;

-- Liga o recurso de trace automático
set autotrace on statistics;
-- Repete a mesma query acima
select sid, serial#, paddr from v$session where username = user;

-- Observe que existem duas linhas para o mesmo PADDR (uma para a sessão do
-- usuário e outra para o trace). Logo, uma conexão criou duas sessões.

/*
  Finalmente, vamos fazer uma tarefa que é relativamente comum para os DBAs,
  mas não muito para desenvolvedores.
*/

select vp.spid, 
       vs.sid, 
       vs.serial#, 
       vs.program, 
       vs.server, 
       vs.type
  from v$session vs,
       v$process vp
 where vs.status   = 'ACTIVE'
   and vs.username = USER
   and vs.paddr    = vp.addr;
 
-- Na linha de comando, executar o comando abaixo substituindo o SPID pelo 
-- valor da query acima
> ps -ef | grep SPID | grep -v grep

-- Para matar a sessão no SO
> kill -9 SPID

-- Testando a conexão
select 1 from dual;

-- Cuidado! Não matar nenhum processo background do banco, você pode derrubar
-- o banco inteiro!