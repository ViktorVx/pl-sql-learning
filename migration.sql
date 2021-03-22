-- liquibase formatted sql

/*** Migrate data from version 20.1 to 20.2 ***/
-- changeset petrov7-va:MIGRATION_20_1_TO_20_2#0001 dbms:oracle logicalFilePath:path-independent runOnChange:true splitStatements:true endDelimiter:/
DECLARE
    united_operations_exists NUMBER:=0;
    catalog_tenant_links_exists NUMBER:=0;
    united_operations_tenant_links_exists NUMBER:=0;
    pilot_groups_exists NUMBER:=0;
    process_id_val VARCHAR2(64 BYTE):= SYS_GUID();
    process_name_val VARCHAR2(256 BYTE):= 'Data migration 20.1 -> 20.2';
    v_code NUMBER;
    v_errm VARCHAR2(256);

    PROCEDURE logMessage(level_val VARCHAR2, msg VARCHAR2) AS
        PRAGMA autonomous_transaction;
    BEGIN
        INSERT INTO ${schema}.LOG(PROCESS_ID, PROCESS_NAME, LOG_LEVEL_VALUE, MESSAGE_VALUE)
        VALUES (process_id_val, process_name_val, level_val, msg);
        COMMIT;
    END;

    PROCEDURE migrateOperations AS
        CURSOR operations_cur IS SELECT *
                                 FROM ${schema}.OPERATION;
        operation_record ${schema}.OPERATION%ROWTYPE;
        new_oper_name    ${schema}.UNITED_OPERATION.OPERATION_NAME%TYPE;
        exists_uo        NUMBER := 0;
        duplicates_names NUMBER;

        PROCEDURE logMessage(level_val VARCHAR2, msg VARCHAR2) AS
            PRAGMA autonomous_transaction;
        BEGIN
            INSERT INTO ${schema}.LOG(PROCESS_ID, PROCESS_NAME, LOG_LEVEL_VALUE, MESSAGE_VALUE)
            VALUES (process_id_val, process_name_val, level_val, msg);
            COMMIT;
        END;

    BEGIN
        OPEN operations_cur;
        LOOP
            FETCH operations_cur INTO operation_record;
            EXIT WHEN operations_cur%NOTFOUND;
            logMessage('INFO', 'Migrate operation with id: ' || operation_record.ENTITY_ID);

            SELECT count(*) INTO duplicates_names FROM ${schema}.OPERATION op WHERE op.NAME = operation_record.NAME;
            IF duplicates_names = 1 THEN
                new_oper_name := operation_record.NAME;
            ELSE
                new_oper_name := operation_record.NAME || '_' || operation_record.ENTITY_ID;
            END IF;

            SELECT count(*) INTO exists_uo FROM ${schema}.UNITED_OPERATION uo WHERE uo.OPERATION_NAME = new_oper_name;
            IF exists_uo = 0 THEN
                INSERT INTO ${schema}.UNITED_OPERATION(OPERATION_NAME, CHANNEL_NAME, OPERATION_PERMISSION, OPERATION_SUBSYSTEM,
                                                OPERATION_TITLE, SUB_SYSTEM_TYPE, SHORT_TITLE, AVAILABLE_IN_SI)
                VALUES (new_oper_name,
                        operation_record.CHANNEL_NAME,
                        operation_record.PERMISSION,
                        operation_record.SUBSYSTEM,
                        operation_record.TITLE,
                        NVL(operation_record.SUB_SYSTEM_TYPE, 'INTERNAL'),
                        operation_record.SHORT_TITLE,
                        operation_record.IS_AVAILABLE_IN_STANDIN);
                INSERT INTO ${schema}.OPERATION_VERSION(VERSION_ID, OPERATION_NAME, CATALOG_ID, VERSION_VALUE, RESOURCE_URL,
                                                 WEIGHT, BACKGROUND, KEY_WORDS, KEY_WORD_SYNONYMS, BLOCKED_FLAG,
                                                 BLOCKED_MESSAGE, PILOT_FLAG, SUP_PARAM_ID, MODIFIED_DATE, ROW_VERSION,
                                                 LOCKED_FLAG, NEED_REPLICATION)
                VALUES (rawtohex(standard_hash(new_oper_name || '|01.00', 'MD5')),
                        new_oper_name, operation_record.CATALOG_ID, '01.00', operation_record.URL,
                        operation_record.WEIGHT,
                        operation_record.BACKGROUND, operation_record.KEY_WORDS, operation_record.KEY_WORD_SYNONYMS,
                        operation_record.IS_BLOCKED, operation_record.BLOCKED_MESSAGE, operation_record.IS_PILOT_ZONE,
                        operation_record.SUP_PARAM_ID, operation_record.MODIFIED_DATE, operation_record.ROW_VERSION,
                        operation_record.LOCKED_FLAG, operation_record.NEED_REPLICATION);
            END IF;
        END LOOP;
    END;

BEGIN
    DBMS_OUTPUT.ENABLE(buffer_size => NULL);
    -- Проверяем, что миграция еще не выполнялась
    SELECT count(*) INTO united_operations_exists FROM ${schema}.UNITED_OPERATION;
    SELECT count(*) INTO catalog_tenant_links_exists FROM ${schema}.CATALOG_TENANT;
    SELECT count(*) INTO united_operations_tenant_links_exists FROM ${schema}.UNITED_OPERATION_TENANT;
    SELECT count(*) INTO pilot_groups_exists FROM ${schema}.PILOT_GROUP;
    IF (united_operations_exists = 0 AND united_operations_tenant_links_exists = 0 AND
        catalog_tenant_links_exists = 0 AND pilot_groups_exists = 0) THEN
        ---------------------
        DBMS_OUTPUT.PUT_LINE('Operations migration started');
        logMessage('INFO', 'Operations migration started');
        migrateOperations();
        DBMS_OUTPUT.PUT_LINE('Operations migration complete');
        logMessage('INFO', 'Operations migration complete');
        COMMIT;
    ELSE
        logMessage('WARN', 'Новые таблицы 20.2 уже заполнены данными. Миграция не осуществлена');
    END IF;
    -- Перехватываем исключения
    EXCEPTION
        WHEN OTHERS THEN
            v_code := SQLCODE;
            v_errm := SUBSTR(SQLERRM, 1 , 450);
            logMessage('ERROR', 'Error code ' || v_code || ': ' || v_errm);
            raise_application_error(SQLCODE, SQLERRM);
END ;
/

