show pdbs;
select name, open_mode from v$pdbs;
Alter pluggable database all open;
create pluggable database PSTFAM from PIROUT file_name_convert = ('PIROUT', 'PSTFAM');
alter pluggable database PSTFAM open read write;
alter pluggable database PSTFAM;

ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER SESSION SET CONTAINER = PSTFAM;

CDB$ROOT;
SELECT NAME, PDB FROM all_services;
select * from all_users;

show tns;

alter pluggable database PSTFAM save state;

ALTER PLUGGABLE DATABASE PSTFAM CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE PSTFAM OPEN;

-- RENAME PDB
alter pluggable database PSTFAMST close immediate;
alter pluggable database PSTFAMST open restricted;
connect c##sysstm as sysdba;
alter pluggable database PSTFAMST rename global_name to PSTFAMLT;
alter pluggable database close immediate;
alter pluggable database open;
