/* aula17.sql: Materialized Views
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
 
 -----------------------------
 -- Funcionalidades Básicas --
 -----------------------------

DROP TABLE employees;
CREATE TABLE employees AS
SELECT * FROM hr.employees;

ALTER TABLE employees ADD PRIMARY KEY(employee_id);

DROP MATERIALIZED VIEW emp_mv;
CREATE MATERIALIZED VIEW emp_mv 
AS SELECT * FROM employees;

SELECT * FROM emp_mv;

-- Views de performance
desc user_snapshots

SELECT name, table_name, updatable, refresh_method, refresh_mode
FROM user_snapshots;

SELECT name, query
FROM user_snapshots;

SELECT name, last_refresh
FROM user_mview_refresh_times;

SELECT constraint_name, table_name, constraint_type
FROM user_constraints;

-- A view é "materializada" como uma tabela
SELECT * 
  FROM user_tables 
 WHERE table_name = 'EMP_MV';

-- Diferente das views normais, não é possível fazer operações (por default)
INSERT INTO emp_mv(employee_id, first_name, last_name, email, hire_date, job_id) 
VALUES(300, 'John', 'Doe', 'john.doe@example.com', SYSDATE, 'SA_REP');

-- Inserindo na tabela de origem
INSERT INTO employees(employee_id, first_name, last_name, email, hire_date, job_id) 
VALUES(300, 'John', 'Doe', 'john.doe@example.com', SYSDATE, 'SA_REP');
COMMIT;

SELECT * 
  FROM employees 
 WHERE employee_id = 300;

-- Não propaga automaticamente para a MV
SELECT * 
  FROM emp_mv
 WHERE employee_id = 300;

-- Refresh manual
EXEC DBMS_MVIEW.refresh('EMP_MV');

SELECT * 
  FROM emp_mv
 WHERE employee_id = 300;

-- Refresh Fast (INCREMENTAL)

-- Precisa ter um materialized view log
DROP MATERIALIZED VIEW LOG ON employees;
CREATE MATERIALIZED VIEW LOG ON employees
WITH PRIMARY KEY
INCLUDING NEW VALUES;

DROP MATERIALIZED VIEW emp_mv_fast;
CREATE MATERIALIZED VIEW emp_mv_fast 
REFRESH FAST
AS SELECT * FROM employees;

-- DELETE FROM employees WHERE employee_id = 301;
-- COMMIT;

SELECT * 
  FROM employees
 WHERE employee_id = 301;

SELECT * 
  FROM emp_mv_fast
 WHERE employee_id = 301;

INSERT INTO employees(employee_id, first_name, last_name, email, hire_date, job_id) 
VALUES(301, 'Jane', 'Doe', 'jane.doe@example.com', SYSDATE, 'SA_REP');
COMMIT;

-- Não propagou a mudança
SELECT * 
  FROM emp_mv_fast
 WHERE employee_id = 301;

-- Refresh manual e INCREMENTAL (REFRESH FAST)
EXEC DBMS_MVIEW.refresh('EMP_MV');

SELECT * 
  FROM emp_mv_fast
 WHERE employee_id = 301;

-- Refresh INCREMENTAL e AUTOMÁTICO
DROP MATERIALIZED VIEW emp_mv_fast2;
CREATE MATERIALIZED VIEW emp_mv_fast2
REFRESH FAST ON COMMIT
AS SELECT * FROM employees;

-- DELETE FROM employees WHERE employee_id = 302;
-- COMMIT;

SELECT * 
  FROM emp_mv_fast2
 WHERE employee_id = 302;

INSERT INTO employees(employee_id, first_name, last_name, email, hire_date, job_id) 
VALUES(302, 'Oliver', 'Queen', 'oliver.queen@example.com', SYSDATE, 'SA_REP');
COMMIT;

SELECT * 
  FROM emp_mv_fast2
 WHERE employee_id = 302;

-- Refresh Periódico

-- Opção 1: programaticamente adiciona a mview a um grupo

-- Cria um grupo de refresh
BEGIN
   DBMS_REFRESH.make(
     name                 => 'CURSO.MINUTO_EM_MINUTO',
     list                 => '',
     next_date            => SYSDATE,
     interval             => '/*1:Min*/ SYSDATE + 1/(60*24)',
     implicit_destroy     => FALSE,
     lax                  => FALSE,
     job                  => 0,
     rollback_seg         => NULL,
     push_deferred_rpc    => TRUE,
     refresh_after_errors => TRUE,
     purge_option         => NULL,
     parallelism          => NULL,
     heap_size            => NULL);
END;
/

--  Adiciona a mview ao grupo de refresh
BEGIN
   DBMS_REFRESH.add(
     name => 'CURSO.MINUTO_EM_MINUTO',
     list => 'CURSO.EMP_MV',
     lax  => TRUE);
END;
/

SELECT name, 
       table_name, 
       updatable, 
       refresh_method, 
       refresh_mode, 
       start_with, 
       next
  FROM user_snapshots;

BEGIN
  DBMS_REFRESH.destroy(name => 'CURSO.MINUTO_EM_MINUTO');
END;
/

-- Opção 2: Programando os updates direto na criação
DROP MATERIALIZED VIEW emp_mv_per;
CREATE MATERIALIZED VIEW emp_mv_per
REFRESH FAST
START WITH SYSDATE
NEXT TRUNC(SYSDATE+1) + 1/24
AS SELECT * FROM employees;

SELECT name, 
       table_name, 
       updatable, 
       refresh_method, 
       refresh_mode, 
       start_with, 
       next
  FROM user_snapshots;
  
----------------
-- For Update --
----------------

DROP MATERIALIZED VIEW emp_mv_upd;
CREATE MATERIALIZED VIEW emp_mv_upd
REFRESH FAST
START WITH SYSDATE
NEXT TRUNC(SYSDATE+1) + 1/24
FOR UPDATE
AS SELECT * FROM employees;

SELECT name, 
       table_name, 
       updatable, 
       refresh_method, 
       refresh_mode, 
       start_with, 
       next
  FROM user_snapshots;

INSERT INTO emp_mv_upd(employee_id, first_name, last_name, email, hire_date, job_id) 
VALUES(304, 'Felicity', 'Smoke', 'f.smoke@example.com', SYSDATE, 'SA_REP');
COMMIT;

-- ???
SELECT * 
  FROM employees
 WHERE employee_id = 304;

-- A linha está apenas na MVIEW!
SELECT * 
  FROM emp_mv_upd
 WHERE employee_id = 304;
 
-- A cláusula FOR UPDATE foi desenhada para replicação de dados entre sites
-- e depende do gerenciamento por um recurso chamado ADVANCED REPLICATION,
-- porém explorar este recurso vai além do escopo deste curso.
--
-- O objetivo deste código foi demonstrar que simplesmente colocar o FOR
-- UPDATE não resulta no comportamento que esperamos de uma view.

-------------------------------------
-- MATERIALIZED VIEW QUERY REWRITE --
-------------------------------------

-- Executar como SYSTEM do PDB
GRANT GLOBAL QUERY REWRITE TO curso;
GRANT SELECT ON sh.sales TO curso;
GRANT SELECT ON sh.times TO curso;

-- Voltar para usuário CURSO

-- Veja o plano de execução desta consulta
EXPLAIN PLAN FOR
 SELECT t.calendar_month_desc, sum(s.amount_sold) AS dollars
   FROM sh.sales s, sh.times t 
  WHERE s.time_id = t.time_id
  GROUP BY t.calendar_month_desc;

SELECT *
  FROM TABLE(dbms_xplan.display);

-- Criamos uma view materializada com query rewrite para esta consulta
DROP MATERIALIZED VIEW cal_month_sales_mv2;
CREATE MATERIALIZED VIEW cal_month_sales_mv2
 ENABLE QUERY REWRITE AS
 SELECT t.calendar_month_desc, sum(s.amount_sold) AS dollars
   FROM sh.sales s, sh.times t 
  WHERE s.time_id = t.time_id
  GROUP BY t.calendar_month_desc;

-- Compare o plano
EXPLAIN PLAN FOR
SELECT t.calendar_month_desc, sum(s.amount_sold)
FROM sh.sales s, sh.times t WHERE s.time_id = t.time_id
GROUP BY t.calendar_month_desc;

SELECT *
  FROM TABLE(dbms_xplan.display);
  
-- https://docs.oracle.com/database/121/DWHSG/qrbasic.htm#DWHSG0184

-------------------
-- Explain MView --
-------------------

-- Acessar o sqlplus e rodar os scripts abaixo:
> sqlplus curso/curso

-- Cria MV_CAPABILITIES_TABLE
> @$ORACLE_HOME/rdbms/admin/utlxmv.sql

-- Cria REWRITE_TABLE
> @$ORACLE_HOME/rdbms/admin/utlxrw.sql

select * 
  from MV_CAPABILITIES_TABLE;

exec dbms_mview.explain_mview('emp_mv');

select * 
  from MV_CAPABILITIES_TABLE
 where mvname = 'EMP_MV';

exec dbms_mview.explain_mview('cal_month_sales_mv2');

select * 
  from MV_CAPABILITIES_TABLE
 where mvname = 'CAL_MONTH_SALES_MV2';

truncate table rewrite_table;

EXECUTE DBMS_MVIEW.EXPLAIN_REWRITE('SELECT sum(s.amount_sold) AM_sold FROM sh.sales s');

select *
  from rewrite_table;

truncate table rewrite_table;

EXECUTE DBMS_MVIEW.EXPLAIN_REWRITE('SELECT sum(s.amount_sold) AM_sold FROM sh.sales s, sh.times t WHERE s.time_id = t.time_id');

select *
  from rewrite_table;
  
--exec dbms_mview.refresh('CAL_MONTH_SALES_MV2');

----------------
-- Tune MView --
----------------

select *
  from user_tune_mview;

var  tname varchar2(30);
exec :tname := 'TAREFA1';
exec DBMS_ADVISOR.TUNE_MVIEW(:tname, 'CREATE MATERIALIZED VIEW mv1 AS SELECT sum(s.amount_sold) AM_sold FROM sh.sales s, sh.times t WHERE s.time_id = t.time_id');

-- produz recomendações para habilitar REFRESH FAST e QUERY REWRITE
select *
  from user_tune_mview
 where TASK_NAME = 'TAREFA1';
