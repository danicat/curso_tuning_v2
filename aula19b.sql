rem
rem     Script:         12c_inmemory_surprise.sql
rem     Author:         Jonathan Lewis
rem     Dated:          July 2016
rem
rem     Last tested
rem             12.1.0.2
rem
 
drop table t2 purge;
drop table t1 purge;
 
create table t1
nologging
as
with generator as (
        select  --+ materialize
                rownum id
        from dual
        connect by
                level <= 1e4
)
select
        rownum                                          id,
        trunc((rownum - 1)/100)                         n1,
        trunc((rownum - 1)/100)                         n2,
        trunc(dbms_random.value(1,1e4))                 rand,
        cast(lpad(rownum,10,'0') as varchar2(10))       v1,
        cast(lpad('x',100,'x') as varchar2(100))        padding
from
        generator       v1
;
 
create table t2
nologging
as
with generator as (
        select  --+ materialize
                rownum id
        from dual
        connect by
                level <= 1e4
)
select
        rownum                                          id,
        trunc((rownum - 1)/100)                         n1,
        trunc((rownum - 1)/100)                         n2,
        trunc(dbms_random.value(1,1e4))                 rand,
        cast(lpad(rownum,10,'0') as varchar2(10))       v1,
        cast(lpad('x',100,'x') as varchar2(100))        padding
from
        generator       v1,
        generator       v2
where
        rownum <= 1e6
;

create index t1_n1   on t1(n1)   nologging;
create index t2_rand on t2(rand) nologging;
 
begin
        dbms_stats.gather_table_stats(
                ownname          => user,
                tabname          =>'T1',
                method_opt       => 'for columns (n1,n2) size 1'
        );
end;
/

select
        /*+
                qb_name(main)
        */
        count(*)
from    (
        select
                /*+ qb_name(inline) */
                distinct t1.v1, t2.v1
        from
                t1,t2
        where
                t1.n1 = 50
        and     t1.n2 = 50
        and     t2.rand = t1.id
        )
;
 
select * from table(dbms_xplan.display_cursor);

alter table t2 inmemory;

select * 
  from V$IM_USER_SEGMENTS;


select
        /*+
                qb_name(main)
        */
        count(*)
from    (
        select
                /*+ qb_name(inline) */
                distinct t1.v1, t2.v1
        from
                t1,t2
        where
                t1.n1 = 50
        and     t1.n2 = 50
        and     t2.rand = t1.id
        )
;

select * from table(dbms_xplan.display_cursor);

-- Fonte: https://jonathanlewis.wordpress.com/2016/10/10/inmemory-surprise/