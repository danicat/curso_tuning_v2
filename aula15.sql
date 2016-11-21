/* aula15.sql: Bulk Collect e Forall
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
  O objetivo desta pr�tica � demonstrar as t�cnicas de processamento em
  massa BULK COLLECT e FORALL.
*/

/*
  N�s vamos criar uma massa de dados para simular um processo de aumento
  de sal�rio na tabela de funcion�rios. A regra � dar um aumento de acordo
  com a Avalia��o de Desempenho (coluna aval).
  
  Note que a regra poderia ser facilmente implementada em um �nico update,
  por�m o objetivo aqui � demonstrar a t�cnica para ser aplicada em cen�rios
  mais complexos.
 */

SET serveroutput ON

-- Cria uma massa de dados para o nosso processo
DROP TABLE employees;
CREATE TABLE employees AS
SELECT * FROM hr.employees, (SELECT ROWNUM FROM dual CONNECT BY LEVEL <= 5000);

CREATE INDEX emp_idx ON employees(employee_id);

-- ~500k linhas
SELECT count(*) FROM employees;

-- Adiciona a coluna avalia��o  
ALTER TABLE employees ADD aval NUMBER;

-- Seta o seed para garantir reproducibilidade
BEGIN
  dbms_random.SEED(1234);
END;
/

-- Atribui uma avalia��o de desempenho aleat�ria para cada funcion�rio
-- Garante que cada funcion�rio tem um id unico
UPDATE employees
   SET aval        = trunc(dbms_random.VALUE(1,5)),
       employee_id = ROWNUM;
   
COMMIT;

-- Verificando
SELECT employee_id, count(*)
  FROM employees
 GROUP BY employee_id
 HAVING count(*) > 1;

BEGIN
  dbms_stats.gather_table_stats(USER, 'EMPLOYEES');
END;
/

SELECT employee_id, salary, aval
  FROM employees
fetch FIRST 5 ROWS ONLY;
  
-- Nossa procedure de neg�cio
-- Vers�o 1: lenta, faz um loop e update linha a linha
CREATE OR REPLACE PROCEDURE aumenta_salario
AS
  v_salario_novo  employees.salary%TYPE;
  t0              NUMBER := dbms_utility.get_time;
BEGIN
  FOR emp IN (SELECT employee_id, salary, aval FROM employees)
  loop
    v_salario_novo := emp.salary * CASE WHEN emp.aval = 5
                                        THEN 1.5
                                        WHEN emp.aval = 4
                                        THEN 1.3
                                        WHEN emp.aval = 3
                                        THEN 1.2
                                        WHEN emp.aval = 2
                                        THEN 1.1
                                        ELSE 1.0
                                    END;
    UPDATE employees
       SET salary      = v_salario_novo
     WHERE employee_id = emp.employee_id; 
  END loop;
  
  dbms_output.put_line('Tempo decorrido: ' || 
                       to_char(dbms_utility.get_time - t0) || ' hsecs');
END;
/

-- Executa o processo
-- Tempo Decorrido: ? [Estimado 24 s]
BEGIN
  aumenta_salario;
END;
/
COMMIT;

-- Vers�o 2: um pouco melhor, utilizamos o bulk collect para ler v�rias linhas
--           em cada passada. Note que o default do FOR � ler de 100 em 100,
--           por isso vamos chamar a fun��o com o par�metro 1000, o que vai
--           causar uma redu��o de 10x no n�mero de fetches.
CREATE OR REPLACE PROCEDURE aumenta_salario(num_linhas IN pls_integer DEFAULT 100)
AS
  CURSOR c_emp IS
  SELECT employee_id, salary, aval FROM employees;
  
  TYPE emp_arr_typ IS TABLE OF c_emp%rowtype INDEX BY pls_integer;
  a_emp emp_arr_typ ;

  t0              NUMBER := dbms_utility.get_time;
BEGIN
  OPEN c_emp;
  loop
    fetch c_emp BULK COLLECT INTO a_emp LIMIT num_linhas;
    
    FOR i IN 1 .. a_emp.count
    loop
      a_emp(i).salary := a_emp(i).salary * CASE WHEN a_emp(i).aval = 5
                                                THEN 1.5
                                                WHEN a_emp(i).aval = 4
                                                THEN 1.3
                                                WHEN a_emp(i).aval = 3
                                                THEN 1.2
                                                WHEN a_emp(i).aval = 2
                                                THEN 1.1
                                                ELSE 1.0
                                           END;
      UPDATE employees
         SET salary      = a_emp(i).salary
       WHERE employee_id = a_emp(i).employee_id; 
    END loop;
    
    exit WHEN a_emp.count < num_linhas;
    
  END loop;

  dbms_output.put_line('Tempo decorrido: ' || 
                       to_char(dbms_utility.get_time - t0) || ' hsecs');
END;
/

-- Execute e marque o tempo
-- Tempo Decorrido: ? [Estimado: 22 s]
BEGIN
  aumenta_salario(1000);
END;
/
COMMIT;

-- Vers�o 3: R�pida, al�m do fetch de 1000 em 1000, melhoramos o c�digo fazendo
--           o update de 1000 em 1000. Este � o melhor dos mundos se tratando
--           de processamento com PL/SQL.
CREATE OR REPLACE PROCEDURE aumenta_salario(num_linhas IN pls_integer DEFAULT 100)
AS
  CURSOR c_emp IS
  SELECT employee_id, salary, aval FROM employees;
  
  TYPE emp_arr_typ IS TABLE OF c_emp%rowtype INDEX BY pls_integer;
  a_emp emp_arr_typ ;

  t0              NUMBER := dbms_utility.get_time;
BEGIN
  OPEN c_emp;
  loop
    fetch c_emp BULK COLLECT INTO a_emp LIMIT num_linhas;
    
    FOR i IN 1 .. a_emp.count
    loop
      a_emp(i).salary := a_emp(i).salary * CASE WHEN a_emp(i).aval = 5
                                                THEN 1.5
                                                WHEN a_emp(i).aval = 4
                                                THEN 1.3
                                                WHEN a_emp(i).aval = 3
                                                THEN 1.2
                                                WHEN a_emp(i).aval = 2
                                                THEN 1.1
                                                ELSE 1.0
                                           END;
    END loop;
    
    forall i IN 1 .. a_emp.count
    UPDATE employees
       SET salary      = a_emp(i).salary
     WHERE employee_id = a_emp(i).employee_id;
    
    exit WHEN a_emp.count < num_linhas;
    
  END loop;

  dbms_output.put_line('Tempo decorrido: ' || 
                       to_char(dbms_utility.get_time - t0) || ' hsecs');
END;
/

-- Execute e marque o tempo
-- Tempo Decorrido: ? [Estimado: 9 s]
BEGIN
  aumenta_salario(1000);
END;
/
COMMIT;

-- Vers�o 4: Mais r�pida
CREATE OR REPLACE PROCEDURE aumenta_salario(num_linhas IN pls_integer DEFAULT 100)
AS
  CURSOR c_emp IS
  SELECT employee_id, salary, aval, ROWID FROM employees;
  
  TYPE emp_arr_typ IS TABLE OF c_emp%rowtype INDEX BY pls_integer;
  a_emp emp_arr_typ ;

  t0              NUMBER := dbms_utility.get_time;
BEGIN
  OPEN c_emp;
  loop
    fetch c_emp BULK COLLECT INTO a_emp LIMIT num_linhas;
    
    FOR i IN 1 .. a_emp.count
    loop
      a_emp(i).salary := a_emp(i).salary * CASE WHEN a_emp(i).aval = 5
                                                THEN 1.5
                                                WHEN a_emp(i).aval = 4
                                                THEN 1.3
                                                WHEN a_emp(i).aval = 3
                                                THEN 1.2
                                                WHEN a_emp(i).aval = 2
                                                THEN 1.1
                                                ELSE 1.0
                                           END;
    END loop;
    
    forall i IN 1 .. a_emp.count
    UPDATE employees
       SET salary    = a_emp(i).salary
     WHERE ROWID     = a_emp(i).ROWID;
    
    exit WHEN a_emp.count < num_linhas;
    
  END loop;

  dbms_output.put_line('Tempo decorrido: ' || 
                       to_char(dbms_utility.get_time - t0) || ' hsecs');
END;
/

-- Execute e marque o tempo
-- Tempo Decorrido: ? [Estimado: 7 s]
BEGIN
  aumenta_salario(1000);
END;
/
COMMIT;

-- Do jeito correto
-- Tempo Decorrido: ? [Estimado: 4 s]
UPDATE (SELECT employee_id, 
               salary, 
               CASE WHEN aval = 5
                    THEN 1.5
                    WHEN aval = 4
                    THEN 1.3
                    WHEN aval = 3
                    THEN 1.2
                    WHEN aval = 2
                    THEN 1.1
                    ELSE 1.0
                END fator
          FROM employees)
   SET salary = salary * fator;

COMMIT;


-----------------------
-- FORALL INDICES OF --
-----------------------

/*
  Um novo requisito surgiu! A diretoria decidiu que a TI j� ganha bem demais
  e n�o precisa de aumento. O departamento da TI � o id 10.
 */
 
SELECT department_id, count(*)
  FROM employees
 GROUP BY department_id
 ORDER BY 1;

-- Mesma fun��o, com a regra nova
CREATE OR REPLACE PROCEDURE aumenta_salario_exceto_ti(num_linhas IN pls_integer DEFAULT 100)
AS
  CURSOR c_emp IS
  SELECT employee_id, department_id, salary, aval, ROWID FROM employees;
  
  TYPE emp_arr_typ IS TABLE OF c_emp%rowtype INDEX BY pls_integer;
  a_emp emp_arr_typ ;

  t0              NUMBER := dbms_utility.get_time;
BEGIN
  OPEN c_emp;
  loop
    fetch c_emp BULK COLLECT INTO a_emp LIMIT num_linhas;
    
    FOR i IN 1 .. a_emp.count
    loop
      IF a_emp(i).department_id != 10 THEN
        a_emp(i).salary := a_emp(i).salary * CASE WHEN a_emp(i).aval = 5
                                                  THEN 1.5
                                                  WHEN a_emp(i).aval = 4
                                                  THEN 1.3
                                                  WHEN a_emp(i).aval = 3
                                                  THEN 1.2
                                                  WHEN a_emp(i).aval = 2
                                                  THEN 1.1
                                                  ELSE 1.0
                                             END;
      ELSE
        -- TI n�o precisa de mais dinheiro
        -- remove da cole��o
        a_emp.DELETE(i);
      END IF;
    END loop;

    forall i IN indices OF a_emp
    UPDATE employees
       SET salary    = a_emp(i).salary
     WHERE ROWID     = a_emp(i).ROWID;
    
    exit WHEN a_emp.count < num_linhas;
    
  END loop;

  dbms_output.put_line('Tempo decorrido: ' || 
                       to_char(dbms_utility.get_time - t0) || ' hsecs');
END;
/

-- Antes
SELECT employee_id, salary, aval, department_id
  FROM employees
 WHERE department_id IN (10,20)
   AND aval > 1
fetch FIRST 10 ROWS ONLY;

-- Execute
BEGIN
  aumenta_salario_exceto_ti(1000);
END;
/
COMMIT;

-- Depois
SELECT employee_id, salary, aval, department_id
  FROM employees
 WHERE department_id IN (10,20)
   AND aval > 1
fetch FIRST 10 ROWS ONLY;

----------------------------
-- FORALL SAVE EXCEPTIONS --
----------------------------

/*
  Mais um dia de trabalho come�a e mais uma regra surgiu: agora nenhum
  funcion�rio pode ganhar mais do que 100 mil de sal�rio.
 */

-- Provavelmente ilegal... mas ordens s�o ordens!
UPDATE employees
   SET salary = 100000
 WHERE salary > 100000;

COMMIT;

-- Deixa a diretoria tranquila de novo
ALTER TABLE employees ADD CONSTRAINT salario_100k CHECK (salary <= 100000);

-- Precisamos capturar as exce��es caso o processo aumente o sal�rio al�m de 100k
CREATE OR REPLACE PROCEDURE aumenta_salario_exceto_ti(num_linhas IN pls_integer DEFAULT 100)
AS
  CURSOR c_emp IS
  SELECT employee_id, department_id, salary, aval, ROWID FROM employees;
  
  TYPE emp_arr_typ IS TABLE OF c_emp%rowtype INDEX BY pls_integer;
  a_emp emp_arr_typ ;

  t0              NUMBER := dbms_utility.get_time;
BEGIN
  OPEN c_emp;
  loop
    fetch c_emp BULK COLLECT INTO a_emp LIMIT num_linhas;
    
    FOR i IN 1 .. a_emp.count
    loop
      IF a_emp(i).department_id != 10 THEN
        a_emp(i).salary := a_emp(i).salary * CASE WHEN a_emp(i).aval = 5
                                                  THEN 1.5
                                                  WHEN a_emp(i).aval = 4
                                                  THEN 1.3
                                                  WHEN a_emp(i).aval = 3
                                                  THEN 1.2
                                                  WHEN a_emp(i).aval = 2
                                                  THEN 1.1
                                                  ELSE 1.0
                                             END;
      ELSE
        -- TI n�o precisa de mais dinheiro
        -- remove da cole��o
        a_emp.DELETE(i);
      END IF;
    END loop;

    -- captura exce��es da constraint caso algu�m tenha o sal�rio atualizado
    -- para mais de 100k e n�o perde o processamento
    BEGIN 
      forall i IN indices OF a_emp save EXCEPTIONS
      UPDATE employees
         SET salary    = a_emp(i).salary
       WHERE ROWID     = a_emp(i).ROWID;
    exception
      WHEN others THEN
        IF sqlcode = -24381 -- exce��o do Forall
        THEN
          FOR i IN 1 .. SQL%bulk_exceptions.count
          loop
            dbms_output.put_line(SQL%bulk_exceptions(i).error_index || ': '
                              || SQL%bulk_exceptions(i).error_code);
         END loop;
      ELSE
         raise;
      END IF;
    END;
    
    exit WHEN a_emp.count < num_linhas;
    
  END loop;

  dbms_output.put_line('Tempo decorrido: ' || 
                       to_char(dbms_utility.get_time - t0) || ' hsecs');
END;
/

-- Execute e observe... viola��o de check constraint � o ORA-02290
BEGIN
  aumenta_salario_exceto_ti(1000);
END;
/
COMMIT;
