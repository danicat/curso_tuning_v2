/* aula09.sql: Otimizador II
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
  O objetivo desta prática é demonstrar os diferentes caminhos que o otimizador
  pode tomar ao desenhar o plano de execução para retornar o resultado de uma
  consulta.
*/

/***********/
/* CLUSTER */
/***********/

/*
  INDEXED CLUSTER
 */

drop cluster emp_dept_clu including tables;

-- size é o tamanho do bloco do cluster
create cluster emp_dept_clu(department_id number(4)) size 512; 

create index idx_emp_dept_clu on cluster emp_dept_clu;

create table emp_clu
  cluster emp_dept_clu(department_id)
  as select * from hr.employees;
  
create table dept_clu
  cluster emp_dept_clu(department_id)
  as select * from hr.departments;

explain plan for
select *
  from emp_clu
 where department_id = 30;
  
select plan_table_output
  from table(dbms_xplan.display);

explain plan for
select e.last_name, e.email
  from emp_clu  e,
       dept_clu d
 where e.department_id = d.department_id
   and d.location_id = 100;

select plan_table_output
  from table(dbms_xplan.display);
   
/*
  HASH CLUSTER
 */

drop cluster emp_dept_hash_clu including tables;

-- size = tamanho do bloco do cluster
-- hashkeys = número de chaves "distintas" na tabela de hash
create cluster emp_dept_hash_clu( department_id number(4) )
  size 8192 hashkeys 100;
  
create table emp_hash_clu
  cluster emp_dept_hash_clu(department_id)
  as select * from hr.employees;
  
create table dept_hash_clu
  cluster emp_dept_hash_clu(department_id)
  as select * from hr.departments;

explain plan for
select *
  from emp_hash_clu
 where department_id = 30;
  
select plan_table_output
  from table(dbms_xplan.display);

explain plan for
select e.last_name, e.email
  from emp_hash_clu  e,
       dept_hash_clu d
 where e.department_id = d.department_id
   and d.location_id = 100;

select plan_table_output
  from table(dbms_xplan.display);

explain plan for
select e.last_name, e.email, d.department_name
  from emp_hash_clu  e,
       dept_hash_clu d
 where e.department_id = d.department_id
   and d.department_id = 30;

select plan_table_output
  from table(dbms_xplan.display);

/*
  SORTED HASH CLUSTER
*/

create cluster call_detail_cluster ( 
   telephone_number number, 
   call_timestamp   number sort, 
   call_duration    number sort ) 
  hashkeys 10000 
  hash is telephone_number 
  size 256; 
  
create table call_detail ( 
   telephone_number     number, 
   call_timestamp       number   sort, 
   call_duration        number   sort, 
   other_info           varchar2(30) ) 
  cluster call_detail_cluster ( 
   telephone_number, call_timestamp, call_duration );
   
insert into call_detail values (6505551212, 0, 9, 'misc info');
insert into call_detail values (6505551212, 1, 17, 'misc info');
insert into call_detail values (6505551212, 2, 5, 'misc info');
insert into call_detail values (6505551212, 3, 90, 'misc info');
insert into call_detail values (6505551213, 0, 35, 'misc info');
insert into call_detail values (6505551213, 1, 6, 'misc info');
insert into call_detail values (6505551213, 2, 4, 'misc info');
insert into call_detail values (6505551213, 3, 4, 'misc info');
insert into call_detail values (6505551214, 0, 15, 'misc info');
insert into call_detail values (6505551214, 1, 20, 'misc info');
insert into call_detail values (6505551214, 2, 1, 'misc info');
insert into call_detail values (6505551214, 3, 25, 'misc info');
commit;   

select * from call_detail where telephone_number = 6505551212;

delete from call_detail;
insert into call_detail values (6505551213, 3, 4, 'misc info');
insert into call_detail values (6505551214, 0, 15, 'misc info');
insert into call_detail values (6505551212, 0, 9, 'misc info');
insert into call_detail values (6505551214, 1, 20, 'misc info');
insert into call_detail values (6505551214, 2, 1, 'misc info');
insert into call_detail values (6505551213, 1, 6, 'misc info');
insert into call_detail values (6505551213, 2, 4, 'misc info');
insert into call_detail values (6505551214, 3, 25, 'misc info');
insert into call_detail values (6505551212, 1, 17, 'misc info');
insert into call_detail values (6505551212, 2, 5, 'misc info');
insert into call_detail values (6505551212, 3, 90, 'misc info');
insert into call_detail values (6505551213, 0, 35, 'misc info');
commit;

select * from call_detail where telephone_number = 6505551212;

explain plan for
select * from call_detail where telephone_number = 6505551212;

-- Consulta ordenada sem order by!
select plan_table_output
  from table(dbms_xplan.display);

drop table call_detail_nonclustered;
create table call_detail_nonclustered as
select * from call_detail;

explain plan for
select * 
  from call_detail_nonclustered 
 where telephone_number = 6505551212 
 order by call_timestamp, call_duration;

-- Precisa do operador de ordenação
select plan_table_output
  from table(dbms_xplan.display);

/*
  SINGLE TABLE HASH CLUSTER
 */
 
drop cluster st_hash_clu including tables;

create cluster st_hash_clu( department_id number(4) )
  size 512 single table hashkeys 30;

create table dept_st_hash_clu
  cluster st_hash_clu(department_id)
  as select * from hr.departments;

explain plan for
select * 
  from dept_st_hash_clu
 where department_id = 30;
  
select plan_table_output
  from table(dbms_xplan.display);

/***************************/
/* OPERADORES DE ORDENAÇÃO */
/***************************/

/*
  IN-LIST ITERATOR
 */

explain plan for
select * 
  from hr.employees
 where department_id in (10,20);
 
select plan_table_output
  from table(dbms_xplan.display);
 
explain plan for
select * 
  from hr.employees
 where department_id = 1
    or department_id = 2;
 
select plan_table_output
  from table(dbms_xplan.display);

/*
  MIN/MAX e FIRST ROW
 */

explain plan for 
select min(employee_id)
  from hr.employees;
  
select plan_table_output
  from table(dbms_xplan.display);

explain plan for 
select max(employee_id)
  from hr.employees
 where employee_id < 100;
  
select plan_table_output
  from table(dbms_xplan.display);

/*******************/
/* MÉTODOS DE JOIN */
/*******************/

/*
  NESTED LOOPS
  
  Hint: USE_NL( t1 [t2] )
  Hint: ORDERED - força a ordem do join
  Hint Oposta: NO_USE_NL( tabela )
 */

-- sem hints
explain plan for
select e.last_name, d.department_name
  from hr.employees   e,
       hr.departments d
 where e.department_id = d.department_id
   and e.last_name like 'A%';

select plan_table_output
  from table(dbms_xplan.display);

-- com hint e forçando a ordem do join
explain plan for
select /*+ ORDERED USE_NL(e) */
       e.last_name, 
       d.department_name
  from hr.employees   e,
       hr.departments d
 where e.department_id = d.department_id
   and e.last_name like 'A%';

select plan_table_output
  from table(dbms_xplan.display);

-- Observe a ordem do JOIN!
explain plan for
select /*+ ORDERED USE_NL(e) */
       e.last_name, 
       d.department_name
  from hr.departments d,
       hr.employees   e
 where e.department_id = d.department_id
   and e.last_name like 'A%';

select plan_table_output
  from table(dbms_xplan.display);

/*
  HASH JOINS
  
  Hint: USE_HASH
  Hint Oposta: NO_USE_HASH
 */
 
explain plan for
select o.customer_id,
       oi.unit_price * oi.quantity
  from oe.orders      o,
       oe.order_items oi
 where o.order_id = oi.order_id;
 
select plan_table_output
  from table(dbms_xplan.display);

-- Com hint
explain plan for
select /*+ use_hash(o oi) no_index(o) */
       o.customer_id,
       oi.unit_price * oi.quantity
  from oe.orders      o,
       oe.order_items oi
 where o.order_id = oi.order_id;
 
select plan_table_output
  from table(dbms_xplan.display);

/*
  SORT-MERGE
  
  Hint: USE_MERGE(t1 t2)
  Hint Oposta: NO_USE_MERGE
 */
 
explain plan for
select --+ USE_MERGE(d e) NO_INDEX(d)
       e.employee_id,
       e.last_name, 
       e.first_name,
       d.department_id,
       d.department_name
  from hr.departments d,
       hr.employees   e
 where e.department_id = d.department_id
 order by department_id;

select plan_table_output
  from table(dbms_xplan.display);

/*
  CARTESIAN JOIN
  
  Hint: USE_MERGE_CARTESIAN( tabela )
  Hint Oposta: NO_CARTESIAN( tabela )
 */

explain plan for
select *
  from hr.employees   e,
       hr.departments d;
       
select plan_table_output
  from table(dbms_xplan.display);

/*****************/
/* TIPOS DE JOIN */
/*****************/

/*
  EQUIJOIN: todos os joins que testamos até agora foram equijoins!
 */
 
/*
  NONEQUIJOIN
 */

explain plan for
select e.employee_id, e.first_name, e.last_name, e.hire_date
  from hr.employees e, hr.job_history h
 where h.employee_id = 176
   and e.hire_date between h.start_date and h.end_date; 

select plan_table_output
  from table(dbms_xplan.display);
  
/*
  NESTED LOOP OUTER JOIN
 */
 
explain plan for
select /*+ USE_NL(c o) */ cust_last_name,
       sum(nvl2(o.customer_id,0,1)) "Count"
from   oe.customers c, oe.orders o
where  c.credit_limit > 1000
and    c.customer_id = o.customer_id(+)
group by cust_last_name;

select plan_table_output
  from table(dbms_xplan.display);

/*
  HASH OUTER JOIN
 */

explain plan for 
select /*+ use_hash(c o) */
       cust_last_name, sum(nvl2(o.customer_id,0,1)) "Count"
from   oe.customers c, oe.orders o
where  c.credit_limit > 1000
and    c.customer_id = o.customer_id(+)
group by cust_last_name;

select plan_table_output
  from table(dbms_xplan.display);

/*
  FULL OUTER JOIN
 */
 
-- empregados sem departamento, e;
-- departamentos sem empregado
explain plan for
select d.department_id, 
       e.employee_id
  from hr.employees e full outer join hr.departments d
    on e.department_id = d.department_id
 order by d.department_id;

select plan_table_output
  from table(dbms_xplan.display);

/*
  SEMI JOINS
 */
 
explain plan for
select /*+ full(d) */
       department_id, department_name 
from   hr.departments d
where exists (select 1
              from   hr.employees e
              where  e.department_id = d.department_id);

select plan_table_output
  from table(dbms_xplan.display);

explain plan for
select --+ FULL(d) 
       department_id, department_name
from   hr.departments d
where  department_id in 
       (select department_id 
        from   hr.employees);

select plan_table_output
  from table(dbms_xplan.display);

/*
  ANTIJOINS
  
  Hint: HASH_AJ, NL_AJ
 */

-- clientes que tem limite de crédito maior que 1000 mas não tem pedidos
explain plan for
select cust_first_name, cust_last_name
from   oe.customers c, oe.orders o
where  c.credit_limit > 1000
and    c.customer_id = o.customer_id(+)
and    o.customer_id is null;

select plan_table_output
  from table(dbms_xplan.display);

/**********************/
/* Operadores N-ários */
/**********************/

-- INTERSECT: tem em ambos
explain plan for
select product_id from oe.inventories
intersect
select product_id from oe.order_items;

select plan_table_output
  from table(dbms_xplan.display);

-- MINUS: só tem na primeira query
explain plan for
select product_id from oe.inventories
minus
select product_id from oe.order_items;

select plan_table_output
  from table(dbms_xplan.display);
  
-- UNION: soma dos dois (apenas distintos)
explain plan for
select product_id from oe.inventories
union
select product_id from oe.order_items;

select plan_table_output
  from table(dbms_xplan.display);

-- UNION ALL: soma dos dois (com repetição)
explain plan for
select location_id from hr.locations
union all
select location_id from hr.departments;

select plan_table_output
  from table(dbms_xplan.display);
