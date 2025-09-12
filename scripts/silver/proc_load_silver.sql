/*
=============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
=============================================================================
Script Purpose:
  This stored procedure performs the ETL (Extract, Transform, Load) process to 
  populate the 'silver' schema tables from the 'bronze' schema.
  It performs the following actions:
    - Truncates the silver tables.
    - Inserts transformed and cleaned data from bronze to silver tables.

Parameters:
  None.
  This stored procedure does not accept any parameters or return any values.

Usage Example:
  EXEC silver.load_silver;
=============================================================================
*/
CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '======================================================';
		PRINT 'Loading Silver Layer';
		PRINT '======================================================';

		PRINT '------------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '------------------------------------------------------';


-- LOADING silver.crm_cust_info
SET @start_time = GETDATE();
PRINT'>> Truncating Table: silver.crm_cust_info';
TRUNCATE TABLE silver.crm_cust_info;
PRINT 'Inserting Data Into: silver.crm_cust_info' ;

INSERT INTO silver.crm_cust_info (
	cst_id,
	cst_key,
	cst_firstname,
	cst_lastname,
	cst_material_status,
	cst_gndr,
	cst_create_date) 

SELECT
cst_id,
cst_key,
TRIM(cst_firstname) AS cst_firstname,
TRIM(cst_lastname) AS cst_lastname,
CASE WHEN UPPER(TRIM(cst_material_status)) = 'S' THEN 'Single'
	WHEN UPPER(TRIM(cst_material_status)) = 'M' THEN 'Married'
	ELSE 'n/a'
END
cst_material_status,
CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
	WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
	ELSE 'n/a'
END
cst_gndr,
cst_create_date
FROM(
SELECT 
*,
ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last
FROM bronze.crm_cust_info
WHERE cst_id IS NOT NULL
)t WHERE flag_last = 1;
SET @end_time = GETDATE();
		PRINT '>> Load Duration:' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + 'seconds';
		PRINT '--------------------------------------------------';

-- LOADING silver.erp_cust_az12
SET @start_time = GETDATE();
PRINT'>> Truncating Table: silver.erp_cust_az12';
TRUNCATE TABLE silver.erp_cust_az12;
PRINT 'Inserting Data Into: silver.erp_cust_az12' ;
INSERT INTO silver.erp_cust_az12 (cid,bdate,gen)

SELECT
CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4, LEN(cid))
	ELSE cid
END AS cid,
CASE WHEN bdate > GETDATE() THEN NULL
	ELSE bdate
END as bdate,
CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
	WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
	ELSE 'n/a'
END AS gen
FROM bronze.erp_cust_az12;
SET @end_time = GETDATE();
		PRINT '>> Load Duration:' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + 'seconds';
		PRINT '--------------------------------------------------';

-- LOADING silver.erp_loc_a101
SET @start_time = GETDATE();
PRINT'>> Truncating Table: silver.erp_loc_a101';
TRUNCATE TABLE silver.erp_loc_a101;
PRINT 'Inserting Data Into: silver.erp_loc_a101' ;
INSERT INTO silver.erp_loc_a101 (cid,cntry)

SELECT 
REPLACE(cid,'-','') cid,
CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
	WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
	WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
	ELSE TRIM(cntry)
END AS cntry
FROM bronze.erp_loc_a101;
SET @end_time = GETDATE();
		PRINT '>> Load Duration:' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + 'seconds';
		PRINT '--------------------------------------------------';

-- LOADING silver.erp_px_cat_g1v2
SET @start_time = GETDATE();
PRINT'>> Truncating Table: silver.erp_px_cat_g1v2';
TRUNCATE TABLE silver.erp_px_cat_g1v2;
PRINT 'Inserting Data Into: silver.erp_px_cat_g1v2' ;
INSERT INTO silver.erp_px_cat_g1v2 (id,cat,subcat,maintenance)
SELECT 
id,
cat,
subcat,
maintenance
FROM bronze.erp_px_cat_g1v2;
SET @end_time = GETDATE();
		PRINT '>> Load Duration:' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + 'seconds';
		PRINT '--------------------------------------------------';

		SET @batch_end_time = GETDATE();
		PRINT '==============================================';
		PRINT 'Loading Silver Layer is Completed';
		PRINT '- Total Load Duration:' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + 'seconds';
		PRINT '==============================================';

END TRY

BEGIN CATCH
PRINT '==============================================';
		PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER';
		PRINT 'ERROR MESSAGE' + ERROR_MESSAGE();
		PRINT 'ERROR MESSAGE' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'ERROR MESSAGE' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '==============================================';
	END CATCH
END
