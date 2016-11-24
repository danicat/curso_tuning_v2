/* aula12.sql: Compartilhamento de Cursores
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
  O objetivo desta prática é complementar a nossa conversa sobre padrões
  de codificação com algumas informações adicionas sobre compartilhamento
  de cursores
*/

DROP TABLE employees;
CREATE TABLE employees AS
SELECT e.* 
 FROM hr.employees e, (SELECT ROWNUM FROM dual CONNECT BY LEVEL <= 10000);

-- 1 milhão de linhas
SELECT count(*) FROM employees;

-- Observe a distribuição de departamentos
SELECT department_id, count(*)
  FROM employees
 GROUP BY department_id
 ORDER BY 2 DESC;

-- vamos dividir pela metade e aleatoriamente o departamento 10
UPDATE employees
   SET department_id = CASE WHEN mod(trunc(dbms_random.VALUE * 2),2) = 0
                            THEN 5
                            ELSE 15
                            END
 WHERE department_id = 10;

-- Agora vamos consolidar o vários departamentos no departamento 50
UPDATE employees
   SET department_id = 50
 WHERE department_id IN (80,100,30,90,20);

COMMIT;

/* 
  O objetivo dos passos anteriores foi gerar uma distribuição desbalanceada
  onde um valor domina praticamente toda a tabela (departamento 50) e outros
  valores são bem raros (departamentos 5 e 15)
  
  Neste cenário a consulta pelo departamento 50 favorece um table access full
  enquanto que a consulta pelo departamento 5 ou pelo departamento 15 favorecem
  o acesso por índice.
*/

-- Observe a distribuição
SELECT department_id, count(*)
  FROM employees
 GROUP BY department_id
 ORDER BY 2 DESC;

DROP INDEX idx_emp_depto;
CREATE INDEX idx_emp_depto ON employees(department_id);

BEGIN
  dbms_stats.gather_table_stats(
      USER,
      'EMPLOYEES', 
      method_opt => 'FOR ALL COLUMNS SIZE AUTO');
END;
/

-- Vamos limpar os planos existentes para garantir a consistência do teste
ALTER SYSTEM FLUSH SHARED_POOL;

-- Execute as seguintes querys
SELECT /*bloco1*/ count(*), MAX(employee_id) FROM employees WHERE department_id = 50;
SELECT /*bloco1*/ count(*), MAX(employee_id) FROM employees WHERE department_id = 100;
SELECT /*bloco1*/ count(*), MAX(employee_id) FROM employees WHERE department_id = 5;

-- Observe que mesmo sendo exatamente a mesma query, apenas com valores
-- distintos, o Oracle interpretou como três querys diferentes:
SELECT sql_id, 
       sql_text, 
       plan_hash_value, 
       fetches, 
       executions, 
       loads, 
       loaded_versions
  FROM v$sql
 WHERE sql_text LIKE 'SELECT /*bloco1*/%';

-- No entanto, observe atentamente ao PLAN_HASH_VALUE. Duas querys, mesmo sendo
-- diferentes, utilizaram o mesmo plano. Duvida? :) Confira os planos:

EXPLAIN PLAN FOR
SELECT /*bloco1*/ count(*), MAX(employee_id) FROM employees WHERE department_id = 5;
 
SELECT * FROM TABLE(dbms_xplan.display);

-- Agora vamos executar a mesma consulta com binds
SELECT /*bloco1*/ count(*), MAX(employee_id) FROM employees WHERE department_id = :depto;

-- Repare no flag IS_BIND_SENSITIVE
SELECT sql_id, 
       child_number, 
       sql_text, 
       plan_hash_value, 
       is_bind_sensitive, 
       is_bind_aware, 
       buffer_gets 
  FROM v$sql
 WHERE sql_text LIKE 'SELECT /*bloco1*/%';


-------------------------------------
-- Executar esta etapa do SQL*Plus --
-------------------------------------

var depto NUMBER;

exec :depto := 5;
SELECT /*bloco1*/ count(*), MAX(employee_id) FROM employees WHERE department_id = :depto;
exec :depto := 50;
SELECT /*bloco1*/ count(*), MAX(employee_id) FROM employees WHERE department_id = :depto;

exec :depto := 5;
SELECT /*bloco1*/ count(*), MAX(employee_id) FROM employees WHERE department_id = :depto;
exec :depto := 50;
SELECT /*bloco1*/ count(*), MAX(employee_id) FROM employees WHERE department_id = :depto;

------------------------------
-- Retorne ao SQL Developer --
------------------------------

-- Repare nos flag IS_BIND_SENSITIVE e IS_BIND_AWARE
SELECT sql_id, 
       child_number, 
       sql_text, 
       plan_hash_value, 
       is_bind_sensitive, 
       is_bind_aware, 
       buffer_gets 
  FROM v$sql
 WHERE sql_text LIKE 'SELECT /*bloco1*/%';

-- Observe que para a mesma query cada child_number tem um plano diferente
SELECT *
  FROM v$sql_plan
 WHERE sql_id = 'fkaycpxt6xqfx';

-- O segundo parâmetro é o child_number
SELECT * FROM TABLE(dbms_xplan.display_cursor('fkaycpxt6xqfx', 1));

SELECT *
  FROM v$sql_shared_cursor
 WHERE sql_id = '9ncr3jkmxhfgm';
 
 