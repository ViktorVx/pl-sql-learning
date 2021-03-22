DECLARE
    TYPE refCur IS REF CURSOR;
    cur refCur;
    type t_tab is table of PROFILE_PARAMS_C%rowtype;
    tab t_tab;
    rows_count NUMBER:= 50000;

    PROCEDURE migrateSector(new_sector VARCHAR2) IS
            rc NUMBER;
            new_sector_like VARCHAR2(32);
        BEGIN
            new_sector_like:=new_sector || '.%';
            ----------------------------
            EXECUTE IMMEDIATE '
                SELECT COUNT(*) FROM PROFILE_PARAMS_C pp WHERE NOT EXISTS
                    (SELECT NULL FROM SHARDING_PARAMS sp
                     WHERE sp.SHARDING_PARAM_ID = (pp.ACC || ''|'' || pp.COMPONENT_ID || ''|'' || :new_sector || ''|'' || pp.PARAMETER_TYPE_ID || ''|1''))
                     AND (pp.COMPONENT_ID = :new_sector  OR pp.COMPONENT_ID LIKE :new_sector_like)
            ' INTO rc USING new_sector, new_sector, new_sector_like;
            DBMS_OUTPUT.PUT_LINE('Starts migration for sector ' || new_sector || ' for ' || rc || ' rows');
            ----------------------------
            OPEN cur FOR '
                 SELECT * FROM PROFILE_PARAMS_C pp WHERE NOT EXISTS
                    (SELECT NULL FROM SHARDING_PARAMS sp
                     WHERE sp.SHARDING_PARAM_ID = (pp.ACC || ''|'' || pp.COMPONENT_ID || ''|'' || :new_sector || ''|'' || pp.PARAMETER_TYPE_ID || ''|1''))
                     AND (pp.COMPONENT_ID = :new_sector OR pp.COMPONENT_ID LIKE :new_sector_like)
            ' USING new_sector, new_sector, new_sector_like;
            BEGIN
                LOOP FETCH cur BULK COLLECT INTO tab LIMIT rows_count;
                EXIT WHEN tab.COUNT = 0;
                    FORALL i IN tab.FIRST..tab.LAST
                        INSERT INTO SHARDING_PARAMS (SHARDING_PARAM_ID,
                                                         PARAMETER_TYPE_ID,
                                                         SHARDING_PARAM_VALUE,
                                                         MODIFIED_DATE,
                                                         SECTOR_ID,
                                                         ACC,
                                                         DEPARTMENT,
                                                         COMPONENT_ID,
                                                         CHANGE_VERSION,
                                                         CREATION_DATE,
                                                         LOCKED_FLAG,
                                                         NEED_REPLICATION)
                        VALUES (tab(i).ACC || '|' || tab(i).COMPONENT_ID || '|' || new_sector || '|' || tab(i).PARAMETER_TYPE_ID || '|1',
                                tab(i).PARAMETER_TYPE_ID,
                                tab(i).PROF_PARAM_VALUE,
                                SYSTIMESTAMP,
                                new_sector,
                                tab(i).ACC,
                                tab(i).DEPARTMENT,
                                tab(i).COMPONENT_ID,
                                '1',
                                SYSTIMESTAMP,
                                'N',
                                'N');
                        COMMIT;
                        DBMS_OUTPUT.PUT_LINE('Complete ' || tab.COUNT || ' rows');
                    END LOOP;
                END;
                CLOSE cur;
                DBMS_OUTPUT.PUT_LINE(new_sector || ' complete');
            END;
BEGIN
    DBMS_OUTPUT.ENABLE (buffer_size => NULL);
    migrateSector('s.data');
    migrateSector('s.fin');
    DBMS_OUTPUT.PUT_LINE('Migration complete');
END;
