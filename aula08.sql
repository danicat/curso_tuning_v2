/* aula08.sql: Otimizador I
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
  O objetivo desta pr�tica � demonstrar os diferentes caminhos que o otimizador
  pode tomar ao desenhar o plano de execu��o para retornar o resultado de uma
  consulta.
*/

-----------
-- HINTS --
-----------

/*
  Ao longo desta pr�tica e da pr�xima iremos utilizar hints para for�ar o plano
  para o caminho que queremos demonstrar. � importante ressaltar que o plano
  que estamos for�ando com as hints n�o necessariamente s�o os melhores planos
  para cada situa��o.
  
  O objetivo desta pr�tica � mostrar os operadores em a��o para que nos
  familiarizemos com eles.
  
  Na vida real, em c�digos de produ��o, dificilmente usamos hints. S�o casos
  muito espec�ficos e geralmente s�o "solu��es" tempor�rias at� encontrarmos
  solu��es definitivas.
  
  A necessidade de usar uma hint geralmente � um sinal de que estamos deixando
  de perceber algum fator que est� influenciando o otimizador e que n�o estamos
  levando em conta na nossa an�lise.
 */

-- Relembrando a sintaxe de hints:
SELECT /*+ FULL(e) */ e.*
  FROM hr.employees e;
  
-- � equivalente a:
SELECT --+ FULL(e)
       e.*
  FROM hr.employees e;

------------------------------
-- Operadores do Otimizador --
------------------------------

/*
  Agora vamos iniciar nossos estudos sobre operadores, come�ando pelos caminhos
  de acesso (Access Paths).
 */

/***********/
/* TABELAS */
/***********/

/* 
  FULL TABLE SCAN 
  
  L� todos os blocos da tabela. Hint: FULL
 */

-- Plano sem hint
explain plan for
select *
  from hr.employees;
  
select plan_table_output
  from table(dbms_xplan.display);

-- Plano com hint
explain plan for
select /*+ full(e) */ *
  from hr.employees e
 where e.employee_id = 100;
 
select plan_table_output
  from table(dbms_xplan.display); 
  
/*
  ROWID scan: acesso direto no bloco
  
  Consequencia de um acesso via indice ou acesso direto.
 */
 
select rowid, e.*
  from hr.employees e
 fetch first 5 rows only;

-- Acesso direto 
-- [substitua a subquery por um valor acima para remover a view do plano]
explain plan for
select *
  from hr.employees e
 where rowid = (select rowid
                  from hr.employees e
                 fetch first 1 rows only);

select plan_table_output
  from table(dbms_xplan.display);

-- Acesso por �ndice
explain plan for
select *
  from hr.employees e
 where e.employee_id > 190;
 
select plan_table_output
  from table(dbms_xplan.display);
  
/*
  TABLE ACCESS SAMPLE
  
  Faz a amostragem de uma tabela.
  
  SAMPLE(pct)      : percentual de linhas
  SAMPLE BLOCK(pct): percentual de blocos
  
  SEED: semente do gerador de n�meros aleat�rios, garante reprodutibilidade
*/

drop table t8;
create table t8
as
select rownum id, rpad('*', 1000, '*') dados
  from dual connect by level <= 10000;

exec dbms_stats.gather_table_stats(user, 'T8');

select num_rows, 
       blocks, 
       ceil(num_rows / blocks) "linhas_por_bloco",
       blocks / 10             "blocks_10_pct"
  from dba_tab_statistics
 where owner      = user
   and table_name = 'T8';

-- Amostragem por percentual de linhas
select count(*)
  from T8 sample(10) seed(1);

explain plan for
select *
  from T8 sample(10) seed(1);

select plan_table_output
  from table(dbms_xplan.display);

-- Amostragem por percentual de blocos
select count(*)
  from T8 sample block(10) seed(1);

explain plan for
select *
  from T8 sample(10) seed(1);

select plan_table_output
  from table(dbms_xplan.display);

/*
  INMEMORY COLUMN STORE
  
  Depende da option IN-MEMORY DATABASE. Hints: INMEMORY e NO_INMEMORY
 */

explain plan for
select *
  from oe.product_information pi
 where pi.list_price > 10
 order by product_id;
 
select plan_table_output
  from table(dbms_xplan.display);

/*
  Configurar a in-memory option no banco de dados:
  
  Este passos precisam ser executados como usu�rio SYS do CDB.

  alter system set inmemory_size = 100M scope=spfile;
  shutdown immediate;
  startup;
*/

alter table oe.product_information inmemory;

explain plan for
select *
  from oe.product_information pi
 where pi.list_price > 10
 order by product_id;
 
select plan_table_output
  from table(dbms_xplan.display);

explain plan for
select --+ NO_INMEMORY
       pi.*
  from oe.product_information pi
 where pi.list_price > 10
 order by product_id;
 
select plan_table_output
  from table(dbms_xplan.display);


/***********/
/* �NDICES */
/***********/


/*
   INDEX UNIQUE SCAN
   
   Busca por registro �nico, predicado de igualdade. 
   
   Hint: INDEX (tabela nome-do-indice)
 */

explain plan for
select *
  from sh.products
 where prod_id = 19;
 
select plan_table_output
  from table(dbms_xplan.display);

/*
  INDEX RANGE SCAN
  
  Busca uma faixa de valores, predicado de desigualdade.

  Hint: INDEX (tabela nome-do-indice)  
*/

explain plan for
select *
  from hr.employees e
 where e.department_id = 20 and e.salary > 1000;

select plan_table_output
  from table(dbms_xplan.display);

/*
  INDEX RANGE SCAN (DESCENDING)
  
  Busca uma faixa de valores, predicado de desigualdade, ordem descendente.

  Hint: INDEX_DESC (tabela nome-do-indice)  
*/

 explain plan for
 select *
   from hr.employees e
  where e.department_id < 20
  order by department_id desc;

 select plan_table_output
  from table(dbms_xplan.display);

 explain plan for
 select *
   from hr.employees e
  where e.department_id > 100 -- <-- nota: n�o � o predicado, � o order by
                              --           que sugere o descending
  order by department_id desc;

 select plan_table_output
  from table(dbms_xplan.display);

/*
  DESCENDING INDEX RANGE SCAN
  
  Busca uma faixa de valores, predicado de desigualdade, ordem descendente COM
  �NDICE criado em ordem descendente.

  Hint: INDEX (tabela nome-do-indice)  
*/

-- Cria indice descendente
create index idx_emp_desc on hr.employees(department_id desc);

explain plan for
select *
  from hr.employees
 where department_id < 30
  order by department_id desc;

/*
  Observe os operadores SYS_OP_DESCEND e SYS_OP_UNDESCEND no predicado
  
  �ndices descendentes s�o tratados como �ndices baseados em fun��o, utilizando
  fun��es internas de revers�o de ordem.
*/
select plan_table_output
  from table(dbms_xplan.display);
  
/*
  INDEX RANGE SCAN FUNCTION BASED
  
  Predicado tem uma fun��o e existe �ndice na fun��o.
 */
 
select last_name 
  from hr.employees;
 
drop index idx_emp_sobrenome_ibf;
create index idx_emp_sobrenome_ibf on hr.employees(UPPER(last_name));

explain plan for
select * 
  from hr.employees e
 where upper(e.last_name) like 'A%';

select plan_table_output
  from table(dbms_xplan.display);

/*
  INDEX FULL SCAN
  
  Quando a consulta demanda um resultado ordenado, mas precisa da tabela
  inteira.
 */

explain plan for
select department_id, department_name
  from hr.departments
 order by department_id;
 
select plan_table_output
  from table(dbms_xplan.display); 
  
/*
  INDEX FAST FULL SCAN
  
  Quando a consulta acessa apenas atributos que est�o no �ndice.
  
  Hint: INDEX_FFS
 */

explain plan for
 select /*+ index_ffs(d dept_id_pk) */ count(*)
   from hr.departments d;

 select plan_table_output
   from table(dbms_xplan.display); 

/*
  INDEX SKIP SCAN
  
  Quando a consulta acessa apenas *alguns* atributos que est�o no �ndice.
  
  Hint: INDEX_SS
 */

drop index idx_cust_gender_email;
create index idx_cust_gender_email on sh.customers(cust_gender, cust_email);

explain plan for
select *
  from sh.customers
 where cust_email = 'Abbey@company.example.com';
 
select plan_table_output
   from table(dbms_xplan.display); 

/*
  INDEX JOIN SCAN
  
  Quando a consulta acessa apenas *alguns* atributos que est�o no �ndice.
  
  Hint: INDEX_JOIN (tabela)
 */

explain plan for
 select /*+ INDEX_JOIN(e) */ last_name, email
   from hr.employees e
  where last_name like 'A%';
  
select plan_table_output
  from table(dbms_xplan.display);  
  
  
/*
  IOTs: Tabelas organizadas por �ndice
 */
 
create table iot_employees (
 employee_id primary key,
 first_name,
 last_name,
 email,
 phone_number,
 hire_date,
 job_id,
 salary,
 commission_pct,
 manager_id,
 department_id
)
organization index
as
select * from hr.employees;

explain plan for
select *
  from iot_employees
 where employee_id = 100;

select plan_table_output
  from table(dbms_xplan.display);  

explain plan for
select *
  from iot_employees;

select plan_table_output
  from table(dbms_xplan.display);  

explain plan for
select *
  from iot_employees
 where department_id = 100;

select plan_table_output
  from table(dbms_xplan.display);  

explain plan for
select *
  from iot_employees
 where employee_id < 110;

select plan_table_output
  from table(dbms_xplan.display);  

select rowid, e.*
  from iot_employees e;
  
  
/*
  �NDICES BITMAP
 */
 
select *
  from all_indexes
 where owner = 'SH'
   and table_name = 'CUSTOMERS'
   and index_type = 'BITMAP';

/*
  BITMAP INDEX SINGLE VALUE
 */

explain plan for
select /*+ index(c customers_gender_bix) */ *
  from sh.customers c
 where cust_gender = 'F';

select plan_table_output
  from table(dbms_xplan.display);  

/*
  BITMAP INDEX RANGE SCAN
 */

explain plan for
select /*+ index(c customers_yob_bix) */ *
  from sh.customers c
 where cust_year_of_birth > 80;

select plan_table_output
  from table(dbms_xplan.display);  
  
/*
  INLIST ITERATOR BITMAP INDEX SINGLE VALUE
 */
explain plan for
select /*+ index(c customers_yob_bix) */ *
  from sh.customers c
 where cust_year_of_birth in (80,81);

select plan_table_output
  from table(dbms_xplan.display);  

/*
  BITMAP AND
 */
explain plan for
select /*+ index(c customers_gender_bix) */ *
  from sh.customers c
 where cust_year_of_birth = 80
   and cust_gender        = 'F';

select plan_table_output
  from table(dbms_xplan.display);  

/*
  BITMAP JOIN INDEX
*/

drop index emp_dept_loc;
create bitmap index emp_dept_loc 
on hr.employees(d.location_id)
from hr.employees e, hr.departments d
where e.department_id = d.department_id;

explain plan for
select /*+ index(e emp_dept_loc ) */ e.*
  from hr.employees   e,
       hr.departments d
 where e.department_id = d.department_id
   and d.location_id = 100;

select plan_table_output
  from table(dbms_xplan.display);  