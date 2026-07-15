-- =============================================================
--  ANULACIÓN DE COMPRAS
--  Ejecutar en orden. Idempotente: se puede correr varias veces.
-- =============================================================

-- -------------------------------------------------------------
-- 1. Campo ANULADA en tabla COMPRAS
-- -------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'COMPRAS' AND COLUMN_NAME = 'ANULADA'
)
BEGIN
    ALTER TABLE COMPRAS ADD ANULADA BIT NOT NULL DEFAULT 0;
    PRINT 'Columna ANULADA agregada a COMPRAS.';
END
ELSE
    PRINT 'Columna ANULADA ya existe en COMPRAS — omitida.';
GO

-- -------------------------------------------------------------
-- 2. SP_ANULAR_COMPRA
--    - Marca ANULADA = 1
--    - Restaura stock de productos
--    - Revierte deuda al proveedor (solo si fue a crédito,
--      IDX_FORMA_PAGO = 2)
-- -------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_ANULAR_COMPRA]
    @id_compra NUMERIC(18, 0)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar que existe
    IF NOT EXISTS (SELECT 1 FROM COMPRAS WHERE ID_COMPRA = @id_compra)
    BEGIN
        RAISERROR('Compra #%d no encontrada.', 16, 1, @id_compra);
        RETURN;
    END

    -- Validar que no esté ya anulada
    IF EXISTS (SELECT 1 FROM COMPRAS WHERE ID_COMPRA = @id_compra AND ANULADA = 1)
    BEGIN
        RAISERROR('La compra #%d ya está anulada.', 16, 1, @id_compra);
        RETURN;
    END

    DECLARE @forma_pago      NUMERIC(18, 0);
    DECLARE @costo_total     DECIMAL(18, 2);
    DECLARE @valor_pagado    DECIMAL(18, 2);
    DECLARE @idx_proveedor   NUMERIC(18, 0);

    SELECT
        @forma_pago    = IDX_FORMA_PAGO,
        @costo_total   = COSTO_TOTAL,
        @valor_pagado  = VALOR_PAGADO,
        @idx_proveedor = IDX_PROVEEDOR
    FROM COMPRAS
    WHERE ID_COMPRA = @id_compra;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 2a. Marcar como anulada
        UPDATE COMPRAS
        SET ANULADA = 1
        WHERE ID_COMPRA = @id_compra;

        -- 2b. Restaurar stock de productos existentes
        UPDATE P
        SET P.QUANTITY = P.QUANTITY - CD.CANTIDAD
        FROM PRODUCTOS P
        INNER JOIN COMPRAS_DETALLES CD ON P.PRODUCT_ID = CD.IDX_PRODUCTO
        WHERE CD.IDX_COMPRA = @id_compra
          AND CD.IDX_PRODUCTO IS NOT NULL;

        -- 2c. Si era a crédito, revertir la deuda pendiente con el proveedor
        --     (solo se revierte lo que queda sin pagar)
        IF @forma_pago = 2
        BEGIN
            DECLARE @deuda_restante DECIMAL(18, 2) = @costo_total - @valor_pagado;

            IF @deuda_restante > 0
            BEGIN
                UPDATE PROVEEDORES
                SET SALDO_PENDIENTE = ISNULL(SALDO_PENDIENTE, 0) - @deuda_restante
                WHERE ID_PROVEEDOR = @idx_proveedor;
            END
        END

        COMMIT TRANSACTION;

        SELECT 'OK' AS resultado, 'Compra anulada correctamente.' AS mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @err NVARCHAR(500) = ERROR_MESSAGE();
        RAISERROR('%s', 16, 1, @err);
    END CATCH
END
GO

-- -------------------------------------------------------------
-- 3. SP_CARGADO_COMPRAS  — agrega campo ANULADA al resultado
--    (informe-compras muestra todas, incluidas anuladas con badge)
-- -------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_CARGADO_COMPRAS]
    @todas          BIT,
    @fechaInicial   DATETIME = NULL,
    @fechaFinal     DATETIME = NULL,
    @proveedor      DECIMAL,
    @usuario        DECIMAL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        C.ID_COMPRA,
        C.COSTO_TOTAL,
        C.IDX_PROVEEDOR,
        C.IDX_USUARIO_COMPRADOR,
        FP.FORMA_PAGO                                                   AS forma_pago,
        C.IDX_FORMA_PAGO                                                AS medio,
        FORMAT(C.FECHA_COMPRA, 'dd/MM/yyyy hh:mm tt')                  AS FECHA_COMPRA,
        PV.RAZON_SOCIAL                                                 AS PROVEEDOR,
        PV.TELEFONO                                                     AS TELEFONO_PROVEEDOR,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                          AS USUARIO_NOMBRE,
        DP.NUMERO_TELEFONO                                              AS TELEFONO_USUARIO,
        C.VALOR_PAGADO                                                  AS pagado,
        ISNULL(C.ANULADA, 0)                                           AS anulada
    INTO #COMPRAS
    FROM COMPRAS C
    INNER JOIN PROVEEDORES       PV ON C.IDX_PROVEEDOR               = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS          US ON C.IDX_USUARIO_COMPRADOR        = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES  DP ON US.IDX_DATOS_PERSONALES        = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO       FP ON C.IDX_FORMA_PAGO               = FP.ID_FORMA_PAGO
    WHERE ((C.FECHA_COMPRA >= ISNULL(@fechaInicial, C.FECHA_COMPRA)
            AND C.FECHA_COMPRA <= ISNULL(@fechaFinal, C.FECHA_COMPRA)) OR @todas = 1)
      AND (C.IDX_USUARIO_COMPRADOR = @usuario  OR @usuario  = 0)
      AND (C.IDX_PROVEEDOR         = @proveedor OR @proveedor = 0);

    -- Resultado 1: encabezados de compras
    SELECT * FROM #COMPRAS;

    -- Resultado 2: detalles de productos
    SELECT
        CD.IDX_COMPRA,
        CD.CANTIDAD,
        CD.COSTO,
        CD.COSTO / CD.CANTIDAD                              AS valor_comprado,
        P.PRODUCTO,
        P.COSTO_X_UNIDAD,
        MP.EQUIVALENCIA_MEDIDA,
        CASE MP.IDX_TIPO_MEDIDA
            WHEN 1 THEN ''
            ELSE CASE CD.CANTIDAD WHEN 1 THEN 'unidad' ELSE 'unidades' END
        END                                                 AS EQUIVALENCIA,
        GRAMAJE_COMPRADO
    FROM COMPRAS_DETALLES  CD
    INNER JOIN PRODUCTOS        P  ON CD.IDX_PRODUCTO  = P.PRODUCT_ID
    LEFT  JOIN MEDIDAS_PESADO   MP ON P.IDX_MEDIDA     = MP.ID_MEDIDAS_PESADO
    WHERE CD.IDX_COMPRA IN (SELECT ID_COMPRA FROM #COMPRAS);

    DROP TABLE #COMPRAS;
END
GO

-- -------------------------------------------------------------
-- 4. SP_CARGADO_COMPRAS_V2  — agrega ANULADA al resultado
--    (abonos-compras usa este SP con paginación)
-- -------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_CARGADO_COMPRAS_V2]
    @todas                  BIT,
    @fechaInicial           DATETIME  = NULL,
    @fechaFinal             DATETIME  = NULL,
    @proveedor              DECIMAL,
    @usuario                DECIMAL,
    @pagina                 INT       = 1,
    @registros_por_pagina   INT       = 10
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        C.ID_COMPRA,
        C.COSTO_TOTAL,
        C.IDX_PROVEEDOR,
        C.IDX_USUARIO_COMPRADOR,
        FP.FORMA_PAGO                                                   AS forma_pago,
        C.IDX_FORMA_PAGO                                                AS medio,
        FORMAT(C.FECHA_COMPRA, 'dd/MM/yyyy hh:mm tt')                  AS FECHA_COMPRA,
        PV.RAZON_SOCIAL                                                 AS PROVEEDOR,
        PV.TELEFONO                                                     AS TELEFONO_PROVEEDOR,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                          AS USUARIO_NOMBRE,
        DP.NUMERO_TELEFONO                                              AS TELEFONO_USUARIO,
        C.VALOR_PAGADO                                                  AS pagado,
        ISNULL(C.ANULADA, 0)                                           AS anulada
    INTO #COMPRAS
    FROM COMPRAS C
    INNER JOIN PROVEEDORES       PV ON C.IDX_PROVEEDOR               = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS          US ON C.IDX_USUARIO_COMPRADOR        = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES  DP ON US.IDX_DATOS_PERSONALES        = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO       FP ON C.IDX_FORMA_PAGO               = FP.ID_FORMA_PAGO
    WHERE ((C.FECHA_COMPRA >= ISNULL(@fechaInicial, C.FECHA_COMPRA)
            AND C.FECHA_COMPRA <= ISNULL(@fechaFinal, C.FECHA_COMPRA)) OR @todas = 1)
      AND (C.IDX_USUARIO_COMPRADOR = @usuario   OR @usuario   = 0)
      AND (C.IDX_PROVEEDOR         = @proveedor OR @proveedor = 0);

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
    SELECT
        CD.IDX_COMPRA,
        CD.CANTIDAD,
        CD.COSTO,
        CD.COSTO / CD.CANTIDAD                              AS valor_comprado,
        P.PRODUCTO,
        P.COSTO_X_UNIDAD,
        MP.EQUIVALENCIA_MEDIDA,
        CASE MP.IDX_TIPO_MEDIDA
            WHEN 1 THEN ''
            ELSE CASE CD.CANTIDAD WHEN 1 THEN 'unidad' ELSE 'unidades' END
        END                                                 AS EQUIVALENCIA,
        GRAMAJE_COMPRADO
    FROM COMPRAS_DETALLES  CD
    INNER JOIN PRODUCTOS        P  ON CD.IDX_PRODUCTO  = P.PRODUCT_ID
    LEFT  JOIN MEDIDAS_PESADO   MP ON P.IDX_MEDIDA     = MP.ID_MEDIDAS_PESADO
    WHERE CD.IDX_COMPRA IN (SELECT ID_COMPRA FROM #PAGINA);

    -- Resultado 3: total de registros (para el paginador Angular)
    SELECT COUNT(*) AS total_registros FROM #COMPRAS;

    DROP TABLE #PAGINA;
    DROP TABLE #COMPRAS;
END
GO

-- -------------------------------------------------------------
-- 5. SP_ABONOS_COMPRAS  — excluye anuladas del listado de créditos
--    (operación 'COMPRAS')
-- -------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_ABONOS_COMPRAS]
    @OPERACION              VARCHAR(10),
    @ID_DETALLE             NUMERIC(18, 0)  = NULL,
    @IDX_COMPRA             NUMERIC(18, 0)  = NULL,
    @IDX_USUARIO            NUMERIC(18, 0)  = NULL,
    @IDX_PROVEEDOR          NUMERIC(18, 0)  = NULL,
    @IDX_FORMA_PAGO         NUMERIC(18, 0)  = NULL,
    @IDX_CLIENTE            NUMERIC(18, 0)  = NULL,
    @BIT_PAGA_CLIENTE       NUMERIC(18, 0)  = NULL,
    @VALOR_ABONADO          DECIMAL(18, 2)  = NULL,
    @COMENTARIO             VARCHAR(100)    = NULL,
    @ESTADO                 BIT             = NULL,
    @PAGO_TOTAL             BIT             = NULL,
    @FECHA_FINAL            DATETIME        = NULL,
    @FECHA_INICIAL          DATETIME        = NULL,
    @PAGINA                 INT             = 1,
    @TAMANO_PAGINA          INT             = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @OPERACION = 'ABONOS'
    BEGIN
        SELECT
            IDX_COMPRA, IDX_USUARIO, DAC.IDX_FORMA_PAGO,
            DP.NOMBRES + ' ' + DP.APELLIDOS                AS USUARIO,
            DAC.FECHA_ABONO, DAC.VALOR_ABONADO,
            FP.FORMA_PAGO,
            C.NOMBRES + ' ' + C.APELLIDOS                  AS CLIENTE,
            ISNULL(DAC.BIT_PAGA_CLIENTE, 0)                AS bit_paga_cliente,
            DAC.COMENTARIO
        FROM DETALLE_ABONOS_COMPRAS DAC
        INNER JOIN USUARIOS          U  ON DAC.IDX_USUARIO   = U.USUARIO_ID
        INNER JOIN DATOS_PERSONALES  DP ON U.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
        LEFT  JOIN FORMAS_PAGO       FP ON DAC.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
        LEFT  JOIN CLIENTES          C  ON DAC.IDX_CLIENTE    = C.CLIENTE_ID
        WHERE @IDX_COMPRA IS NULL OR DAC.IDX_COMPRA = @IDX_COMPRA
    END

    ELSE IF @OPERACION = 'COMPRAS'
    BEGIN
        SELECT
            PR.RAZON_SOCIAL,
            (CP.COSTO_TOTAL - CP.VALOR_PAGADO)              AS RESTANTE,
            CP.COSTO_TOTAL,
            CP.FECHA_COMPRA,
            CP.IDX_PROVEEDOR,
            CP.ID_COMPRA,
            CP.PAGO_INICIAL,
            FORMAS_PAGO.FORMA_PAGO,
            ISNULL(CP.ANULADA, 0)                          AS anulada,
            COUNT(*) OVER()                                AS total_registros
        FROM COMPRAS CP
        INNER JOIN PROVEEDORES   PR ON CP.IDX_PROVEEDOR             = PR.ID_PROVEEDOR
        LEFT  JOIN FORMAS_PAGO       ON CP.IDX_FORMA_PAGO_INICIAL   = FORMAS_PAGO.ID_FORMA_PAGO
        WHERE CP.IDX_FORMA_PAGO = 2
          AND (ISNULL(CP.ANULADA, 0) = 0)                  -- excluye anuladas
          AND (@FECHA_INICIAL IS NULL OR CP.FECHA_COMPRA > @FECHA_INICIAL)
          AND (@FECHA_FINAL   IS NULL OR CP.FECHA_COMPRA < @FECHA_FINAL)
          AND (@IDX_PROVEEDOR IS NULL OR CP.IDX_PROVEEDOR  = @IDX_PROVEEDOR)
        ORDER BY (CP.COSTO_TOTAL - CP.VALOR_PAGADO) DESC
        OFFSET (@PAGINA - 1) * @TAMANO_PAGINA ROWS
        FETCH NEXT @TAMANO_PAGINA ROWS ONLY;
    END

    ELSE IF @OPERACION = 'INSERT'
    BEGIN
        DECLARE @PAGO_REALIZADO_A_LA_FECHA  DECIMAL(18, 2) = (SELECT TOP 1 ISNULL(VALOR_PAGADO, 0)         FROM COMPRAS     WHERE ID_COMPRA     = @IDX_COMPRA)
        DECLARE @COSTO_TOTAL                DECIMAL(18, 2) = (SELECT TOP 1 ISNULL(COSTO_TOTAL, 0)          FROM COMPRAS     WHERE ID_COMPRA     = @IDX_COMPRA)
        DECLARE @SALDO_PENDIENTE_PROVEEDOR  DECIMAL(18, 2) = (SELECT TOP 1 ISNULL(SALDO_PENDIENTE, 0)      FROM PROVEEDORES WHERE ID_PROVEEDOR  = @IDX_PROVEEDOR)
        DECLARE @caja                       NUMERIC(18, 0) = (SELECT TOP 1 ID_CAJA FROM CAJA WHERE IDX_USUARIO = @IDX_USUARIO AND FECHA_CIERRE_CAJA IS NULL)

        IF @PAGO_TOTAL = 1
        BEGIN
            UPDATE COMPRAS    SET VALOR_PAGADO      = @COSTO_TOTAL WHERE ID_COMPRA    = @IDX_COMPRA
            SET @SALDO_PENDIENTE_PROVEEDOR = @SALDO_PENDIENTE_PROVEEDOR - (@COSTO_TOTAL - @PAGO_REALIZADO_A_LA_FECHA)
            SET @VALOR_ABONADO = @COSTO_TOTAL - @PAGO_REALIZADO_A_LA_FECHA
            UPDATE PROVEEDORES SET SALDO_PENDIENTE  = @SALDO_PENDIENTE_PROVEEDOR WHERE ID_PROVEEDOR = @IDX_PROVEEDOR
        END
        ELSE
        BEGIN
            SET @PAGO_REALIZADO_A_LA_FECHA = @PAGO_REALIZADO_A_LA_FECHA + @VALOR_ABONADO
            UPDATE COMPRAS    SET VALOR_PAGADO      = @PAGO_REALIZADO_A_LA_FECHA WHERE ID_COMPRA    = @IDX_COMPRA
            SET @SALDO_PENDIENTE_PROVEEDOR = @SALDO_PENDIENTE_PROVEEDOR - @VALOR_ABONADO
            UPDATE PROVEEDORES SET SALDO_PENDIENTE  = @SALDO_PENDIENTE_PROVEEDOR WHERE ID_PROVEEDOR = @IDX_PROVEEDOR
        END

        INSERT INTO DETALLE_ABONOS_COMPRAS (IDX_COMPRA, IDX_USUARIO, IDX_FORMA_PAGO, VALOR_ABONADO, FECHA_ABONO, COMENTARIO, ESTADO, IDX_CAJA, IDX_CLIENTE, BIT_PAGA_CLIENTE)
        VALUES (@IDX_COMPRA, @IDX_USUARIO, @IDX_FORMA_PAGO, @VALOR_ABONADO, GETDATE(), @COMENTARIO, 1, @caja, @IDX_CLIENTE, @BIT_PAGA_CLIENTE)
    END
END
GO

-- -------------------------------------------------------------
-- 6. SP_BALANCE_PERIODOS  — excluye compras anuladas de totales
-- -------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_BALANCE_PERIODOS]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy                DATE = CONVERT(DATE, GETDATE());
    DECLARE @inicio_semana      DATE = DATEADD(WEEK, DATEDIFF(WEEK, 0, GETDATE()), 0);
    DECLARE @fin_semana         DATE = DATEADD(DAY, 6, @inicio_semana);
    DECLARE @inicio_mes         DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    DECLARE @fin_mes            DATE = EOMONTH(GETDATE());

    ;WITH cte_ventas AS (
        SELECT
            F.ID_FACTURA,
            F.COSTO_TOTAL,
            F.IDX_CLIENTE,
            CONVERT(DATE, F.FECHA_VENTA)        AS fecha,
            ISNULL(VP.utilidad, 0)              AS utilidad
        FROM FACTURAS F
        LEFT JOIN (
            SELECT IDX_FACTURA, SUM(UTILIDAD_TOTAL) AS utilidad
            FROM VENDIDO_PRODUCTOS
            GROUP BY IDX_FACTURA
        ) VP ON F.ID_FACTURA = VP.IDX_FACTURA
        WHERE (F.ANULADO IS NULL OR F.ANULADO <> 1)
    ),
    cte_compras AS (
        SELECT CONVERT(DATE, FECHA_COMPRA) AS fecha, COSTO_TOTAL
        FROM COMPRAS
        WHERE ISNULL(ANULADA, 0) = 0           -- excluye anuladas
    ),
    cte_gastos AS (
        SELECT CONVERT(DATE, FECHA_MOVIMIENTO) AS fecha, VALOR
        FROM MOVIMIENTOS_CAJA
        WHERE IDX_TIPO_MOVIMIENTO = 2
    ),
    cte_abonos AS (
        SELECT CONVERT(DATE, FECHA_ABONO) AS fecha, VALOR_ABONADO
        FROM DETALLE_ABONOS_VENTAS
    )

    SELECT
        periodo,
        total_ingresos,
        utilidad_bruta,
        total_compras,
        gastos_caja,
        abonos_recibidos,
        total_ingresos - total_compras - gastos_caja   AS balance_neto,
        num_facturas,
        clientes_atendidos
    FROM (
        SELECT
            'DIARIO' AS periodo,
            ISNULL((SELECT SUM(COSTO_TOTAL)         FROM cte_ventas  WHERE fecha = @hoy), 0) AS total_ingresos,
            ISNULL((SELECT SUM(utilidad)             FROM cte_ventas  WHERE fecha = @hoy), 0) AS utilidad_bruta,
            ISNULL((SELECT SUM(COSTO_TOTAL)         FROM cte_compras WHERE fecha = @hoy), 0) AS total_compras,
            ISNULL((SELECT SUM(VALOR)               FROM cte_gastos  WHERE fecha = @hoy), 0) AS gastos_caja,
            ISNULL((SELECT SUM(VALOR_ABONADO)       FROM cte_abonos  WHERE fecha = @hoy), 0) AS abonos_recibidos,
            ISNULL((SELECT COUNT(*)                 FROM cte_ventas  WHERE fecha = @hoy), 0) AS num_facturas,
            ISNULL((SELECT COUNT(DISTINCT IDX_CLIENTE) FROM cte_ventas WHERE fecha = @hoy), 0) AS clientes_atendidos
        UNION ALL
        SELECT
            'SEMANAL',
            ISNULL((SELECT SUM(COSTO_TOTAL)         FROM cte_ventas  WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT SUM(utilidad)             FROM cte_ventas  WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT SUM(COSTO_TOTAL)         FROM cte_compras WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT SUM(VALOR)               FROM cte_gastos  WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT SUM(VALOR_ABONADO)       FROM cte_abonos  WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT COUNT(*)                 FROM cte_ventas  WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT COUNT(DISTINCT IDX_CLIENTE) FROM cte_ventas WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0)
        UNION ALL
        SELECT
            'MENSUAL',
            ISNULL((SELECT SUM(COSTO_TOTAL)         FROM cte_ventas  WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT SUM(utilidad)             FROM cte_ventas  WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT SUM(COSTO_TOTAL)         FROM cte_compras WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT SUM(VALOR)               FROM cte_gastos  WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT SUM(VALOR_ABONADO)       FROM cte_abonos  WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT COUNT(*)                 FROM cte_ventas  WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT COUNT(DISTINCT IDX_CLIENTE) FROM cte_ventas WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0)
    ) AS resumen;
END
GO

-- -------------------------------------------------------------
-- 7. SP_LISTADO_PERIODOS  — excluye compras anuladas
-- -------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_LISTADO_PERIODOS]
    @periodo VARCHAR(10)    -- 'DIARIO' | 'SEMANAL' | 'MENSUAL'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy                DATE = CONVERT(DATE, GETDATE());
    DECLARE @inicio_semana      DATE = DATEADD(WEEK, DATEDIFF(WEEK, 0, GETDATE()), 0);
    DECLARE @fin_semana         DATE = DATEADD(DAY, 6, @inicio_semana);
    DECLARE @inicio_mes         DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    DECLARE @fin_mes            DATE = EOMONTH(GETDATE());

    DECLARE @f_ini DATE, @f_fin DATE;

    IF      @periodo = 'DIARIO'   BEGIN SET @f_ini = @hoy;            SET @f_fin = @hoy;          END
    ELSE IF @periodo = 'SEMANAL'  BEGIN SET @f_ini = @inicio_semana;  SET @f_fin = @fin_semana;    END
    ELSE IF @periodo = 'MENSUAL'  BEGIN SET @f_ini = @inicio_mes;     SET @f_fin = @fin_mes;       END
    ELSE BEGIN RAISERROR('Periodo invalido. Use: DIARIO, SEMANAL o MENSUAL', 16, 1); RETURN; END

    -- Resultado 1: Facturas del periodo (excluye anuladas)
    SELECT
        F.ID_FACTURA                                                                    AS id_factura,
        FORMAT(F.FECHA_VENTA, 'dd/MM/yyyy HH:mm')                                      AS fecha_venta,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                                          AS cliente,
        CL.NUMERO_TELEFONO                                                              AS telefono_cliente,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                                          AS vendedor,
        FP.FORMA_PAGO                                                                   AS forma_pago,
        F.COSTO_TOTAL                                                                   AS total,
        F.VALOR_PAGADO                                                                  AS pagado,
        F.COSTO_TOTAL - F.VALOR_PAGADO                                                 AS pendiente,
        F.VALOR_IVA                                                                     AS valor_iva,
        F.CONSUMIDOR_FINAL                                                              AS consumidor_final,
        ISNULL(UP.utilidad_factura, 0)                                                 AS utilidad_total
    FROM FACTURAS F
    INNER JOIN CLIENTES             CL ON F.IDX_CLIENTE              = CL.CLIENTE_ID
    INNER JOIN USUARIOS             US ON F.IDX_USUARIO              = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES     DP ON US.IDX_DATOS_PERSONALES    = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO          FP ON F.IDX_FORMA_PAGO           = FP.ID_FORMA_PAGO
    LEFT  JOIN (
        SELECT IDX_FACTURA, SUM(UTILIDAD_TOTAL) AS utilidad_factura
        FROM VENDIDO_PRODUCTOS
        GROUP BY IDX_FACTURA
    ) UP ON F.ID_FACTURA = UP.IDX_FACTURA
    WHERE CONVERT(DATE, F.FECHA_VENTA) BETWEEN @f_ini AND @f_fin
      AND (F.ANULADO IS NULL OR F.ANULADO <> 1)
    ORDER BY F.FECHA_VENTA DESC;

    -- Resultado 2: Compras del periodo (excluye anuladas)
    SELECT
        C.ID_COMPRA                                                                     AS id_compra,
        FORMAT(C.FECHA_COMPRA, 'dd/MM/yyyy HH:mm')                                     AS fecha_compra,
        PV.RAZON_SOCIAL                                                                 AS proveedor,
        PV.TELEFONO                                                                     AS telefono_proveedor,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                                          AS comprador,
        FP.FORMA_PAGO                                                                   AS forma_pago,
        C.COSTO_TOTAL                                                                   AS total,
        C.VALOR_PAGADO                                                                  AS pagado,
        C.COSTO_TOTAL - C.VALOR_PAGADO                                                 AS pendiente,
        C.PAGO_INICIAL                                                                  AS pago_inicial
    FROM COMPRAS C
    INNER JOIN PROVEEDORES          PV ON C.IDX_PROVEEDOR               = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS             US ON C.IDX_USUARIO_COMPRADOR        = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES     DP ON US.IDX_DATOS_PERSONALES        = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO          FP ON C.IDX_FORMA_PAGO               = FP.ID_FORMA_PAGO
    WHERE CONVERT(DATE, C.FECHA_COMPRA) BETWEEN @f_ini AND @f_fin
      AND ISNULL(C.ANULADA, 0) = 0                                      -- excluye anuladas
    ORDER BY C.FECHA_COMPRA DESC;
END
GO

-- -------------------------------------------------------------
-- 8. SP_BALANCE_DIARIO_IMPRIMIBLE  — excluye compras anuladas
--    y agrega campo anulada al resultado de compras
-- -------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_BALANCE_DIARIO_IMPRIMIBLE]
    @fecha_inicio   DATETIME,
    @fecha_fin      DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- Resultado 1: Ventas (Facturas) del rango
    SELECT
        F.ID_FACTURA                                                                AS id_factura,
        FORMAT(F.FECHA_VENTA, 'dd/MM/yyyy HH:mm')                                  AS fecha_venta,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                                      AS cliente,
        FP.FORMA_PAGO                                                               AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                                      AS vendedor,
        F.COSTO_TOTAL                                                               AS total,
        F.VALOR_PAGADO                                                              AS pagado,
        CASE WHEN F.IDX_FORMA_PAGO = 2 THEN F.COSTO_TOTAL - F.VALOR_PAGADO ELSE 0 END AS pendiente,
        ISNULL(UP.utilidad_factura, 0)                                             AS utilidad_total
    FROM FACTURAS F
    INNER JOIN CLIENTES             CL ON F.IDX_CLIENTE              = CL.CLIENTE_ID
    INNER JOIN USUARIOS             US ON F.IDX_USUARIO              = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES     DP ON US.IDX_DATOS_PERSONALES    = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO          FP ON F.IDX_FORMA_PAGO           = FP.ID_FORMA_PAGO
    LEFT  JOIN (
        SELECT IDX_FACTURA, SUM(UTILIDAD_TOTAL) AS utilidad_factura
        FROM VENDIDO_PRODUCTOS
        GROUP BY IDX_FACTURA
    ) UP ON F.ID_FACTURA = UP.IDX_FACTURA
    WHERE F.FECHA_VENTA BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY F.FECHA_VENTA;

    -- Resultado 2: Compras del rango (excluye anuladas)
    SELECT
        C.ID_COMPRA                                                                 AS id_compra,
        FORMAT(C.FECHA_COMPRA, 'dd/MM/yyyy HH:mm')                                 AS fecha_compra,
        PV.RAZON_SOCIAL                                                             AS proveedor,
        FP.FORMA_PAGO                                                               AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                                      AS comprador,
        C.COSTO_TOTAL                                                               AS total,
        C.VALOR_PAGADO                                                              AS pagado,
        C.COSTO_TOTAL - C.VALOR_PAGADO                                             AS pendiente,
        ISNULL(C.ANULADA, 0)                                                       AS anulada
    FROM COMPRAS C
    INNER JOIN PROVEEDORES          PV ON C.IDX_PROVEEDOR               = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS             US ON C.IDX_USUARIO_COMPRADOR        = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES     DP ON US.IDX_DATOS_PERSONALES        = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO          FP ON C.IDX_FORMA_PAGO               = FP.ID_FORMA_PAGO
    WHERE C.FECHA_COMPRA BETWEEN @fecha_inicio AND @fecha_fin
      AND ISNULL(C.ANULADA, 0) = 0                                      -- excluye anuladas
    ORDER BY C.FECHA_COMPRA;

    -- Resultado 3: Gastos (Movimientos de caja - egresos IDX_TIPO_MOVIMIENTO = 2)
    SELECT
        FORMAT(MC.FECHA_MOVIMIENTO, 'dd/MM/yyyy HH:mm')                            AS fecha,
        CASE
            WHEN MC.IDX_GASTO IS NULL OR MC.IDX_GASTO = 0 THEN 'Sin categoria'
            ELSE G.NOMBRE
        END                                                                         AS categoria_gasto,
        ISNULL(MC.DESCRIPCION, '')                                                  AS descripcion,
        FP.FORMA_PAGO                                                               AS forma_pago,
        MC.VALOR                                                                    AS valor
    FROM MOVIMIENTOS_CAJA  MC
    LEFT  JOIN GASTOS       G  ON MC.IDX_GASTO          = G.ID_GASTO
    INNER JOIN FORMAS_PAGO  FP ON MC.IDX_DENOMINACION   = FP.ID_FORMA_PAGO
    WHERE MC.IDX_TIPO_MOVIMIENTO = 2
      AND MC.FECHA_MOVIMIENTO BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY MC.FECHA_MOVIMIENTO;

    -- Resultado 4: Abonos recibidos de clientes
    SELECT
        FORMAT(DAV.FECHA_ABONO, 'dd/MM/yyyy HH:mm')                                AS fecha_abono,
        DAV.IDX_FACTURA                                                             AS id_factura,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                                      AS cliente,
        ISNULL(FP.FORMA_PAGO, 'N/A')                                               AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                                      AS usuario,
        DAV.VALOR_ABONADO                                                           AS valor_abonado
    FROM DETALLE_ABONOS_VENTAS DAV
    INNER JOIN CLIENTES             CL ON DAV.IDX_CLIENTE            = CL.CLIENTE_ID
    INNER JOIN USUARIOS             US ON DAV.IDX_USUARIO            = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES     DP ON US.IDX_DATOS_PERSONALES    = DP.DATOS_PERSONALES_ID
    LEFT  JOIN FORMAS_PAGO          FP ON DAV.IDX_FORMA_PAGO         = FP.ID_FORMA_PAGO
    WHERE DAV.FECHA_ABONO BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY DAV.FECHA_ABONO;

    -- Resultado 5: Abonos pagados a proveedores
    SELECT
        FORMAT(DAC.FECHA_ABONO, 'dd/MM/yyyy HH:mm')                                AS fecha_abono,
        DAC.IDX_COMPRA                                                              AS id_compra,
        PV.RAZON_SOCIAL                                                             AS proveedor,
        ISNULL(FP.FORMA_PAGO, 'N/A')                                               AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                                      AS usuario,
        DAC.VALOR_ABONADO                                                           AS valor_abonado
    FROM DETALLE_ABONOS_COMPRAS DAC
    INNER JOIN COMPRAS           CP ON DAC.IDX_COMPRA            = CP.ID_COMPRA
    INNER JOIN PROVEEDORES       PV ON CP.IDX_PROVEEDOR           = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS          US ON DAC.IDX_USUARIO            = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES  DP ON US.IDX_DATOS_PERSONALES    = DP.DATOS_PERSONALES_ID
    LEFT  JOIN FORMAS_PAGO       FP ON DAC.IDX_FORMA_PAGO         = FP.ID_FORMA_PAGO
    WHERE DAC.FECHA_ABONO BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY DAC.FECHA_ABONO;

    -- Resultado 6: Productos vendidos en el rango
    SELECT
        P.CODIGO_BARRAS                                                             AS codigo,
        P.PRODUCTO                                                                  AS nombre,
        SUM(VP.QUANTITY)                                                            AS cantidad_vendida,
        SUM(VP.TOTAL_COST)                                                          AS ingresos,
        SUM(VP.UTILIDAD_TOTAL)                                                      AS utilidad
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN PRODUCTOS    P  ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    INNER JOIN FACTURAS     F  ON VP.IDX_FACTURA  = F.ID_FACTURA
    WHERE F.FECHA_VENTA BETWEEN @fecha_inicio AND @fecha_fin
      AND (F.ANULADO IS NULL OR F.ANULADO <> 1)
    GROUP BY P.CODIGO_BARRAS, P.PRODUCTO
    ORDER BY SUM(VP.QUANTITY) DESC;
END
GO


CREATE   OR ALTER PROCEDURE [dbo].[SP_UTILIDADES_ACCIONES]
    @fecha_inicial DATETIME,
    @fecha_final   DATETIME
AS
BEGIN
    declare @fecha_gastos_inicial datetime = @fecha_inicial,
            @fecha_gastos_final   datetime = @fecha_final;

    set @fecha_inicial = '01/01/2025';
    set @fecha_final   = '01/01/2030';

    -- Ganancia Bruta de ventas (excluye facturas anuladas)
    DECLARE @ganancia_bruta_ventas DECIMAL =
    (
        ISNULL(
            (
                SELECT ISNULL(SUM(COSTO_TOTAL), 0)
                     + ISNULL((
                           SELECT SUM(PAGO_INICIAL)
                           FROM FACTURAS
                           WHERE IDX_FORMA_PAGO = 2
                             AND @fecha_inicial <= FECHA_VENTA AND @fecha_final >= FECHA_VENTA
                             AND (ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
                       ), 0)
                FROM FACTURAS
                WHERE IDX_FORMA_PAGO <> 2
                  AND @fecha_inicial <= FECHA_VENTA AND @fecha_final >= FECHA_VENTA
                  AND (ANULADO IS NULL OR ANULADO <> 1)              -- ← excluye anuladas
            ),
        0)
    ),

    -- Abonos recibidos (no depende de FACTURAS directamente)
    @ganancia_bruta_abonos DECIMAL =
    (
        ISNULL(
            (SELECT SUM(VALOR_ABONADO)
             FROM DETALLE_ABONOS_VENTAS
             WHERE @fecha_inicial <= FECHA_ABONO AND @fecha_final >= FECHA_ABONO),
        0)
    );

    -- Egresos
    DECLARE @egresos_gastos DECIMAL =
    (
        ISNULL(
            (SELECT SUM(VALOR)
             FROM MOVIMIENTOS_CAJA
             WHERE IDX_GASTO <> 0
               AND IDX_TIPO_MOVIMIENTO = 2
               AND @fecha_gastos_inicial <= FECHA_MOVIMIENTO AND @fecha_gastos_final >= FECHA_MOVIMIENTO),
        0)
    ),
    @egresos_compras DECIMAL =
    (
        ISNULL(
            (
                SELECT ISNULL(SUM(COSTO_TOTAL), 0)
                     + ISNULL((
                           SELECT SUM(ISNULL(PAGO_INICIAL,0))
                           FROM COMPRAS
                           WHERE IDX_FORMA_PAGO = 2 AND ANULADA = 0
                             AND @fecha_inicial <= FECHA_COMPRA AND @fecha_final >= FECHA_COMPRA
                       ), 0)
                FROM COMPRAS
                WHERE @fecha_inicial <= FECHA_COMPRA AND @fecha_final >= FECHA_COMPRA AND
                ANULADA = 0
                  AND IDX_FORMA_PAGO <> 2
            ),
        0)
    ),
    @egresos_abonos_hechos DECIMAL =
    (
        ISNULL(
            (SELECT SUM(VALOR_ABONADO)
             FROM DETALLE_ABONOS_COMPRAS
             WHERE  @fecha_inicial <= FECHA_ABONO AND @fecha_final >= FECHA_ABONO),
        0)
    );

    DECLARE @movimientos_positivos DECIMAL = (
        SELECT ISNULL(SUM(VALOR), 0)
        FROM MOVIMIENTOS_CAJA
        WHERE IDX_TIPO_MOVIMIENTO = 1
          AND @fecha_inicial <= FECHA_MOVIMIENTO AND @fecha_final >= FECHA_MOVIMIENTO
    );

    DECLARE @movimientos_negativos DECIMAL = (
        SELECT ISNULL(SUM(VALOR), 0)
        FROM MOVIMIENTOS_CAJA
        WHERE IDX_TIPO_MOVIMIENTO = 2
          AND @fecha_inicial <= FECHA_MOVIMIENTO AND @fecha_final >= FECHA_MOVIMIENTO
    );

    -- Utilidad Neta
    DECLARE @ganancia_neta DECIMAL =
        (@ganancia_bruta_ventas + @ganancia_bruta_abonos)
        - (@egresos_gastos + @egresos_compras + @egresos_abonos_hechos);

    -- Valor por Inventario
    DECLARE @total_por_productos_inventario DECIMAL =
    (
        ISNULL(
            (SELECT SUM(total_por_producto)
             FROM (
                 SELECT SUM(QUANTITY * COSTO_X_UNIDAD) AS total_por_producto
                 FROM PRODUCTOS
                 GROUP BY PRODUCTO
             ) AS sub),
        0)
    );

    DECLARE @total_me_deben  DECIMAL = (SELECT SUM(ISNULL(SALDO_NEGATIVO, 0)) FROM CLIENTES);
    DECLARE @total_debo_clientes   DECIMAL = (SELECT SUM(ISNULL(SALDO, 0)) FROM CLIENTES);
    DECLARE @total_debo_proveedores DECIMAL = (SELECT SUM(ISNULL(SALDO_PENDIENTE, 0)) FROM PROVEEDORES);
    DECLARE @total_debo DECIMAL = @total_debo_proveedores + @total_debo_clientes;

    -- Resultado 1: Saldo general
    SELECT
        @ganancia_bruta_ventas              AS ganancia_bruta_ventas,
        @ganancia_bruta_abonos              AS ganancia_bruta_abonos,
        @egresos_abonos_hechos              AS egresos_abonos_hechos,
        @egresos_compras                    AS egresos_compras,
        @egresos_gastos                     AS egresos_gastos,
        @ganancia_neta                      AS ganancia_neta,
        @total_debo                         AS debo,
        @total_me_deben                     AS me_deben,
        @movimientos_negativos              AS movimientos_negativos,
        @movimientos_positivos              AS movimienetos_positivos,
        @total_por_productos_inventario     AS total_por_productos_inventario,
        (@ganancia_neta + @total_por_productos_inventario) AS patrimonio;

    -- Resultado 2: Cajas del periodo
    SELECT
        ID_CAJA             AS id_caja,
        FECHA_APERTURA_CAJA AS fecha_apertura,
        FECHA_CIERRE_CAJA   AS fecha_cierre,
        DATOS_PERSONALES.NOMBRES
    FROM CAJA
    INNER JOIN USUARIOS         ON CAJA.IDX_USUARIO             = USUARIOS.USUARIO_ID
    INNER JOIN DATOS_PERSONALES ON USUARIOS.IDX_DATOS_PERSONALES = DATOS_PERSONALES.DATOS_PERSONALES_ID
    WHERE FECHA_APERTURA_CAJA >= @fecha_gastos_inicial
      AND FECHA_CIERRE_CAJA   <= @fecha_gastos_final
    ORDER BY id_caja DESC;

    -- Resultado 3: Utilidad de productos en el periodo (excluye anuladas via JOIN)
    SELECT ISNULL(SUM(VP.UTILIDAD_TOTAL), 0) AS utilidad_total
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN FACTURAS F ON VP.IDX_FACTURA = F.ID_FACTURA
    WHERE VP.FECHA_CREACION >= @fecha_gastos_inicial
      AND VP.FECHA_CREACION <= @fecha_gastos_final
      AND (F.ANULADO IS NULL OR F.ANULADO <> 1);   -- ← excluye anuladas

    -- Resultado 4: Resumen de productos vendidos en el periodo (excluye anuladas)
    SELECT
        P.PRODUCT_ID      AS id,
        P.QUANTITY        AS disponible,
        P.PRODUCTO        AS producto,
        ISNULL(VS.cantidad_vendida,       0) AS cantidad_vendida,
        ISNULL(VS.utilidad_generada,      0) AS utilidad_generada,
        ISNULL(VSF.cantidad_vendida_mes,  0) AS cantidad_vendida_mes,
        ISNULL(VSF.utilidad_generada_mes, 0) AS utilidad_generada_mes
    FROM PRODUCTOS P
    LEFT JOIN (
        SELECT VP.IDX_PRODUCTO,
               SUM(VP.QUANTITY)       AS cantidad_vendida,
               SUM(VP.UTILIDAD_TOTAL) AS utilidad_generada
        FROM VENDIDO_PRODUCTOS VP
        INNER JOIN FACTURAS F ON VP.IDX_FACTURA = F.ID_FACTURA
        WHERE VP.FECHA_CREACION BETWEEN @fecha_inicial AND @fecha_final
          AND (F.ANULADO IS NULL OR F.ANULADO <> 1)   -- ← excluye anuladas
        GROUP BY VP.IDX_PRODUCTO
    ) VS ON VS.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT JOIN (
        SELECT VP.IDX_PRODUCTO,
               SUM(VP.QUANTITY)       AS cantidad_vendida_mes,
               SUM(VP.UTILIDAD_TOTAL) AS utilidad_generada_mes
        FROM VENDIDO_PRODUCTOS VP
        INNER JOIN FACTURAS F ON VP.IDX_FACTURA = F.ID_FACTURA
        WHERE VP.FECHA_CREACION BETWEEN @fecha_gastos_inicial AND @fecha_gastos_final
          AND (F.ANULADO IS NULL OR F.ANULADO <> 1)   -- ← excluye anuladas
        GROUP BY VP.IDX_PRODUCTO
    ) VSF ON VSF.IDX_PRODUCTO = P.PRODUCT_ID
    ORDER BY utilidad_generada DESC;

    -- Resultado 5: Cuadre por forma de pago (excluye facturas anuladas en VENTAS y PAGOS_INICIALES_RECIBIDOS)
    WITH
    VENTAS AS (
        SELECT IDX_FORMA_PAGO, SUM(COSTO_TOTAL) AS total_ventas
        FROM FACTURAS
        WHERE @fecha_inicial <= FECHA_VENTA AND @fecha_final >= FECHA_VENTA
          AND (ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
        GROUP BY IDX_FORMA_PAGO
    ),
    PAGOS_INICIALES_RECIBIDOS AS (
        SELECT IDX_FORMA_PAGO_INICIAL, SUM(PAGO_INICIAL) AS total_pagos_iniciales
        FROM FACTURAS
        WHERE @fecha_inicial <= FECHA_VENTA AND @fecha_final >= FECHA_VENTA
          AND (ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
        GROUP BY IDX_FORMA_PAGO_INICIAL
    ),
    PAGOS_INICIALES_HECHOS AS (
        SELECT IDX_FORMA_PAGO_INICIAL, SUM(PAGO_INICIAL) AS total_pagos_iniciales
        FROM COMPRAS
        WHERE @fecha_inicial <= FECHA_COMPRA AND @fecha_final >= FECHA_COMPRA AND ANULADA = 0
        GROUP BY IDX_FORMA_PAGO_INICIAL
    ),
    ABONOS_VENTAS AS (
        SELECT IDX_FORMA_PAGO, SUM(VALOR_ABONADO) AS total_abonos_ventas
        FROM DETALLE_ABONOS_VENTAS
        WHERE @fecha_inicial <= FECHA_ABONO AND @fecha_final >= FECHA_ABONO
        GROUP BY IDX_FORMA_PAGO
    ),
    COMPRAS_HECHAS AS (
        SELECT IDX_FORMA_PAGO, SUM(COSTO_TOTAL) AS total_compras
        FROM COMPRAS
        WHERE @fecha_inicial <= FECHA_COMPRA AND @fecha_final >= FECHA_COMPRA AND ANULADA = 0
        GROUP BY IDX_FORMA_PAGO
    ),
    ABONOS_COMPRAS AS (
        SELECT IDX_FORMA_PAGO, SUM(VALOR_ABONADO) AS total_abonos_compras
        FROM DETALLE_ABONOS_COMPRAS
        WHERE @fecha_inicial <= FECHA_ABONO AND @fecha_final >= FECHA_ABONO
        GROUP BY IDX_FORMA_PAGO
    ),
    APERTURA_CAJA AS (
        SELECT IDX_DENOMINACION, SUM(SALDO) AS total_apertura
        FROM SALDOS_APERTURA_CAJA
        WHERE @fecha_inicial <= FECHA AND @fecha_final >= FECHA
        GROUP BY IDX_DENOMINACION
    ),
    MOVIMIENTOS_CAJAS AS (
        SELECT
            IDX_DENOMINACION,
            SUM(CASE WHEN IDX_TIPO_MOVIMIENTO = 1 THEN VALOR ELSE 0 END) AS entradas,
            SUM(CASE WHEN IDX_TIPO_MOVIMIENTO = 2 THEN VALOR ELSE 0 END) AS salidas
        FROM MOVIMIENTOS_CAJA
        WHERE @fecha_inicial <= FECHA_MOVIMIENTO AND @fecha_final >= FECHA_MOVIMIENTO
        GROUP BY IDX_DENOMINACION
    )
    SELECT
        FP.ID_FORMA_PAGO                                          AS id_pago,
        FP.FORMA_PAGO                                             AS forma_pago,
        ISNULL(V.total_ventas,                  0)                AS valor_ventas,
        ISNULL(AV.total_abonos_ventas,          0)                AS valor_abonos_ventas,
        ISNULL(C.total_compras,                 0)                AS valor_compras,
        ISNULL(AC.total_abonos_compras,         0)                AS valor_abonos_compras,
        ISNULL(ACJ.total_apertura,              0)                AS saldo_apertura,
        ISNULL(MC.entradas,                     0)                AS movimientos_entrada,
        ISNULL(MC.salidas,                      0)                AS movimientos_salida,
        ISNULL(P_I.total_pagos_iniciales,       0)                AS pago_inicial_recibido,
        ISNULL(P_IH.total_pagos_iniciales,      0)                AS pago_inicial_hecho,
        (
            ISNULL(V.total_ventas,              0) +
            ISNULL(AV.total_abonos_ventas,      0) +
            ISNULL(ACJ.total_apertura,          0) +
            ISNULL(MC.entradas,                 0) +
            ISNULL(P_I.total_pagos_iniciales,   0)
        ) - (
            ISNULL(C.total_compras,             0) +
            ISNULL(AC.total_abonos_compras,     0) +
            ISNULL(MC.salidas,                  0) +
            ISNULL(P_IH.total_pagos_iniciales,  0)
        )                                                         AS dinero_actual,
        BIT_CAJA
    FROM FORMAS_PAGO FP
    LEFT JOIN VENTAS                   V    ON V.IDX_FORMA_PAGO              = FP.ID_FORMA_PAGO
    LEFT JOIN ABONOS_VENTAS            AV   ON AV.IDX_FORMA_PAGO             = FP.ID_FORMA_PAGO
    LEFT JOIN COMPRAS_HECHAS           C    ON C.IDX_FORMA_PAGO              = FP.ID_FORMA_PAGO
    LEFT JOIN ABONOS_COMPRAS           AC   ON AC.IDX_FORMA_PAGO             = FP.ID_FORMA_PAGO
    LEFT JOIN APERTURA_CAJA            ACJ  ON ACJ.IDX_DENOMINACION          = FP.ID_FORMA_PAGO
    LEFT JOIN MOVIMIENTOS_CAJAS        MC   ON MC.IDX_DENOMINACION           = FP.ID_FORMA_PAGO
    LEFT JOIN PAGOS_INICIALES_RECIBIDOS P_I  ON P_I.IDX_FORMA_PAGO_INICIAL  = FP.ID_FORMA_PAGO
    LEFT JOIN PAGOS_INICIALES_HECHOS   P_IH ON P_IH.IDX_FORMA_PAGO_INICIAL  = FP.ID_FORMA_PAGO;

    -- Resultado 6: Saldos de clientes
    SELECT
        NOMBRES + ' ' + APELLIDOS AS cliente,
        SALDO_NEGATIVO            AS saldo_negativo,
        SALDO                     AS saldo_positivo
    FROM CLIENTES
    ORDER BY saldo_negativo DESC;

    -- Resultado 7: Saldos de proveedores
    SELECT
        RAZON_SOCIAL              AS proveedor,
        ISNULL(SALDO_PENDIENTE,0) AS saldo_pendiente
    FROM PROVEEDORES
    ORDER BY saldo_pendiente DESC;
END
GO

PRINT '== sp_anular_compra.sql ejecutado correctamente ==';
