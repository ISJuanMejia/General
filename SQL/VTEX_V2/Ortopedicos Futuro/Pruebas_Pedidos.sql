SELECT TOP (1000) [f215_ts]
      ,[f215_rowid]
      ,[f215_rowid_tercero]
      ,[f215_id_sucursal]
      ,[f215_id]
      ,[f215_id_cia]
      ,[f215_descripcion]
      ,[f215_rowid_contacto]
      ,[f215_id_vendedor]
      ,[f215_codigo_ean]
      ,[f215_id_parametro_edi]
      ,[f215_ind_estado]
      ,[f215_id_criterio_mayor_cli]
      ,[f215_vlr_pedido_minimo]
      ,[f215_id_portafolio_edi]
      ,[f215_frecuencia_entrega]
      ,[f215_rowid_movto_entidad]
      ,[f215_ind_gum_unificado]
  FROM [UnoEE_PruebasProyectosCol].[dbo].[t215_mm_puntos_envio_cliente]
  WHERE 
    f215_rowid_tercero = 39406

SELECT * FROM t015_mm_contactos WHERE f015_rowid >= 576690

  select * from T200_MM_TERCEROS WHERE f200_id = '63369444'


  select *

--   UPDATE  
  FROM
  [Integracion-Vtex-Estandar-Ortopedicos].dbo.ordenes /*
  SET id_estado = 1, endpoint = null
  , orden_obj_origen = '{
  "orderId": "1633800577546-01",
  "sequence": "577546",
  "marketplaceOrderId": "",
  "marketplaceServicesEndpoint": "http://oms.vtexinternal.com.br/api/oms?an=ortopedicosfuturoco",
  "sellerOrderId": "00-1633800577546-01",
  "origin": "Marketplace",
  "affiliateId": "",
  "salesChannel": "1",
  "merchantName": null,
  "status": "ready-for-handling",
  "workflowIsInError": false,
  "statusDescription": "Pronto para o manuseio",
  "value": 5482000,
  "creationDate": "2026-05-21T15:17:37.4461275-05:00",
  "lastChange": "2026-05-21T15:19:03.8929788-05:00",
  "orderGroup": "1633800577546",
  "followUpEmail": "eb4d0ee2b8ff409c95f97939d5002d85@ct.vtex.com.br",
  "lastMessage": null,
  "hostname": "ortopedicosfuturoco",
  "isCompleted": true,
  "roundingError": 0,
  "orderFormId": "b326593dc0dd49c5822879bc31e7c2af",
  "allowCancellation": true,
  "allowEdition": false,
  "isCheckedIn": false,
  "authorizedDate": "2026-05-21T15:18:58-05:00",
  "invoicedDate": null,
  "cancelReason": null,
  "checkedInPickupPointId": null,
  "totals": [
    {
      "id": "Items",
      "name": "Total de los items",
      "value": 5265000
    },
    {
      "id": "Discounts",
      "name": "Total de descuentos",
      "value": -783000
    },
    {
      "id": "Shipping",
      "name": "Costo total del envío",
      "value": 1000000
    },
    {
      "id": "Tax",
      "name": "Costo total del cambio",
      "value": 0
    }
  ],
  "sellers": [
    {
      "id": "1",
      "name": "ESSITY Ortopédicos Futuro",
      "logo": "",
      "fulfillmentEndpoint": "http://fulfillment.vtexcommerce.com.br/api/fulfillment?an=ortopedicosfuturoco"
    }
  ],
  "clientPreferencesData": {
    "locale": "es-CO",
    "optinNewsLetter": true
  },
  "cancellationData": null,
  "taxData": null,
  "subscriptionData": null,
  "itemMetadata": {
    "Items": [
      {
        "Id": "6123",
        "Seller": "1",
        "Name": "Bolsa Bambu",
        "SkuName": "Bolsa Bambu",
        "ProductId": "5508",
        "RefId": "99999991",
        "Ean": "7707066001509",
        "ImageUrl": "https://ortopedicosfuturoco.vteximg.com.br/arquivos/ids/173266-55-55/Bolsa-OF.png?v=638935412187100000",
        "DetailUrl": "/bolsa-bambu/p",
        "AssemblyOptions": []
      },
      {
        "Id": "1902",
        "Seller": "1",
        "Name": "Clx Theraband Red Mediu",
        "SkuName": "Clx Theraband Red Mediu",
        "ProductId": "1294",
        "RefId": "22402672",
        "Ean": "087453127720",
        "ImageUrl": "https://ortopedicosfuturoco.vteximg.com.br/arquivos/ids/173036-55-55/Clx-Theraband-Red-Medium-22402672-1.jpg.jpg?v=638817972727400000",
        "DetailUrl": "/clx-theraband-red-mediu-22402672/p",
        "AssemblyOptions": []
      }
    ]
  },
  "marketplace": {
    "baseURL": "http://oms.vtexinternal.com.br/api/oms?an=ortopedicosfuturoco",
    "isCertified": null,
    "name": "ortopedicosfuturoco"
  },
  "storePreferencesData": {
    "countryCode": "COL",
    "currencyCode": "COP",
    "currencyFormatInfo": {
      "CurrencyDecimalDigits": 2,
      "CurrencyDecimalSeparator": ",",
      "CurrencyGroupSeparator": ".",
      "CurrencyGroupSize": 3,
      "StartsWithCurrencySymbol": true
    },
    "currencyLocale": 9226,
    "currencySymbol": "$",
    "timeZone": "SA Pacific Standard Time"
  },
  "customData": {
    "customApps": [
      {
        "fields": {
          "session_id": "1779394281",
          "client_id": "336208786.1743600247"
        },
        "id": "ids",
        "major": 1
      }
    ],
    "customFields": []
  },
  "commercialConditionData": null,
  "openTextField": null,
  "invoiceData": null,
  "changesAttachment": null,
  "callCenterOperatorData": null,
  "packageAttachment": {
    "packages": []
  },
  "paymentData": {
    "transactions": [
      {
        "isActive": true,
        "transactionId": "9974A3EDBCC34C6ABC6918B15F26553B",
        "merchantName": "ORTOPEDICOSFUTUROCO",
        "payments": [
          {
            "id": "01F0809879CA4347BE4EE6F1A20964A1",
            "paymentSystem": "701",
            "paymentSystemName": "PSE",
            "value": 5482000,
            "installments": 1,
            "referenceValue": 5482000,
            "cardHolder": null,
            "cardNumber": null,
            "firstDigits": null,
            "lastDigits": null,
            "cvv2": null,
            "expireMonth": null,
            "expireYear": null,
            "url": null,
            "giftCardId": null,
            "giftCardName": null,
            "giftCardCaption": null,
            "redemptionCode": null,
            "group": "PSE",
            "tid": "326545953",
            "dueDate": null,
            "connectorResponses": {
              "ReturnCode": null,
              "acquirer": "PayULatam",
              "Message": null,
              "Tid": "326545953",
              "nsu": "4619281760"
            },
            "giftCardProvider": null,
            "giftCardAsDiscount": null,
            "koinUrl": null,
            "accountId": null,
            "parentAccountId": null,
            "bankIssuedInvoiceIdentificationNumber": null,
            "bankIssuedInvoiceIdentificationNumberFormatted": null,
            "bankIssuedInvoiceBarCodeNumber": null,
            "bankIssuedInvoiceBarCodeType": null,
            "billingAddress": null,
            "paymentOrigin": null
          }
        ]
      }
    ],
    "giftCards": []
  },
  "shippingData": {
    "id": "shippingData",
    "address": {
      "addressType": "residential",
      "receiverName": "SANDRA PATRICIA ROMERO",
      "addressId": "10676367631476",
      "versionId": null,
      "entityId": null,
      "postalCode": "05002",
      "city": "Medellín",
      "state": "Antioquia",
      "country": "COL",
      "street": "Calle 123",
      "number": null,
      "neighborhood": "San Martin",
      "complement": null,
      "reference": null,
      "geoCoordinates": [
        -74.07209014892578,
        4.710988521575928
      ]
    },
    "logisticsInfo": [
      {
        "itemIndex": 0,
        "itemId": "1902",
        "selectedSla": "Envío Estandar",
        "selectedDeliveryChannel": "delivery",
        "lockTTL": "12d",
        "price": 929600,
        "listPrice": 929600,
        "sellingPrice": 929600,
        "deliveryWindow": null,
        "deliveryCompany": "NACIONAL ESTANDAR",
        "shippingEstimate": "3bd",
        "shippingEstimateDate": "2026-05-26T15:18:58.5581531-05:00",
        "slas": [
          {
            "id": "Envío Estandar",
            "name": "Envío Estandar",
            "shippingEstimate": "3bd",
            "deliveryWindow": null,
            "availableDeliveryWindows": [],
            "price": 929600,
            "listPrice": 929600,
            "deliveryChannel": "delivery",
            "pickupStoreInfo": {
              "additionalInfo": null,
              "address": null,
              "dockId": null,
              "friendlyName": null,
              "isPickupStore": false
            },
            "polygonName": "",
            "lockTTL": "12d",
            "pickupPointId": null,
            "transitTime": "3bd",
            "pickupDistance": 0,
            "deliveryIds": [
              {
                "courierId": "NALEST",
                "courierName": "NACIONAL ESTANDAR",
                "dockId": "NALEST",
                "quantity": 1,
                "warehouseId": "126",
                "accountCarrierName": "ortopedicosfuturoco",
                "kitItemDetails": []
              }
            ],
            "shippingEstimateDate": "2026-05-26T15:18:58.5581531-05:00"
          },
          {
            "id": "Envío Express",
            "name": "Envío Express",
            "shippingEstimate": "1bd",
            "deliveryWindow": null,
            "availableDeliveryWindows": [],
            "price": 1859200,
            "listPrice": 1859200,
            "deliveryChannel": "delivery",
            "pickupStoreInfo": {
              "additionalInfo": null,
              "address": null,
              "dockId": null,
              "friendlyName": null,
              "isPickupStore": false
            },
            "polygonName": "",
            "lockTTL": "12d",
            "pickupPointId": null,
            "transitTime": "1bd",
            "pickupDistance": 0,
            "deliveryIds": [
              {
                "courierId": "BOGEXP",
                "courierName": "EXPRESS BOGOTA",
                "dockId": "NALEST",
                "quantity": 1,
                "warehouseId": "126",
                "accountCarrierName": "ortopedicosfuturoco",
                "kitItemDetails": []
              }
            ],
            "shippingEstimateDate": "2026-05-22T15:16:00-05:00"
          }
        ],
        "shipsTo": [
          "COL"
        ],
        "deliveryIds": [
          {
            "courierId": "NALEST",
            "courierName": "NACIONAL ESTANDAR",
            "dockId": "NALEST",
            "quantity": 1,
            "warehouseId": "126",
            "accountCarrierName": "ortopedicosfuturoco",
            "kitItemDetails": []
          }
        ],
        "deliveryChannels": [
          {
            "id": "delivery",
            "stockBalance": 0
          }
        ],
        "deliveryChannel": "delivery",
        "pickupStoreInfo": {
          "additionalInfo": null,
          "address": null,
          "dockId": null,
          "friendlyName": null,
          "isPickupStore": false
        },
        "addressId": "10676367631476",
        "versionId": null,
        "entityId": null,
        "polygonName": "",
        "pickupPointId": null,
        "transitTime": "3bd"
      },
      {
        "itemIndex": 1,
        "itemId": "6123",
        "selectedSla": "Envío Estandar",
        "selectedDeliveryChannel": "delivery",
        "lockTTL": "12d",
        "price": 70400,
        "listPrice": 70400,
        "sellingPrice": 70400,
        "deliveryWindow": null,
        "deliveryCompany": "NACIONAL ESTANDAR",
        "shippingEstimate": "3bd",
        "shippingEstimateDate": "2026-05-26T15:18:58.5581802-05:00",
        "slas": [
          {
            "id": "Envío Estandar",
            "name": "Envío Estandar",
            "shippingEstimate": "3bd",
            "deliveryWindow": null,
            "availableDeliveryWindows": [],
            "price": 70400,
            "listPrice": 70400,
            "deliveryChannel": "delivery",
            "pickupStoreInfo": {
              "additionalInfo": null,
              "address": null,
              "dockId": null,
              "friendlyName": null,
              "isPickupStore": false
            },
            "polygonName": "",
            "lockTTL": "12d",
            "pickupPointId": null,
            "transitTime": "3bd",
            "pickupDistance": 0,
            "deliveryIds": [
              {
                "courierId": "NALEST",
                "courierName": "NACIONAL ESTANDAR",
                "dockId": "NALEST",
                "quantity": 1,
                "warehouseId": "126",
                "accountCarrierName": "ortopedicosfuturoco",
                "kitItemDetails": []
              }
            ],
            "shippingEstimateDate": "2026-05-26T15:18:58.5581802-05:00"
          },
          {
            "id": "Envío Express",
            "name": "Envío Express",
            "shippingEstimate": "1bd",
            "deliveryWindow": null,
            "availableDeliveryWindows": [],
            "price": 140800,
            "listPrice": 140800,
            "deliveryChannel": "delivery",
            "pickupStoreInfo": {
              "additionalInfo": null,
              "address": null,
              "dockId": null,
              "friendlyName": null,
              "isPickupStore": false
            },
            "polygonName": "",
            "lockTTL": "12d",
            "pickupPointId": null,
            "transitTime": "1bd",
            "pickupDistance": 0,
            "deliveryIds": [
              {
                "courierId": "BOGEXP",
                "courierName": "EXPRESS BOGOTA",
                "dockId": "NALEST",
                "quantity": 1,
                "warehouseId": "126",
                "accountCarrierName": "ortopedicosfuturoco",
                "kitItemDetails": []
              }
            ],
            "shippingEstimateDate": "2026-05-22T15:16:00-05:00"
          }
        ],
        "shipsTo": [
          "COL"
        ],
        "deliveryIds": [
          {
            "courierId": "NALEST",
            "courierName": "NACIONAL ESTANDAR",
            "dockId": "NALEST",
            "quantity": 1,
            "warehouseId": "126",
            "accountCarrierName": "ortopedicosfuturoco",
            "kitItemDetails": []
          }
        ],
        "deliveryChannels": [
          {
            "id": "delivery",
            "stockBalance": 0
          }
        ],
        "deliveryChannel": "delivery",
        "pickupStoreInfo": {
          "additionalInfo": null,
          "address": null,
          "dockId": null,
          "friendlyName": null,
          "isPickupStore": false
        },
        "addressId": "10676367631476",
        "versionId": null,
        "entityId": null,
        "polygonName": "",
        "pickupPointId": null,
        "transitTime": "3bd"
      }
    ],
    "trackingHints": null,
    "selectedAddresses": [
      {
        "addressType": "residential",
        "receiverName": "SANDRA PATRICIA ROMERO",
        "addressId": "10676367631476",
        "versionId": null,
        "entityId": null,
        "postalCode": "11001",
        "city": "Bogotá, D.c.",
        "state": "Bogotá, D.C.",
        "country": "COL",
        "street": "Carrera 90 Bis 75-77",
        "number": null,
        "neighborhood": "Florencia",
        "complement": null,
        "reference": null,
        "geoCoordinates": [
          -74.07209014892578,
          4.710988521575928
        ]
      }
    ],
    "availableAddresses": [
      {
        "addressType": "residential",
        "receiverName": "SANDRA PATRICIA ROMERO",
        "addressId": "10676367631476",
        "versionId": null,
        "entityId": null,
        "postalCode": "11001",
        "city": "Bogotá, D.c.",
        "state": "Bogotá, D.C.",
        "country": "COL",
        "street": "Carrera 90 Bis 75-77",
        "number": null,
        "neighborhood": "Florencia",
        "complement": null,
        "reference": null,
        "geoCoordinates": [
          -74.07209014892578,
          4.710988521575928
        ]
      }
    ],
    "contactInformation": [],
    "contactsInfo": []
  },
  "ratesAndBenefitsData": {
    "id": "ratesAndBenefitsData",
    "rateAndBenefitsIdentifiers": [
      {
        "description": "15%",
        "featured": false,
        "id": "083be5ff-12cd-4433-a625-d103df4439bd",
        "name": "2605 TRASNOCHON 15",
        "matchedParameters": {
          "productCluster@CatalogSystem": "1077|inclusive"
        },
        "additionalInfo": null
      }
    ]
  },
  "marketingData": {
    "id": "marketingData",
    "utmSource": null,
    "utmPartner": null,
    "utmMedium": null,
    "utmCampaign": null,
    "coupon": null,
    "utmiCampaign": null,
    "utmipage": null,
    "utmiPart": null,
    "marketingTags": [
      "pse-discount-for-bank-code-1013"
    ]
  },
  "giftRegistryData": null,
  "clientProfileData": {
    "id": "clientProfileData",
    "email": "sandyborbon@hotmail.com-264601443631b.ct.vtex.com.br",
    "firstName": "SANDRA PATRICIA",
    "lastName": "ROMERO",
    "documentType": "cedulaCOL",
    "document": "52491166",
    "phone": "+573107661323",
    "corporateName": null,
    "tradeName": null,
    "corporateDocument": null,
    "stateInscription": null,
    "corporatePhone": null,
    "isCorporate": false,
    "userProfileId": "842e8190-3d00-495b-a78f-ed22b2e433a4",
    "userProfileVersion": null,
    "customerClass": null,
    "customerCode": null
  },
  "items": [
    {
      "uniqueId": "3D5F1F54604A48CBB81B060001AB7769",
      "id": "1902",
      "productId": "1294",
      "ean": "087453127720",
      "lockId": "00-1633800577546-01",
      "itemAttachment": {
        "content": {},
        "name": null
      },
      "attachments": [],
      "quantity": 1,
      "seller": "1",
      "name": "Clx Theraband Red Mediu",
      "refId": "22402672",
      "price": 5220000,
      "listPrice": 5220000,
      "manualPrice": null,
      "manualPriceAppliedBy": null,
      "priceTags": [
        {
          "name": "DISCOUNT@MARKETPLACE",
          "value": -783000,
          "isPercentual": false,
          "identifier": "083be5ff-12cd-4433-a625-d103df4439bd",
          "rawValue": -7830,
          "rate": null,
          "jurisCode": null,
          "jurisType": null,
          "jurisName": null
        }
      ],
      "imageUrl": "https://ortopedicosfuturoco.vteximg.com.br/arquivos/ids/173036-55-55/Clx-Theraband-Red-Medium-22402672-1.jpg.jpg?v=638817972727400000",
      "detailUrl": "/clx-theraband-red-mediu-22402672/p",
      "components": [],
      "bundleItems": [],
      "params": [],
      "offerings": [],
      "attachmentOfferings": [],
      "sellerSku": "1902",
      "priceValidUntil": "2027-05-21T15:17:37-05:00",
      "commission": 0,
      "tax": 0,
      "preSaleDate": null,
      "additionalInfo": {
        "brandName": "Theraband",
        "brandId": "1",
        "categoriesIds": "/6/27/170/",
        "categories": [
          {
            "id": 170,
            "name": "Bandas"
          },
          {
            "id": 27,
            "name": "Terapia Física"
          },
          {
            "id": 6,
            "name": "Deporte y Fitness"
          }
        ],
        "productClusterId": "150,191,193,223,228,240,246,273,276,281,283,286,288,294,298,306,310,315,317,328,331,335,347,350,408,411,463,466,470,474,528,539,544,546,561,570,602,605,630,642,668,670,680,707,715,768,777,780,788,794,800,803,810,814,824,832,837,842,861,870,1075,1077",
        "commercialConditionId": "1",
        "dimension": {
          "cubicweight": 0,
          "height": 13.5,
          "length": 4.8,
          "weight": 66,
          "width": 6.5
        },
        "offeringInfo": null,
        "offeringType": null,
        "offeringTypeId": null
      },
      "measurementUnit": "un",
      "unitMultiplier": 1,
      "sellingPrice": 4437000,
      "isGift": false,
      "shippingPrice": null,
      "rewardValue": 0,
      "freightCommission": 0,
      "priceDefinition": {
        "sellingPrices": [
          {
            "value": 4437000,
            "quantity": 1
          }
        ],
        "calculatedSellingPrice": 4437000,
        "total": 4437000,
        "reason": null
      },
      "taxCode": null,
      "parentItemIndex": null,
      "parentAssemblyBinding": null,
      "callCenterOperator": null,
      "serialNumbers": null,
      "assemblies": [],
      "costPrice": 5220000
    },
    {
      "uniqueId": "DF1BD2981ED143888BEFE7476F76D60D",
      "id": "6123",
      "productId": "5508",
      "ean": "7707066001509",
      "lockId": "00-1633800577546-01",
      "itemAttachment": {
        "content": {},
        "name": null
      },
      "attachments": [],
      "quantity": 1,
      "seller": "1",
      "name": "Bolsa Bambu",
      "refId": "99999991",
      "price": 45000,
      "listPrice": 45000,
      "manualPrice": null,
      "manualPriceAppliedBy": null,
      "priceTags": [],
      "imageUrl": "https://ortopedicosfuturoco.vteximg.com.br/arquivos/ids/173266-55-55/Bolsa-OF.png?v=638935412187100000",
      "detailUrl": "/bolsa-bambu/p",
      "components": [],
      "bundleItems": [],
      "params": [],
      "offerings": [],
      "attachmentOfferings": [],
      "sellerSku": "6123",
      "priceValidUntil": "2027-05-21T15:16:40-05:00",
      "commission": 0,
      "tax": 0,
      "preSaleDate": null,
      "additionalInfo": {
        "brandName": "Recovery",
        "brandId": "5",
        "categoriesIds": "/1/11/",
        "categories": [
          {
            "id": 11,
            "name": "Bebidas"
          },
          {
            "id": 1,
            "name": "Alimentos y Bebidas"
          }
        ],
        "productClusterId": "193,875",
        "commercialConditionId": "1",
        "dimension": {
          "cubicweight": 0,
          "height": 5,
          "length": 4.9998,
          "weight": 5,
          "width": 5
        },
        "offeringInfo": null,
        "offeringType": null,
        "offeringTypeId": null
      },
      "measurementUnit": "un",
      "unitMultiplier": 1,
      "sellingPrice": 45000,
      "isGift": false,
      "shippingPrice": null,
      "rewardValue": 0,
      "freightCommission": 0,
      "priceDefinition": {
        "sellingPrices": [
          {
            "value": 45000,
            "quantity": 1
          }
        ],
        "calculatedSellingPrice": 45000,
        "total": 45000,
        "reason": null
      },
      "taxCode": "",
      "parentItemIndex": null,
      "parentAssemblyBinding": null,
      "callCenterOperator": null,
      "serialNumbers": null,
      "assemblies": [],
      "costPrice": 45000
    }
  ],
  "marketplaceItems": [],
  "cancellationRequests": null,
  "approvedBy": null,
  "cancelledBy": null,
  "purchaseAgentData": null,
  "pendingData": null,
  "creationEnvironment": "STABLE",
  "authorizationPolicyData": {
    "status": "accepted",
    "deniedPolicies": [],
    "pendingPolicies": [],
    "acceptedPolicies": []
  },
  "budgetData": null
}'*/
  where id_orden like '1636680578475-01'
/*
UPDATE [Integracion-Vtex-Estandar-Ortopedicos].dbo.ordenes
SET ID_ESTADO = 1, ENDPOINT = NULL, ORDEN_OBJ_DESTINO = NULL
WHERE ID_ORDEN = '1633800577546-01'
*/
SELECT * FROM [Integracion-Vtex-Estandar-Ortopedicos].dbo.ordenes
WHERE id_orden IN (
    '1636240578317-01',
    '1636280578347-01',
    '1636280578345-01',
    '1636260578332-01',
    '1636260578327-01',
    '1636250578322-01',
    -- '1636240578317-01',
    '1636230578307-01',
    '1636230578305-01',
    '1636220578301-01',
    '1636150578292-01')

    /*SELECT * FROM ORDENES

where id_orden IN ('1613940570393-01',
'1608360567999-01',
'1605550566758-01',
'1608340567992-01',
'1608380568013-01',
'1608110567896-01',
'1611200569146-01',
'1612090569726-01')

-- update ordenes set id_estado = 2, endpoint = NULL where id = 1027


DECLARE @endpoint NVARCHAR(500) = 'http://localhost:8083/v3.1/ConectoresImportar?idCompania=6695&idSistema=2&idDocumento=242570&nombreDocumento=PEDIDO_INTEGRACION_VTEX&validarEstructura=true';

IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL
    DROP TABLE #ordenes;

select *
into #ordenes
from ordenes
where id_tienda = 1 
and id_estado = 2
--and id_orden = '1566850515500-01'
and ISNULL(endpoint, '') != @endpoint;

-- Verificar si la tabla temporal tiene datos
IF EXISTS (SELECT 1 FROM #ordenes)
BEGIN
   

IF OBJECT_ID('tempdb..#TempOrdenes') IS NOT NULL
    DROP TABLE #TempOrdenes;

CREATE TABLE #TempOrdenes (
    id_tienda INT,
    id_orden NVARCHAR(50),
    endpoint NVARCHAR(500),
    fecha_creacion DATETIME,
    orden_obj_destino NVARCHAR(MAX)
);

INSERT INTO #TempOrdenes (id_tienda, id_orden, endpoint, fecha_creacion,orden_obj_destino)
SELECT 
	id_tienda,
	id_orden,
    @endpoint as endpoint,
    getdate() as fecha_creacion,
    json_query(( 
	 select 
           		
            
            -- Nodo Pedidos
            json_query(( 
                select 
                                      
					
                    convert(varchar(8), getdate(), 112) as f430_id_fecha,
                    json_value(orden_obj_origen, '$.clientProfileData.document') as f430_id_tercero_fact,                    
                    json_value(orden_obj_origen, '$.clientProfileData.document') as f430_id_tercero_rem,             
					CASE 
					    WHEN UPPER(JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName')) LIKE '%ADDI%'
							THEN 'W001'
					
					    --WHEN JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') IN 
					    --    ('Diners', 'Mastercard', 'Visa', 'PSE', 'Efecty')
					    --    THEN 'W003'
					
					    WHEN JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') = 'PayU No Varix'
					        THEN 'W005'
					
					    WHEN JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') LIKE '%Mercado%'
					        THEN 'W002'
					
					    WHEN JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') = 'Pago contra entrega'
					        THEN 'W004'
					
					    WHEN JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') = 'Transferencias'
					        THEN 'W006'
					
					    ELSE 'W003'
					END AS f430_id_tipo_cli_fact,               
                   	CONVERT(VARCHAR(8),TRY_CAST(LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.logisticsInfo[0].shippingEstimateDate'), 19) AS DATETIME),112	) AS f430_fecha_entrega,						
					LEFT(CONCAT(JSON_VALUE(orden_obj_origen, '$.orderId'), ' (', JSON_VALUE(orden_obj_origen, '$.sequence'), ')' ),  50	) as f430_num_docto_referencia,
					CASE
    -- ADDI
    WHEN JSON_VALUE(orden_obj_origen,
         '$.paymentData.transactions[0].payments[0].paymentSystemName')  LIKE '%ADDI%'
    THEN CONCAT(
            JSON_VALUE(orden_obj_origen, '$.orderId'),
            '-',
            JSON_VALUE(orden_obj_origen, '$.sequence')
         )

    -- NO VARIX (orderId inicia con letras)
    WHEN JSON_VALUE(orden_obj_origen, '$.orderId') LIKE '[A-Z]%'
    THEN SUBSTRING(
            JSON_VALUE(orden_obj_origen, '$.orderId'),
            CHARINDEX('-', JSON_VALUE(orden_obj_origen, '$.orderId')) + 1,
            CHARINDEX(
                '-',
                JSON_VALUE(orden_obj_origen, '$.orderId'),
                CHARINDEX('-', JSON_VALUE(orden_obj_origen, '$.orderId')) + 1
            )
            - CHARINDEX('-', JSON_VALUE(orden_obj_origen, '$.orderId')) - 1
         )

    -- ORTOPÉDICOS FUTURO (orderId numérico)
    ELSE JSON_VALUE(orden_obj_origen, '$.sequence')
END AS f430_notas

			
                   
                for json path, include_null_values
            )) as Pedidos,

	-- Movimiento de items vendidos
			json_query(( 
			    SELECT *
			    FROM (
			        SELECT 
			           
			       --ROW_NUMBER()OVER(ORDER BY(SELECT NULL))AS f431_nro_registro,
				  ROW_NUMBER() OVER ( ORDER BY CAST(item.[key] AS INT)) AS f431_nro_registro,
				   '' AS f431_referencia_item,
                   JSON_VALUE(item.value, '$.ean') AS f431_codigo_barras,
			         CONVERT(VARCHAR(8),TRY_CAST(LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.logisticsInfo[0].shippingEstimateDate'), 19) AS DATETIME),112) AS f431_fecha_entrega,			           
			           						
			            --'UND' AS f431_id_unidad_medida,
						ISNULL(LTRIM(RTRIM(v121_id_unidad_inventario)),'UN') AS f431_id_unidad_medida,
			            JSON_VALUE(item.value, '$.quantity') AS f431_cant_pedida_base,
						'P01' as f431_id_lista_precio,
			            CASE 
			                WHEN LEN(ISNULL(JSON_VALUE(item.value, '$.listPrice'), '')) > 2 
			                THEN LEFT(JSON_VALUE(item.value, '$.listPrice'), LEN(JSON_VALUE(item.value, '$.listPrice')) - 2)
			                ELSE '0'
			            END AS f431_precio_unitario	,
						CASE
    -- ADDI
    WHEN JSON_VALUE(orden_obj_origen,
         '$.paymentData.transactions[0].payments[0].paymentSystemName') LIKE '%ADDI%'
    THEN CONCAT(
            JSON_VALUE(orden_obj_origen, '$.orderId'),
            '-',
            JSON_VALUE(orden_obj_origen, '$.sequence')
         )

    -- NO VARIX (orderId inicia con letras)
    WHEN JSON_VALUE(orden_obj_origen, '$.orderId') LIKE '[A-Z]%'
    THEN SUBSTRING(
            JSON_VALUE(orden_obj_origen, '$.orderId'),
            CHARINDEX('-', JSON_VALUE(orden_obj_origen, '$.orderId')) + 1,
            CHARINDEX(
                '-',
                JSON_VALUE(orden_obj_origen, '$.orderId'),
                CHARINDEX('-', JSON_VALUE(orden_obj_origen, '$.orderId')) + 1
            )
            - CHARINDEX('-', JSON_VALUE(orden_obj_origen, '$.orderId')) - 1
         )

    -- ORTOPÉDICOS FUTURO (orderId numérico)
    ELSE JSON_VALUE(orden_obj_origen, '$.sequence')
END AS f431_notas		           
			        FROM OPENJSON(orden_obj_origen, '$.items') AS item
					LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[v121] v121 
					ON v121.v121_id_barras_principal = ISNULL(JSON_VALUE(item.value, '$.ean'), JSON_VALUE(item.value, '$.refId'))	
					AND v121.v121_id_cia	= 1

               union all
			   select 
			     -- SEGUNDO SELECT: ENVÍO COMO ITEM SEPARADO
				    300 AS f431_nro_registro,
                    '99999977' AS f431_referencia_item,   
					'' AS f431_codigo_barras,                 
						
			         CONVERT(VARCHAR(8),TRY_CAST(LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.logisticsInfo[0].shippingEstimateDate'), 19) AS DATETIME),112) AS f431_fecha_entrega,			           
			           						
			            --'UND' AS f431_id_unidad_medida,
						'UN' AS f431_id_unidad_medida,
			            1 AS f431_cant_pedida_base,
						'P01' as f431_id_lista_precio,
			           ISNULL((
    SELECT CAST(JSON_VALUE(value, '$.value') AS BIGINT) / 100
    FROM OPENJSON(orden_obj_origen, '$.totals')
    WHERE JSON_VALUE(value, '$.id') = 'Shipping'), 0) AS f431_precio_unitario, 'Shipping' as f431_notas
						
	WHERE JSON_VALUE(orden_obj_origen,'$.shippingData.logisticsInfo[0].price') <> '0'
                ) as MovimientoPedidoComercial 
                for json path, include_null_values
            )) as MovimientoPedidoComercial,
			-- =========================

-- NODO DESCUENTOS CORREGIDO
-- =========================


JSON_QUERY((
    SELECT
        --ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS f431_nro_registro,
		CAST(item.[key] AS INT) + 1 AS f431_nro_registro ,     

CASE 
    WHEN JSON_VALUE(tag.value,'$.value') IS NOT NULL THEN
        CAST(
            (
                ABS(TRY_CAST(JSON_VALUE(tag.value,'$.value') AS DECIMAL(18,2))) / 100.0
            )
            / NULLIF(TRY_CAST(JSON_VALUE(item.value,'$.quantity') AS DECIMAL(18,2)), 0)
        AS DECIMAL(18,2))
    ELSE NULL
END AS f432_vlr_uni,
        --ABS(TRY_CAST(JSON_VALUE(orden_obj_origen,'$.totals.Discounts.value') AS DECIMAL(18,2))) AS f432_vlr_uni,

        0 AS f432_tasa

    FROM OPENJSON(orden_obj_origen,'$.items') item
    CROSS APPLY OPENJSON(item.value,'$.priceTags') tag

    WHERE 
        TRY_CAST(JSON_VALUE(tag.value,'$.value') AS DECIMAL(18,2)) < 0
       ---- AND JSON_VALUE(tag.value,'$.name') LIKE '%MARKETPLACE%'

    FOR JSON PATH, INCLUDE_NULL_VALUES
)) AS Descuentos

        for json path, without_array_wrapper, include_null_values
    )) as orden_obj_destino 
from #ordenes

UPDATE t
SET orden_obj_destino = JSON_MODIFY(
    t.orden_obj_destino,
    '$.Descuentos',
    JSON_QUERY(
        (SELECT 
             JSON_VALUE(value,'$.f430_id_co') AS f430_id_co,
             JSON_VALUE(value,'$.f430_id_tipo_docto') AS f430_id_tipo_docto,
             JSON_VALUE(value,'$.f430_consec_docto') AS f430_consec_docto,
             TRY_CAST(JSON_VALUE(value,'$.f431_nro_registro') AS INT) AS f431_nro_registro,
             TRY_CAST(JSON_VALUE(value,'$.f432_tasa') AS DECIMAL(18,4)) AS f432_tasa,
             JSON_VALUE(value,'$.f432_vlr_uni') AS f432_vlr_uni
         FROM OPENJSON(t.orden_obj_destino,'$.Descuentos')
         WHERE TRY_CAST(JSON_VALUE(value,'$.f432_vlr_uni') AS DECIMAL(18,4)) <> 0
         FOR JSON PATH)
    )
)
FROM #TempOrdenes t
--WHERE JSON_QUERY(t.orden_obj_destino,'$.Descuentos') IS NOT NULL;
WHERE 
    JSON_QUERY(orden_obj_destino, '$.Descuentos') IS NULL
    OR JSON_QUERY(orden_obj_destino, '$.Descuentos') = '[]';

-- select * from #TempOrdenes
-- Realizar el UPDATE utilizando la tabla temporal 
UPDATE o
SET 
    o.endpoint = t.endpoint,
    o.intentos = 0,	
    o.fecha_creacion = t.fecha_creacion,
    o.orden_obj_destino = t.orden_obj_destino
FROM ordenes o
JOIN #TempOrdenes t ON o.id_tienda = t.id_tienda AND o.id_orden = t.id_orden;

END*/
/*
*/
SELECT * FROM ORDENES 
WHERE 
id_orden IN (
'1613940570393-01',
'1608360567999-01',
'1605550566758-01',
'1608340567992-01',
'1608380568013-01',
'1608110567896-01',
'1611200569146-01',
'1612090569726-01'
)