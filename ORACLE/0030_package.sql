CREATE OR REPLACE PACKAGE PKG_ETL AS
    FUNCTION GEN_MERGE(src_obj IN VARCHAR2, dst_obj IN VARCHAR2) RETURN CLOB;
    PROCEDURE EXEC_ETL(id IN NUMBER, dry_run IN BOOLEAN DEFAULT FALSE);
END PKG_ETL;
/

CREATE OR REPLACE PACKAGE BODY PKG_ETL AS
    FUNCTION GEN_MERGE(src_obj IN VARCHAR2, dst_obj IN VARCHAR2) RETURN CLOB IS
        l_on_clause CLOB;
        l_update_clause CLOB;
        l_src_insert_clause CLOB;
        l_dst_insert_clause CLOB;
    BEGIN
        SELECT
            LISTAGG(NVL2(C.CONSTRAINT_NAME, 'DST.' || A.COLUMN_NAME || ' = SRC.' || A.COLUMN_NAME, NULL), ' AND ') WITHIN GROUP (ORDER BY A.COLUMN_ID),
            LISTAGG(NVL2(C.CONSTRAINT_NAME, NULL, 'DST.' || A.COLUMN_NAME || ' = SRC.' || A.COLUMN_NAME), ', ') WITHIN GROUP (ORDER BY A.COLUMN_ID),
            LISTAGG('SRC.' || A.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY A.COLUMN_ID),
            LISTAGG('DST.' || A.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY A.COLUMN_ID)
        INTO l_on_clause, l_update_clause, l_src_insert_clause, l_dst_insert_clause
        FROM USER_TAB_COLS A
        LEFT JOIN USER_CONS_COLUMNS B ON B.TABLE_NAME = A.TABLE_NAME AND B.COLUMN_NAME = A.COLUMN_NAME
        LEFT JOIN USER_CONSTRAINTS C ON C.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND C.CONSTRAINT_TYPE = 'P'
        WHERE A.TABLE_NAME = dst_obj;

        RETURN 'MERGE INTO ' || dst_obj || ' DST ' ||
            'USING (SELECT * FROM ' || src_obj || ') SRC ' ||
            'ON (' || l_on_clause || ') ' ||
            'WHEN MATCHED THEN UPDATE SET ' || l_update_clause || ' ' ||
            'WHEN NOT MATCHED THEN INSERT (' || l_dst_insert_clause || ') VALUES (' || l_src_insert_clause || ')';
    END GEN_MERGE;

    PROCEDURE EXEC_ETL(id IN NUMBER, dry_run IN BOOLEAN DEFAULT FALSE) IS
        l_sql CLOB;
    BEGIN
        SELECT GEN_MERGE(SRC_OBJ, DST_OBJ) INTO l_sql FROM ETL_MAPPINGS WHERE ID = id;
        EXECUTE IMMEDIATE l_sql;
        IF dry_run THEN
            ROLLBACK;
        ELSE
            COMMIT;
        END IF;
    END EXEC_ETL;
END PKG_ETL;
/
