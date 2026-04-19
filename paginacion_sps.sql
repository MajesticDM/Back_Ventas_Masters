-- =====================================================================
-- SP_CARGADO_FACTURAS_V2  — con paginación server-side
-- =====================================================================
CREATE OR ALTER PROCEDURE [dbo].[SP_CARGADO_FACTURAS_V2]
    @todas              bit,
    @fechaInicial       datetime = null,
    @fechaFinal         datetime = null,
    @cliente            decimal,
    @usuario            decimal,
    @pagina             int = 1,
    @registros_por_pagina int = 10
AS
BEGIN
    SET NOCOUNT ON;

    SELECT FC.ID_FACTURA, FC.COSTO_TOTAL, FC.IDX_CLIENTE, FC.IDX_USUARIO,
           FP.FORMA_PAGO AS forma_pago, FC.IDX_FORMA_PAGO AS medio,
           FORMAT(FC.FECHA_VENTA, 'dd/MM/yyyy hh:mm tt') AS FECHA_VENTA,
           CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS) AS CLIENTE_NOMBRE,
           CL.NUMERO_TELEFONO AS TELEFONO_CLIENTE,
           CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS) AS USUARIO_NOMBRE,
           DP.NUMERO_TELEFONO AS TELEFONO_USUARIO,
           FC.CONSUMIDOR_FINAL, FC.VALOR_IVA,
           FC.VALOR_PAGADO AS pagado
    INTO #CLIENTES
    FROM FACTURAS FC
    INNER JOIN CLIENTES CL ON FC.IDX_CLIENTE = CL.CLIENTE_ID
    INNER JOIN USUARIOS US ON FC.IDX_USUARIO = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO FP ON FC.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
    WHERE ((FC.FECHA_VENTA >= ISNULL(@fechaInicial, FC.FECHA_VENTA)
            AND FC.FECHA_VENTA <= ISNULL(@fechaFinal, FC.FECHA_VENTA))
           OR @todas = 1)
      AND (FC.IDX_USUARIO = @usuario OR @usuario = 0)
      AND (FC.IDX_CLIENTE = @cliente OR @cliente = 0);

    -- IDs de la página actual
    SELECT ID_FACTURA
    INTO #PAGINA
    FROM #CLIENTES
    ORDER BY ID_FACTURA DESC
    OFFSET (@pagina - 1) * @registros_por_pagina ROWS
    FETCH NEXT @registros_por_pagina ROWS ONLY;

    -- Resultado 1: registros de la página
    SELECT * FROM #CLIENTES
    WHERE ID_FACTURA IN (SELECT ID_FACTURA FROM #PAGINA)
    ORDER BY ID_FACTURA DESC;

    -- Resultado 2: productos vendidos en esta página
    SELECT VP.IDX_FACTURA, VP.QUANTITY, VP.TOTAL_COST,
           VP.COSTO_UNITARIO_AL_VENDER AS valor_vendido,
           P.PRODUCTO, P.COSTO_X_UNIDAD, VP.SUB_TOTAL, VP.VALOR_IVA,
           MP.EQUIVALENCIA_MEDIDA,
           CASE MP.IDX_TIPO_MEDIDA
               WHEN 1 THEN ''
               ELSE CASE VP.QUANTITY WHEN 1 THEN 'unidad' ELSE 'unidades' END
           END AS EQUIVALENCIA,
           GRAMAJE_VENDIDO
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN PRODUCTOS P ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT JOIN MEDIDAS_PESADO MP ON P.IDX_MEDIDA = MP.ID_MEDIDAS_PESADO
    WHERE VP.IDX_FACTURA IN (SELECT ID_FACTURA FROM #PAGINA);

    -- Resultado 3: servicios vendidos en esta página
    SELECT SD.*, S.COSTO_REGULAR, S.SERVICIO
    FROM SERVICIOS_DADOS SD
    INNER JOIN SERVICIOS S ON SD.IDX_SERVICIO = S.SERVICIO_ID
    WHERE SD.IDX_FACTURA IN (SELECT ID_FACTURA FROM #PAGINA);

    -- Resultado 4: total de registros (para el paginador Angular)
    SELECT COUNT(*) AS total_registros FROM #CLIENTES;

    DROP TABLE #PAGINA;
    DROP TABLE #CLIENTES;
END
GO

-- =====================================================================
-- SP_CARGADO_COMPRAS_V2  — con paginación server-side
-- =====================================================================
CREATE OR ALTER PROCEDURE [dbo].[SP_CARGADO_COMPRAS_V2]
    @todas              bit,
    @fechaInicial       datetime = null,
    @fechaFinal         datetime = null,
    @proveedor          decimal,
    @usuario            decimal,
    @pagina             int = 1,
    @registros_por_pagina int = 10
AS
BEGIN
    SET NOCOUNT ON;

    SELECT C.ID_COMPRA, C.COSTO_TOTAL, C.IDX_PROVEEDOR, C.IDX_USUARIO_COMPRADOR,
           FP.FORMA_PAGO AS forma_pago, C.IDX_FORMA_PAGO AS medio,
           FORMAT(C.FECHA_COMPRA, 'dd/MM/yyyy hh:mm tt') AS FECHA_COMPRA,
           PV.RAZON_SOCIAL AS PROVEEDOR, PV.TELEFONO AS TELEFONO_PROVEEDOR,
           CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS) AS USUARIO_NOMBRE,
           DP.NUMERO_TELEFONO AS TELEFONO_USUARIO,
           C.VALOR_PAGADO AS pagado
    INTO #COMPRAS
    FROM COMPRAS C
    INNER JOIN PROVEEDORES PV ON C.IDX_PROVEEDOR = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS US ON C.IDX_USUARIO_COMPRADOR = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO FP ON C.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
    WHERE ((C.FECHA_COMPRA >= ISNULL(@fechaInicial, C.FECHA_COMPRA)
            AND C.FECHA_COMPRA <= ISNULL(@fechaFinal, C.FECHA_COMPRA))
           OR @todas = 1)
      AND (C.IDX_USUARIO_COMPRADOR = @usuario OR @usuario = 0)
      AND (C.IDX_PROVEEDOR = @proveedor OR @proveedor = 0);

    -- IDs de la página actual
    SELECT ID_COMPRA
    INTO #PAGINA
    FROM #COMPRAS
    ORDER BY ID_COMPRA DESC
    OFFSET (@pagina - 1) * @registros_por_pagina ROWS
    FETCH NEXT @registros_por_pagina ROWS ONLY;

    -- Resultado 1: registros de la página
    SELECT * FROM #COMPRAS
    WHERE ID_COMPRA IN (SELECT ID_COMPRA FROM #PAGINA)
    ORDER BY ID_COMPRA DESC;

    -- Resultado 2: productos comprados en esta página
    SELECT CD.IDX_COMPRA, CD.CANTIDAD, CD.COSTO, CD.COSTO / CD.CANTIDAD AS valor_comprado,
           P.PRODUCTO, P.COSTO_X_UNIDAD, MP.EQUIVALENCIA_MEDIDA,
           CASE MP.IDX_TIPO_MEDIDA
               WHEN 1 THEN ''
               ELSE CASE CD.CANTIDAD WHEN 1 THEN 'unidad' ELSE 'unidades' END
           END AS EQUIVALENCIA,
           GRAMAJE_COMPRADO
    FROM COMPRAS_DETALLES CD
    INNER JOIN PRODUCTOS P ON CD.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT JOIN MEDIDAS_PESADO MP ON P.IDX_MEDIDA = MP.ID_MEDIDAS_PESADO
    WHERE CD.IDX_COMPRA IN (SELECT ID_COMPRA FROM #PAGINA);

    -- Resultado 3: total de registros (para el paginador Angular)
    SELECT COUNT(*) AS total_registros FROM #COMPRAS;

    DROP TABLE #PAGINA;
    DROP TABLE #COMPRAS;
END
GO
