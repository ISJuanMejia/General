
WITH XMLNAMESPACES (
    'http://schemas.xmlsoap.org/soap/envelope/' AS soapenv,
    'http://schemas.xmlsoap.org/soap/encoding/' AS soapenc,
    'https://sandbox.coordinadora.com/agw/ws/guias/1.6/server.php' AS ser,
    'http://www.w3.org/2001/XMLSchema-instance' AS xsi,
    'http://www.w3.org/2001/XMLSchema' AS xsd
)
SELECT o.id_orden,
    (SELECT '' AS [soapenv:Header],
          (SELECT
				(SELECT 
                        'ser:Agw_typeGenerarGuiaIn' as [@xsi:type],
                        ''							as [codigo_remision],
                        ''							as [fecha],
                        12120						as [id_cliente],
                        0							as [id_remitente],
                        'AGUA BENDITA S.A.S'		as [nombre_remitente],
                        'CALLE 79 SUR 47 D - 21'	as [direccion_remitente],
                        '3138007604'				as [telefono_remitente],
                        '05631000'					as [ciudad_remitente],
                        JSON_VALUE(o.orden_obj, '$.customer.default_address.company') as [nit_destinatario],
                        '01'														  as [div_destinatario],
                        JSON_VALUE(o.orden_obj, '$.customer.default_address.name')    as [nombre_destinatario],
                        CONCAT(JSON_VALUE(o.orden_obj, '$.customer.default_address.address1'),' ',JSON_VALUE(o.orden_obj, '$.customer.default_address.address2')) as [direccion_destinatario],
                        11001000 as [ciudad_destinatario], --JSON_VALUE(o.orden_obj, '$.customer.default_address.city') AS [ciudad_destinatario],
                        REPLACE(JSON_VALUE(o.orden_obj, '$.customer.default_address.phone'),'+57','') as [telefono_destinatario],
                        34000									  as [valor_declarado],
                        1										  as [codigo_cuenta],
                        0										  as [codigo_producto],
                        1										  as [nivel_servicio],
						''										  as linea,
                        'confección - prueba de integracion'      as [contenido],
                        JSON_VALUE(o.orden_obj, '$.name')		  as [referencia],
                        'factura del erp - prueba de integracion' as [observaciones],
                        'IMPRESO'                                 as [estado],
                        (SELECT 
                           (SELECT 
                                   0  as [ubl],
                                   1  as [alto],
                                   50 as [ancho],
                                   50 as [largo],
                                   5  as [peso],
                                   1  as [unidades]
                               FOR XML PATH('item'), TYPE
                           )
                        ) as [detalle],
				'' as cuenta_contable, 
                '' as centro_costos ,
                (select 'soapenc:Array' AS [@xsi:type],
                        'ser:Agw_typeGuiaDetalleRecaudo[]' as [@soapenc:arrayType]
                         FOR XML PATH('recaudos'), TYPE),
                '' as margen_izquierdo,
                '' as margen_superior,
                '' as id_rotulo,
                '' as usuario_vmi,
                '' as formato_impresion, 
                '' as atributo1_nombre, 
                '' as atributo1_valor, 
                (select 'ns1:ArrayOfAgw_typeNotificaciones' as [@xsi:type]
                    FOR XML PATH('notificaciones'), TYPE),
                (select 'ns1:Agw_typeAtributosRetorno' as [@xsi:type]
                    FOR XML PATH('atributos_retorno'), TYPE),
                '' as nro_doc_radicados ,
                '' as nro_sobre ,
                'aguabendita.ws' as [usuario],
                '99d7b7f7281032abdc30a822ebd6851625068801db2098d41bd13f7e7f3227ae' as [clave]
                    FOR XML PATH('p'), TYPE)
            FOR XML PATH('ser:Guias_generarGuia'), TYPE
        ) AS [soapenv:Body]
    FOR XML PATH('soapenv:Envelope'), TYPE
    ) AS xml
FROM ordenes o
where o.id_estado=2 and o.intentos<3;