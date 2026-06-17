SELECT T350.f350_id_co,
       T350.f350_id_tipo_docto,
       T350.f350_consec_docto,
       T350.f350_fecha,	  
       T430.f461_num_docto_referencia,
f305_xml_cfd
FROM   dbo.t350_co_docto_contable AS T350
       --INNER JOIN dbo.t461_cm_docto_factura_venta AS T461  ON T350.f350_rowid = T461.f461_rowid_docto
	   INNER JOIN t461_cm_docto_factura_venta as T430 ON T350.f350_rowid = T430.f461_rowid_docto
LEFT OUTER JOIN
                  dbo.t305_co_cfd ON t350.f350_rowid = dbo.t305_co_cfd.f305_rowid_docto
     
--WHERE 
WHERE 
T350.f350_id_tipo_docto IN('N01','N02')
 AND T350.f350_consec_docto = 661