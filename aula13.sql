/* aula13.sql: Trace de Aplicações
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
  O objetivo desta prática é mostrar as ferramentas disponíveis de tracing e
  como instrumentar as aplicações para facilitar o seu diagnóstico
*/

/*
  dbms_application_info é a package que nós podemos utilizar para instrumentar
  as aplicações. Com ela podemos preencher as informações module_name,
  action_name e client_info que aparecem na v$session
  
  Além disso, estas informações podem ser utilizadas para orientar o trace.
 */
BEGIN
  dbms_application_info.set_module(module_name => 'Controle de Estoque', 
                                   action_name => 'Executando Relatório de Materiais');
END;
/

SELECT osuser, 
       machine,
       PROGRAM,
       module,
       action 
  FROM v$session 
 WHERE username = USER;

BEGIN
  dbms_application_info.set_client_info('data, hora, meu IP, etc...');
END;
/

SELECT client_info 
  FROM v$session 
 WHERE SID=(SELECT SID FROM v$mystat WHERE ROWNUM=1);

SELECT sys_context('USERENV', 'TERMINAL') micro,
       sys_context('USERENV', 'IP_ADDRESS') ip,
       sys_context('USERENV', 'OS_USER') usuario_rede 
  FROM dual;

/*
  Tkprof: esta é uma ferramenta de formatação de arquivos de trace para
  extrair os principais dados e gerar um relatório.
 */

-- Relembrando: podemos colocar um identificador no trace file com este comando:
ALTER SESSION SET tracefile_identifier = 'aula13';

-- Relembrando: podemos achar o trace file com essa consulta
SELECT VALUE
FROM   v$diag_info
WHERE  NAME = 'Default Trace File';

-- Abaixo vamos simular uma aplicação real criando uma tabela e um
-- processo que insere linhas nesta tabela.
CREATE TABLE sql_trace_test (
  ID  NUMBER,
  description  VARCHAR2(50)
);

exec dbms_stats.gather_table_stats(USER, 'sql_trace_test');

CREATE OR REPLACE PROCEDURE populate_sql_trace_test (p_loops  IN  NUMBER) AS
  l_number  NUMBER;
BEGIN
  FOR i IN 1 .. p_loops loop
    INSERT INTO sql_trace_test (ID, description)
    VALUES (i, 'Description for ' || i);
  END loop;
  
  SELECT count(*)
  INTO   l_number
  FROM   sql_trace_test;
  
  COMMIT;
  
  dbms_output.put_line(l_number || ' rows inserted.');
END;
/
show errors

ALTER SESSION SET EVENTS '10046 trace name context forever, level 8';

SET serveroutput ON
exec populate_sql_trace_test(p_loops => 10);

ALTER SESSION SET EVENTS '10046 trace name context off';

-- Vá na linha de comando do servidor e acesse o diretório onde está o arquivo
-- de trace. 
-- Execute o comando abaixo na linha de comando para gerar o arquivo de texto
> tkprof <nome-do-arquivo>.trc trace_aula13.txt sys=NO waits=yes EXPLAIN=curso/curso@orcl


/*
  dbms_monitor
 */

-- TRACE por serviço, modulo e ação

-- Verifica o nome da instância para passar por parâmetro (pode ser omitido
-- para ativar na instancia atual - útil para RAC)
SELECT instance_name FROM gv$instance;

-- Ativa o trace por serviço, modulo e ação
BEGIN
  dbms_monitor.serv_mod_act_trace_enable(service_name  => 'ORCL', 
                                         module_name   => dbms_monitor.all_modules, 
                                         action_name   => dbms_monitor.all_actions, 
                                         waits         => TRUE, 
                                         binds         => TRUE, 
                                         instance_name =>'orcl12c');
END;
/

-- Desativa o trace por serviço, modulo e ação
-- Ativa o trace por serviço, modulo e ação
BEGIN
  dbms_monitor.serv_mod_act_trace_disable(service_name  => 'ORCL', 
                                          module_name   => dbms_monitor.all_modules, 
                                          action_name   => dbms_monitor.all_actions, 
                                          instance_name =>'orcl12c');
END;
/

-- TRACE por sessão
SELECT SID, serial#
  FROM v$session 
 WHERE username = USER;

-- Ativa o trace para uma sessão pelo sid,serial#
BEGIN
  dbms_monitor.session_trace_enable(session_id => 292, 
                                    serial_num => 59176, 
                                    waits      => TRUE, 
                                    binds      => FALSE);
END;
/

-- Se você não informar parâmetros ele faz o trace da sessão atual:
exec dbms_monitor.session_trace_enable;
-- ou
exec dbms_monitor.session_trace_enable(NULL, NULL);
-- ou ainda, especificando parâmetros:
exec dbms_monitor.session_trace_enable(NULL, NULL, TRUE, TRUE);
exec dbms_monitor.session_trace_enable(binds=>TRUE);

-- Desativa o trace por sessão
BEGIN
  dbms_monitor.session_trace_enable(session_id => 292, 
                                    serial_num => 59176);
END;
/

-- http://psoug.org/reference/dbms_monitor.html
-- http://eduardolegatti.blogspot.com/2009/05/um-pouco-do-pacote-dbmsapplicationinfo.html#ixzz4Ne2RVq1V 
-- https://oracle-base.com/articles/misc/sql-trace-10046-trcsess-and-tkprof#tracing_individual_sql_statements