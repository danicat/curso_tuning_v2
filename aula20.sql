/* aula20.sql: Parallel Queries
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

SHOW PARAMETER PARALLEL

SELECT *
  FROM SH.SALES;
  
EXPLAIN PLAN FOR
SELECT *
  FROM SH.SALES;
  
SELECT *
  FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Os dois comandos são equivalentes:
ALTER TABLE SH.SALES PARALLEL;
ALTER TABLE SH.SALES PARALLEL(DEGREE DEFAULT);

-- Para desativar
ALTER TABLE SH.SALES NOPARALLEL;

EXPLAIN PLAN FOR
SELECT *
  FROM SH.SALES;
  
SELECT *
  FROM TABLE(DBMS_XPLAN.DISPLAY);

SELECT COUNT(*)
  FROM SH.SALES;
  
DROP TABLE T;

ALTER TABLE SH.SALES NOPARALLEL;

EXPLAIN PLAN FOR
CREATE TABLE T AS
SELECT *
  FROM SH.SALES, (SELECT 1 FROM DUAL CONNECT BY LEVEL <= 100);

SELECT *
  FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Tempo estimado 70s
CREATE TABLE T AS
SELECT *
  FROM SH.SALES, (SELECT 1 FROM DUAL CONNECT BY LEVEL <= 100);

/*
UPDATE (SELECT SNAME, PNAME, PVAL1 FROM sys.aux_stats$)
   SET PVAL1 = 14
 WHERE PNAME = 'MBRC';
COMMIT;
*/

DROP TABLE U;

ALTER TABLE SH.SALES PARALLEL;

EXPLAIN PLAN FOR  
CREATE TABLE U AS
SELECT *
  FROM SH.SALES, (SELECT 1 FROM DUAL CONNECT BY LEVEL <= 100);

SELECT *
  FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Tempo estimado: 80s
CREATE TABLE U AS
SELECT *
  FROM SH.SALES, (SELECT 1 FROM DUAL CONNECT BY LEVEL <= 100);
