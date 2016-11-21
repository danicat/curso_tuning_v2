/* aula11.sql: Estatísticas II
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
  Estatísticas de Sistema
  
  Estatísticas de sistema são as estatísticas que dizem para o Oracle o que
  ele pode esperar em termos de tempo de resposta e poder de processamento do
  hardware instalado.
 */

-- Estatísticas atuais
SELECT * FROM sys.aux_stats$;

-- Este comando deleta os valores atuais, retornando para o padrão
exec dbms_stats.delete_system_stats;

-- Estatísticas atuais
SELECT * FROM sys.aux_stats$;

-- Coletando estatísticas NOWORKLOAD
exec dbms_stats.gather_system_stats; 

SELECT * FROM sys.aux_stats$;

-- Coletando estatísticas de intervalo (INTERVAL)

-- Manualmente
exec dbms_stats.gather_system_stats('start');

SELECT * FROM sys.aux_stats$;

exec dbms_stats.gather_system_stats('stop');

SELECT * FROM sys.aux_stats$;


-- Automaticamente, parâmetro interval em minutos
exec dbms_stats.gather_system_stats('interval', INTERVAL => 1); 

SELECT * FROM sys.aux_stats$;
 
-- No modo interval, o Oracle vai monitorar tudo que acontece no sistema
-- para tentar determinar os tempos de resposta dele. Se o workload não
-- for significativo, pode ser que ele não ache os valores corretos e fique
-- sub-dimensionado.

-- Para simular uma carga, vamos utilizar uma procedure de calibração de I/O

--------------------------------------
-- Troque para o usuário SYS do CDB --
--------------------------------------

-- Execute os seguintes passos:
SET serveroutput ON

-- Inicio da coleta
exec dbms_stats.gather_system_stats('start');

-- Observe que a coleta está acontecendo
SELECT * FROM sys.aux_stats$;

-- Rotina de calibração
-- Este processo leva em torno de 10 minutos.
DECLARE
  l_latency  pls_integer;
  l_iops     pls_integer;
  l_mbps     pls_integer;
BEGIN
   dbms_resource_manager.calibrate_io (num_physical_disks => 1, 
                                       max_latency        => 20,
                                       max_iops           => l_iops,
                                       max_mbps           => l_mbps,
                                       actual_latency     => l_latency);
 
  dbms_output.put_line('Max IOPS = ' || l_iops);
  dbms_output.put_line('Max MBPS = ' || l_mbps);
  dbms_output.put_line('Latency  = ' || l_latency);
END;
/

-- fim da coleta
exec dbms_stats.gather_system_stats('stop');

SELECT * FROM sys.aux_stats$;

--------------------------------
-- Volte para o usuário CURSO --
--------------------------------

/*
  Controlando as Estatísticas
  
  A dbms_stats possui inúmeras procedures para setar estatísticas manualmente
  caso seja necessário. São a família de procedures set_*_stats. Exemplos: 
  set_table_stats, set_index_stats, etc
  
  Também é possível deletar estatísticas [já fizemos isso em outra prática] com
  as procedures delete_*_stats.
  
  Caso você precise impedir que novas estatísticas substituam as atuais, pode
  ainda utilizar o procedimento lock_*_stats. O oposto é unlock_*_stats.
  
  As vezes a coleta de estatísticas pode ter um efeito indesejado em algumas
  tabelas. Quando isto acontece, podemos recorrer ao histórico de estatísticas
  e restaurar uma versão anterior das mesmas.
  
  Ou ainda, podemos trabalhar com estatísticas pendentes, o que torna o ambiente
  mais previsível porém vai exigir maior trabalho por parte dos DBAs para
  gerenciar manualmente coletas de estatísticas. Veremos isso em detalhes a
  seguir.
  
  Primeiro alguns setups:
 */

-- Verifica a preferência global da dbms_stats. A preferência global vale para
-- todas as coletas. PUBLISH = TRUE significa que toda coleta entra 
-- automaticamente em produção. FALSE indica que toda coleta fica no status
-- pendente até ser publicada.
SELECT dbms_stats.get_prefs('PUBLISH') FROM dual;

-- Com este comando eu posso mudar individualmente a preferencia de uma tabela
exec dbms_stats.set_table_prefs('SCOTT', 'EMP', 'PUBLISH', 'false');

-- Para reverter basta mudar a propriedade de novo
exec dbms_stats.set_table_prefs('SCOTT', 'EMP', 'PUBLISH', 'true');

-- Para publicar todas as estatísticas pendentes
exec dbms_stats.publish_pending_stats(NULL, NULL);

-- Ou publicar apenas de um objeto específico
exec dbms_stats.publish_pending_stats('SCOTT','EMP');

-- Para deletar as estatísticas pendentes:
exec dbms_stats.delete_pending_stats('SCOTT','EMP');

-- Caso precise testar os efeitos de uma coleta de estatísticas antes de
-- publicá-la, pode instruir o otimizador a fazer isso com o comando abaixo:
ALTER SESSION SET optimizer_use_pending_statistics=TRUE;

-- Vamos ver como isso funciona na prática. Pegaremos como exemplo a tabela
-- SH.SALES:
SELECT channel_id, count(*) 
  FROM sh.sales
 GROUP BY channel_id 
 ORDER BY 2;

-- Vamos garantir que estamos usando as estatísticas atuais
ALTER SESSION SET optimizer_use_pending_statistics=FALSE;

EXPLAIN PLAN FOR
SELECT s.cust_id,s.prod_id,sum(s.amount_sold)
FROM sh.sales s
WHERE channel_id=9
GROUP BY s.cust_id, s.prod_id
ORDER BY s.cust_id, s.prod_id;

-- table access full?? channel id 9 tem poucas linhas!
SELECT * FROM TABLE(dbms_xplan.display);

EXPLAIN PLAN FOR
SELECT s.cust_id,s.prod_id,sum(s.amount_sold)
FROM sh.sales s
WHERE channel_id = 3
GROUP BY s.cust_id, s.prod_id
ORDER BY s.cust_id, s.prod_id;

-- table access full = ok, channel_id 3 tem muitas linhas
SELECT * FROM TABLE(dbms_xplan.display);

SELECT table_name,
       partition_name,
       num_rows, 
       empty_blocks, 
       avg_row_len, 
       BLOCKS, 
       last_analyzed
  FROM dba_tab_statistics d
 WHERE owner='SH'
   AND table_name='SALES';

-- Estatísticas de coluna
SELECT column_name, 
       num_distinct,
       low_value,
       high_value,
       density,
       num_nulls,
       num_buckets,
       histogram
  FROM dba_tab_col_statistics d
 WHERE owner='SH'
   AND table_name='SALES';

-- Consegue identificar o problema???
-------------------------------------

-- Não é o caso, já que estamos fazendo um full table scan, porém existem
-- estatísticas por partição, se for necessário:
SELECT partition_name,
       column_name, 
       num_distinct,
       low_value,
       high_value,
       density,
       num_nulls,
       num_buckets,
       histogram
  FROM dba_part_col_statistics d
 WHERE owner='SH'
   AND table_name='SALES';

-- Temos uma hipotese de que uma coleta de estatísticas resolve o problema
-- mas não queremos piorar ainda mais o problema, então vamos testar!

-- Evita que o gather stats publique as estatísticas imediatamente
exec dbms_stats.set_table_prefs('SH','SALES','PUBLISH','FALSE');

-- Conferindo
SELECT dbms_stats.get_prefs('PUBLISH', 'SH', 'SALES' ) FROM dual;

-- Coleta de estatísticas
exec dbms_stats.gather_table_stats('SH','SALES',method_opt => 'FOR ALL COLUMNS SIZE AUTO');

-- Esta é a data da última estatística que foi coletada. Se nenhuma coleta foi
-- feita na VM desde o inicio do curso ela deve ser diferente do dia de hoje
-- porque a coleta que fizemos agora ainda está pendente
SELECT last_analyzed FROM dba_tables WHERE table_name='SALES';

-- Para verificar isso:
SELECT table_name, 
       partition_name,
       last_analyzed
  FROM dba_tab_pending_stats;

SELECT table_name, 
       partition_name, 
       column_name,
       raw_to_num(low_value)  low_value,
       raw_to_num(high_value) high_value,
       density,
       num_distinct
  FROM dba_col_pending_stats
 WHERE owner = 'SH'
   AND table_name = 'SALES'
   AND column_name = 'CHANNEL_ID';

-- Vamos ver se mudou o plano
ALTER SESSION SET optimizer_use_pending_statistics=TRUE;

EXPLAIN PLAN FOR
SELECT s.cust_id,s.prod_id,sum(s.amount_sold)
FROM sh.sales s
WHERE channel_id=9
GROUP BY s.cust_id, s.prod_id
ORDER BY s.cust_id, s.prod_id;

SELECT * FROM TABLE(dbms_xplan.display);

EXPLAIN PLAN FOR
SELECT s.cust_id,s.prod_id,sum(s.amount_sold)
FROM sh.sales s
WHERE channel_id = 3
GROUP BY s.cust_id, s.prod_id
ORDER BY s.cust_id, s.prod_id;

SELECT * FROM TABLE(dbms_xplan.display);

-- Deu certo! Vamos publicar...
exec dbms_stats.publish_pending_stats ('SH','SALES');

SELECT count(*) FROM dba_tab_pending_stats;

ALTER SESSION SET optimizer_use_pending_statistics=FALSE;

/*
  Restaurando estatísticas antigas
  
  Como nem sempre nós tomamos este cuidado de validar todas as estatísticas
  pendentes antes de publicar, outra alternativa é deixar a publicação
  automática [padrão] e restaurar as estatísticas quando acontece algum
  problema. Veja como:
*/ 

-- A estatística mais antiga disponível:
SELECT dbms_stats.get_stats_history_availability  FROM dual;

-- Por padrão o período de retenção é 31 dias, mas ele pode ser configurado
SELECT dbms_stats.get_stats_history_retention FROM dual;

-- Alterando para 60 dias
EXECUTE dbms_stats.alter_stats_history_retention (60);
SELECT dbms_stats.get_stats_history_retention FROM dual;

-- Se você executou todos os passos da seção anterior, deve ter acabado de
-- atualizar as estatísticas desta tabela
SELECT table_name, partition_name, stats_update_time 
  FROM dba_tab_stats_history 
 WHERE table_name='SALES' 
   AND owner='SH';

-- Estatística atual
SELECT partition_name,
       column_name, 
       num_distinct,
       num_nulls,
       num_buckets,
       histogram
  FROM dba_part_col_statistics d
 WHERE owner='SH'
   AND table_name='SALES'
   AND column_name = 'CHANNEL_ID';
   
SELECT SYSTIMESTAMP FROM dual;

-- Voltando as estatísticas para duas horas atrás
EXECUTE dbms_stats.restore_table_stats('SH','SALES',SYSTIMESTAMP - 2/24);

-- Estatística restaurada
SELECT partition_name,
       column_name, 
       num_distinct,
       num_nulls,
       num_buckets,
       histogram
  FROM dba_part_col_statistics d
 WHERE owner='SH'
   AND table_name='SALES'
   AND column_name = 'CHANNEL_ID';

-- Voltamos ao plano anterior
EXPLAIN PLAN FOR
SELECT s.cust_id,s.prod_id,sum(s.amount_sold)
FROM sh.sales s
WHERE channel_id=9
GROUP BY s.cust_id, s.prod_id
ORDER BY s.cust_id, s.prod_id;

SELECT * FROM TABLE(dbms_xplan.display);

-- Finalmente, se eu quiser comparar as estatísticas da tabela:

SELECT *
  FROM TABLE(dbms_stats.diff_table_stats_in_history('SH',
                                                    'SALES', 
                                                    SYSTIMESTAMP - 1));
                                                    
-- Ou comparar estatísticas pendentes:
exec dbms_stats.gather_table_stats('SH','SALES',method_opt => 'FOR ALL COLUMNS SIZE AUTO');

SELECT *
  FROM TABLE(dbms_stats.diff_table_stats_in_pending('SH','SALES'));

exec dbms_stats.publish_pending_stats ('SH','SALES');

SELECT *
  FROM TABLE(dbms_stats.diff_table_stats_in_history('SH',
                                                    'SALES', 
                                                    SYSTIMESTAMP - 1));


-- Referências:
-- http://psoug.org/reference/dbms_stats.html
-- https://oracle-base.com/articles/11g/statistics-collection-enhancements-11gr1
-- http://gavinsoorma.com/2009/09/11g-pending-and-published-statistics/
-- http://gavinsoorma.com/2011/03/restoring-optimizer-statistics/
-- https://jonathanlewis.wordpress.com/2006/11/29/low_value-high_value/


-----------------------------------------
-- Estatísticas de Tabelas Temporárias --
-----------------------------------------

-- Verifica a preferência global de tabela temporária
SELECT dbms_stats.get_prefs('GLOBAL_TEMP_TABLE_STATS') FROM dual;

-- Configura como estatística compartilhada
BEGIN
  dbms_stats.set_global_prefs (
    pname   => 'GLOBAL_TEMP_TABLE_STATS',
    pvalue  => 'SHARED');
END;
/

-- Configura como estatística por sessão
BEGIN
  dbms_stats.set_global_prefs (
    pname   => 'GLOBAL_TEMP_TABLE_STATS',
    pvalue  => 'SESSION');
END;
/

TRUNCATE TABLE gtt1;
DROP TABLE gtt1;
CREATE GLOBAL TEMPORARY TABLE gtt1 (
  ID NUMBER,
  description VARCHAR2(20)
) ON COMMIT PRESERVE ROWS;


-- Configura estatísticas de GTT como compartilhadas
BEGIN
  dbms_stats.set_global_prefs (
    pname   => 'GLOBAL_TEMP_TABLE_STATS',
    pvalue  => 'SHARED');
END;
/

-- Insere alguns dados e coleta estatísticas
INSERT INTO gtt1
SELECT LEVEL, 'description'
FROM   dual
CONNECT BY LEVEL <= 100;

exec dbms_stats.gather_table_stats('CURSO','GTT1');

-- O count abaixo vai depender do tipo da GTT1:
-- on commit delete rows   = 0
-- on commit preserve rows = 100
SELECT count(*) FROM gtt1;

-- Existe um commit implicito no dbms_stats quando o GLOBAL_TEMP_TABLE_STATS é
-- configurado como SHARED

-- Display the statistics information and scope.
COLUMN table_name format a20

SELECT table_name, num_rows, SCOPE
FROM   dba_tab_statistics
WHERE  owner = 'CURSO'
AND    table_name = 'GTT1';

-- Reset the GTT statistics preference to SESSION.
BEGIN
  dbms_stats.set_global_prefs (
    pname   => 'GLOBAL_TEMP_TABLE_STATS',
    pvalue  => 'SESSION');
END;
/

INSERT INTO gtt1
SELECT LEVEL, 'description'
FROM   dual
CONNECT BY LEVEL <= 1000;
COMMIT;

exec dbms_stats.gather_table_stats(USER,'GTT1');

-- O count abaixo vai depender do tipo da GTT1:
-- on commit delete rows   = 1000
-- on commit preserve rows = 1100
SELECT count(*) FROM gtt1;

-- Existe um commit implicito no dbms_stats quando o GLOBAL_TEMP_TABLE_STATS é
-- configurado como SHARED

-- Exibe estatísticas e informação de escopo
COLUMN table_name format a20

SELECT table_name, num_rows, SCOPE
FROM   dba_tab_statistics
WHERE  owner = 'CURSO'
AND    table_name = 'GTT1';

---------------------------------------------
-- Fazer a consulta abaixo em outra sessão --
---------------------------------------------

-- Exibe estatísticas e informação de escopo
COLUMN table_name format a20

SELECT table_name, num_rows, SCOPE
FROM   dba_tab_statistics
WHERE  owner = 'CURSO'
AND    table_name = 'GTT1';

-- Referência
-- https://oracle-base.com/articles/12c/session-private-statistics-for-global-temporary-tables-12cr1
