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


-------------------------------------
-- MATERIALIZED VIEW QUERY REWRITE --
-------------------------------------

-- Executar como SYSTEM do PDB
GRANT GLOBAL QUERY REWRITE TO curso;
GRANT SELECT ON sh.sales TO curso;
GRANT SELECT ON sh.times TO curso;

-- Veja o plano de execução desta consulta
EXPLAIN PLAN FOR
 SELECT t.calendar_month_desc, sum(s.amount_sold) AS dollars
   FROM sh.sales s, sh.times t 
  WHERE s.time_id = t.time_id
  GROUP BY t.calendar_month_desc;

SELECT *
  FROM TABLE(dbms_xplan.display);

-- Criamos uma view materializada com query rewrite para esta consulta
DROP MATERIALIZED VIEW cal_month_sales_mv;
CREATE MATERIALIZED VIEW cal_month_sales_mv
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
