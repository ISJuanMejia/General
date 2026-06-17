SELECT top 10 * 
FROM t430_cm_pv_docto 
-- WHERE 
--     f430_id_tipo_docto = 'PV'
ORDER BY f430_rowid desc

SELECT * FROM T120_MC_ITEMS 
    INNER JOIN t121_mc_items_extensiones ON f120_rowid = f121_rowid_item
where f120_referencia = '020253132'