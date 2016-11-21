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
  O objetivo desta pr�tica � fixar os conceitos de arquitetura de processos
  apresentados na aula te�rica. Assim como na pr�tica anterior vamos passar
  por algumas views importantes, por�m desta vez tamb�m vamos utilizar a
  linha de comando do sistema operacional (SO).
  
  Quando necess�rio executar uma linha no SO, ser� devidamente indicado no
  texto.
*/

/*
  Antes de come�ar a pr�tica sobre processos precisamos verificar se o Oracle
  est� utilizando o modelo de arquitetura multi-processo ou multi-thread. O
  par�metro threaded_execution mostra justamente isso.
  
  O modelo de arquitetura multi-thread � um conceito novo do Oracle 12c. Neste
  modelo, ao inv�s de abrir um processo de SO para cada processo do servidor, o
  Oracle pode optar por criar threads em um processo comum. 
  
  Tecnicamente threads s�o mais leves em termos de processamento do que
  processos, podendo resultar em um ganho de performance. Por outro lado, ao 
  matar um processo "m�e" de v�rias threads, todas as threads filhas ser�o 
  terminadas tamb�m. Por este motivo, alguns processos mais importantes
  continuam como processos mesmo no modelo multi-thread.
  
  Trabalhar com o modelo multi-threaded exige mais cuidado pelos DBAs, porque
  estes podem estar acostumados a matar processos no SO e, neste caso, um erro
  pode derrubar centenas de usu�rios.
  
  Nesta aula vamos considerar a arquitetura cl�ssica multi-processo para n�o
  nos preocuparmos com as complexidades do gerenciamento multi-threaded. Por�m,
  caso tenha interesse em se aprofundar sobre o assunto, a refer�ncia abaixo �
  um bom ponto de partida:
  
  https://oracle-base.com/articles/12c/multithreaded-model-using-threaded_execution12cr1
 */
show parameter threaded_execution

-- False! Estamos prontos para continuar

/*
  A view mais importante para a arquitetura de processos � a v$process, a qual
  j� tivemos contato quando exploramos a PGA.
 */

-- Apenas para relembrar...
desc v$process

col spid format a8
col stid format a8
select spid,   -- Identificador de processo do sistema operacional (PID)
       stid,   -- Identificador de thread do sistema operacional
       sosid,  -- Identificador �nico do sistema operacional (pode ser thread
               -- processo, dependendo do modelo
       program,
       execution_type
  from v$process 
 order by spid;

-- Trocar para usu�rio SYS do CDB
select count(*) from v$process;

-- Executar no SO da VM e comparar o resultado... pode variar +/- 2 processos 
-- porque alguns processos s�o criados e encerrados muito rapidamente.
> ps -ef | grep -e orcl12c | grep -v grep | wc -l

-- Para ver todos os processos no SO:
> ps -ef | grep -e orcl12c | grep -v grep

-- Voltando ao banco:
-- Server process (vinculados aos usu�rios)
 select *
   from v$process
  where pname is null;

-- Background process
 select pname
   from v$process
  where pname is not null;

-- Sess�es ativas vinculadas ao usu�rio atual
-- Se voc� ainda estiver conectado com SYS poder� ver alguns jobs ou outros
-- processos do sistema, al�m da sua pr�pria conex�o.
 select *
   from v$session vs
  where vs.status = 'ACTIVE'
    and vs.username = USER;

-- Se ainda estiver como SYS, volte a conectar como CURSO@ORCL

-- Combinando informa��es da v$session com v$process
-- Note que a chave � o endere�o do processo
 select vp.spid, vs.sid, vs.serial#, vs.program, vs.server, vs.type, vp.background, vp.pname
   from v$session vs,
        v$process vp
  where vs.status   = 'ACTIVE'
    and vs.username = USER
    and vs.paddr    = vp.addr;
    
/*
  At� agora n�s vimos que uma conex�o no banco gera uma sess�o, mas esta
  rela��o nem sempre � um para um. Para a pr�xima demonstra��o, abra o sqlplus
  na VM com os seguintes comandos:
 */

> export ORACLE_SID=orcl
> sqlplus curso/curso

/*
  No sqlplus, execute os seguintes comandos:
 */

-- Esta � a mesma query que vimos acima, vai mostrar a sess�o rec�m criada
-- do sqlplus, al�m de outras que j� existam (ex.: SQL developer)
select sid, serial#, paddr, program from v$session where username = user;

-- Liga o recurso de trace autom�tico
set autotrace on statistics;
-- Repete a mesma query acima
select sid, serial#, paddr from v$session where username = user;

-- Observe que existem duas linhas para o mesmo PADDR (uma para a sess�o do
-- usu�rio e outra para o trace). Logo, uma conex�o criou duas sess�es.

/*
  Finalmente, vamos fazer uma tarefa que � relativamente comum para os DBAs,
  mas n�o muito para desenvolvedores.
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

-- Para matar a sess�o no SO
> kill -9 SPID

-- Testando a conex�o
select 1 from dual;

-- Cuidado! N�o matar nenhum processo background do banco, voc� pode derrubar
-- o banco inteiro!