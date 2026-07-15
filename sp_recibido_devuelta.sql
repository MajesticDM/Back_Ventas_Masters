-- ============================================================
-- sp_recibido_devuelta.sql
-- Agrega SE_RECIBE y SE_DEVUELVE a la tabla FACTURAS y
-- actualiza los SPs afectados.
--
-- Ejecutar UNA sola vez sobre VENTAS_MASTERS_TEST.
-- Orden:
--   1. ALTER TABLE FACTURAS   (agrega columnas)
--   2. SP_FACTURAS_ACCIONES   (acepta y guarda los nuevos campos)
--   3. SP_CARGADO_FACTURAS    (los retorna en table 0)
-- ============================================================

-- ============================================================
-- 1. Columnas nuevas en FACTURAS
-- ============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('FACTURAS') AND name = 'SE_RECIBE'
)
    ALTER TABLE FACTURAS ADD SE_RECIBE NUMERIC(18,2) NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('FACTURAS') AND name = 'SE_DEVUELVE'
)
    ALTER TABLE FACTURAS ADD SE_DEVUELVE NUMERIC(18,2) NULL;
GO


-- ============================================================
-- 2. SP_FACTURAS_ACCIONES — reescritura completa
--    Agrega @se_recibe / @se_devuelve y los persiste en
--    el INSERT del bloque 'crearFactura'.
--    El resto de acciones (venderProducto, actualizarTotalIva,
--    anularFactura) no cambian.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[SP_FACTURAS_ACCIONES]
    @accion               VARCHAR(100),
    @id_factura           NUMERIC(18,0) = NULL,
    @idx_cliente          NUMERIC(18,0) = NULL,
    @idx_usuario          NUMERIC(18,0) = NULL,
    @costo_total          NUMERIC(18,2) = NULL,
    @estado               BIT           = NULL,
    @consumidor_final     BIT           = NULL,
    @cufe_factura         VARCHAR(1000) = NULL,
    @idx_producto         NUMERIC(18,0) = NULL,
    @cantidad             NUMERIC(18,2) = NULL,
    @forma_pago           NUMERIC(18,0) = NULL,
    @forma_pago_inicial   NUMERIC(18,0) = 0,
    @pago_inicial         NUMERIC(18,2) = NULL,
    @usa_saldo_favor      BIT           = NULL,
    @gramaje_total        NUMERIC(18,2) = NULL,
    @se_recibe            NUMERIC(18,2) = NULL,
    @se_devuelve          NUMERIC(18,2) = NULL
AS
BEGIN
    DECLARE @porcentaje_iva NUMERIC(18,2) =
        ISNULL((SELECT TOP 1 PORCENTAJE_IVA FROM CONFIGURACIONES), 0);

    -- ----------------------------------------------------------
    IF (@accion = 'crearFactura')
    BEGIN
        DECLARE @saldo_favor    DECIMAL(18,2);
        DECLARE @saldo_negativo DECIMAL(18,2);
        DECLARE @caja           NUMERIC(18,0) =
            (SELECT TOP 1 ID_CAJA FROM CAJA
             WHERE IDX_USUARIO = @idx_usuario AND FECHA_CIERRE_CAJA IS NULL);

        SELECT @saldo_favor    = SALDO,
               @saldo_negativo = SALDO_NEGATIVO
        FROM CLIENTES WHERE CLIENTE_ID = @idx_cliente;

        IF (@usa_saldo_favor = 1)
        BEGIN
            DECLARE @disponible DECIMAL(18,2) = @saldo_favor;
            IF (@disponible >= @costo_total)
            BEGIN
                SET @pago_inicial   = @costo_total;
                SET @saldo_favor    = @disponible - @costo_total;
            END
            ELSE
            BEGIN
                SET @pago_inicial    = @disponible;
                SET @saldo_favor     = 0;
                SET @saldo_negativo  = @saldo_negativo + (@costo_total - @pago_inicial);
            END
        END
        ELSE
        BEGIN
            IF (@pago_inicial < @costo_total AND @forma_pago = 2)
                SET @saldo_negativo = @saldo_negativo + (@costo_total - @pago_inicial);
        END

        UPDATE CLIENTES SET
            SALDO          = @saldo_favor,
            SALDO_NEGATIVO = @saldo_negativo
        WHERE CLIENTE_ID = @idx_cliente;

        DECLARE @NuevoID INT;

        INSERT INTO FACTURAS (
            IDX_CLIENTE, IDX_USUARIO, COSTO_TOTAL, CONSUMIDOR_FINAL,
            IDX_FORMA_PAGO, VALOR_PAGADO, PAGO_INICIAL,
            IDX_CAJA, IDX_FORMA_PAGO_INICIAL,
            SE_RECIBE, SE_DEVUELVE
        )
        VALUES (
            @idx_cliente, @idx_usuario, @costo_total, @consumidor_final,
            @forma_pago, @pago_inicial, @pago_inicial,
            @caja, @forma_pago_inicial,
            @se_recibe, @se_devuelve
        );

        SET @NuevoID = SCOPE_IDENTITY();

        -- Asignar número DIAN de la resolución activa (atómico)
        DECLARE @resolucion TABLE (
            numero_dian       NUMERIC(18,0),
            prefijo           VARCHAR(10),
            numero_resolucion VARCHAR(20),
            fecha_resolucion  DATE,
            fecha_inicio      DATE,
            fecha_fin         DATE,
            rango_inicio      NUMERIC(18,0),
            rango_fin         NUMERIC(18,0),
            clave_tecnica     VARCHAR(200)
        );

        UPDATE RESOLUCIONES_DIAN
        SET NUMERO_ACTUAL = NUMERO_ACTUAL + 1
        OUTPUT
            INSERTED.NUMERO_ACTUAL,
            INSERTED.PREFIJO,
            INSERTED.NUMERO_RESOLUCION,
            INSERTED.FECHA_RESOLUCION,
            INSERTED.FECHA_INICIO_VIGENCIA,
            INSERTED.FECHA_FIN_VIGENCIA,
            INSERTED.RANGO_INICIO,
            INSERTED.RANGO_FIN,
            INSERTED.CLAVE_TECNICA
        INTO @resolucion
        WHERE ACTIVA = 1
          AND TIPO   = 'FC'
          AND CAST(GETDATE() AS DATE) BETWEEN FECHA_INICIO_VIGENCIA AND FECHA_FIN_VIGENCIA
          AND NUMERO_ACTUAL < RANGO_FIN;

        -- Si existe resolución activa, guardar número DIAN y marcar PENDIENTE
        IF EXISTS (SELECT 1 FROM @resolucion)
            UPDATE FACTURAS SET
                NUMERO_FACTURA_DIAN = (SELECT numero_dian FROM @resolucion),
                ESTADO_DIAN         = 'PENDIENTE'
            WHERE ID_FACTURA = @NuevoID;

        SELECT @NuevoID AS ID_INSERTADO;
    END

    -- ----------------------------------------------------------
    ELSE IF (@accion = 'venderProducto')
    BEGIN
        DECLARE @COSTO_UNITARIO_AL_VENDER   DECIMAL(18,2) =
            (SELECT COSTO_X_UNIDAD FROM PRODUCTOS WHERE PRODUCT_ID = @idx_producto);
        DECLARE @PRECIO_UNITARIO_VENTA      DECIMAL(18,2) = @costo_total / @cantidad;
        DECLARE @UTILIDAD_UNITARIA          DECIMAL(18,2) =
            @PRECIO_UNITARIO_VENTA - @COSTO_UNITARIO_AL_VENDER;
        DECLARE @UTILIDAD_TOTAL             DECIMAL(18,2) = @UTILIDAD_UNITARIA * @cantidad;
        DECLARE @gramaje_total_producto     NUMERIC(18,2) =
            (SELECT GRAMAJE_DEL_PRODUCTO FROM PRODUCTOS WHERE PRODUCT_ID = @idx_producto);

        INSERT INTO VENDIDO_PRODUCTOS (
            IDX_FACTURA, IDX_PRODUCTO, QUANTITY, TOTAL_COST,
            VALOR_IVA, SUB_TOTAL,
            COSTO_UNITARIO_AL_VENDER, PRECIO_UNITARIO_VENTA,
            UTILIDAD_UNITARIA, UTILIDAD_TOTAL, GRAMAJE_VENDIDO
        )
        VALUES (
            @id_factura, @idx_producto, @cantidad, @costo_total,
            (@costo_total * @porcentaje_iva),
            @costo_total - (@costo_total * @porcentaje_iva),
            @COSTO_UNITARIO_AL_VENDER, @PRECIO_UNITARIO_VENTA,
            @UTILIDAD_UNITARIA, @UTILIDAD_TOTAL,
            ISNULL(@gramaje_total, 0)
        );

        UPDATE PRODUCTOS SET
            QUANTITY              = QUANTITY - @cantidad,
            GRAMAJE_DEL_PRODUCTO  = ISNULL(@gramaje_total_producto, 0) - ISNULL(@gramaje_total, 0)
        WHERE PRODUCT_ID = @idx_producto;
    END

    -- ----------------------------------------------------------
    ELSE IF (@accion = 'actualizarTotalIva')
    BEGIN
        UPDATE FACTURAS SET
            VALOR_IVA = (SELECT SUM(VALOR_IVA)
                         FROM VENDIDO_PRODUCTOS
                         WHERE IDX_FACTURA = @id_factura)
        WHERE ID_FACTURA = @id_factura;
    END

    -- ----------------------------------------------------------
    ELSE IF (@accion = 'anularFactura')
    BEGIN
        -- 1. Marcar factura como anulada
        UPDATE FACTURAS SET ANULADO = 1, ESTADO_DIAN = 'ANULADA'
        WHERE ID_FACTURA = @id_factura;

        -- 2. Restaurar stock
        UPDATE P SET
            P.QUANTITY             = P.QUANTITY + VP.QUANTITY,
            P.GRAMAJE_DEL_PRODUCTO = P.GRAMAJE_DEL_PRODUCTO + ISNULL(VP.GRAMAJE_VENDIDO, 0)
        FROM PRODUCTOS P
        INNER JOIN VENDIDO_PRODUCTOS VP ON P.PRODUCT_ID = VP.IDX_PRODUCTO
        WHERE VP.IDX_FACTURA = @id_factura;

        -- 3. Revertir saldo del cliente (solo facturas a crédito IDX_FORMA_PAGO = 2)
        UPDATE CLIENTES SET
            SALDO_NEGATIVO = SALDO_NEGATIVO -
                ISNULL((
                    SELECT COSTO_TOTAL - VALOR_PAGADO
                    FROM FACTURAS
                    WHERE ID_FACTURA = @id_factura
                      AND IDX_FORMA_PAGO = 2
                ), 0)
        WHERE CLIENTE_ID = (SELECT IDX_CLIENTE FROM FACTURAS WHERE ID_FACTURA = @id_factura);
    END
END
GO


-- ============================================================
-- 3. SP_CARGADO_FACTURAS — agrega SE_RECIBE y SE_DEVUELVE
--    al SELECT que alimenta la table 0.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[SP_CARGADO_FACTURAS]
    @todas          BIT,
    @fechaInicial   DATETIME = NULL,
    @fechaFinal     DATETIME = NULL,
    @cliente        DECIMAL,
    @usuario        DECIMAL,
    @solo_anuladas  BIT      = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        FC.ID_FACTURA,
        FC.COSTO_TOTAL,
        FC.IDX_CLIENTE,
        FC.IDX_USUARIO,
        FP.FORMA_PAGO                                               AS forma_pago,
        FC.IDX_FORMA_PAGO                                           AS medio,
        FORMAT(FC.FECHA_VENTA, 'dd/MM/yyyy hh:mm tt')              AS FECHA_VENTA,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                       AS CLIENTE_NOMBRE,
        CL.NUMERO_TELEFONO                                          AS TELEFONO_CLIENTE,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                       AS USUARIO_NOMBRE,
        DP.NUMERO_TELEFONO                                          AS TELEFONO_USUARIO,
        FC.CONSUMIDOR_FINAL,
        FC.VALOR_IVA,
        FC.VALOR_PAGADO                                             AS pagado,
        FC.ANULADO,
        -- Campos DIAN
        FC.CUFE_FACTURA,
        FC.NUMERO_FACTURA_DIAN,
        FC.ESTADO_DIAN,
        FC.QR_DIAN,
        -- Recibido / Devuelta
        FC.SE_RECIBE,
        FC.SE_DEVUELVE
    INTO #CLIENTES
    FROM FACTURAS FC
    INNER JOIN CLIENTES         CL ON FC.IDX_CLIENTE             = CL.CLIENTE_ID
    INNER JOIN USUARIOS         US ON FC.IDX_USUARIO             = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES    = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO      FP ON FC.IDX_FORMA_PAGO          = FP.ID_FORMA_PAGO
    WHERE (
            (FC.FECHA_VENTA >= ISNULL(@fechaInicial, FC.FECHA_VENTA)
         AND FC.FECHA_VENTA <= ISNULL(@fechaFinal,   FC.FECHA_VENTA))
         OR @todas = 1
          )
      AND (FC.IDX_USUARIO  = @usuario OR @usuario = 0)
      AND (FC.IDX_CLIENTE  = @cliente OR @cliente = 0)
      AND (
            (@solo_anuladas = 0 AND (FC.ANULADO IS NULL OR FC.ANULADO <> 1))
         OR (@solo_anuladas = 1 AND FC.ANULADO = 1)
          );

    -- Table 0: listado de facturas
    SELECT * FROM #CLIENTES;

    -- Table 1: productos vendidos de las facturas seleccionadas
    SELECT
        VP.IDX_FACTURA,
        VP.QUANTITY,
        VP.TOTAL_COST,
        VP.COSTO_UNITARIO_AL_VENDER                                 AS valor_vendido,
        P.PRODUCTO,
        P.COSTO_X_UNIDAD,
        VP.SUB_TOTAL,
        VP.VALOR_IVA,
        MP.EQUIVALENCIA_MEDIDA,
        CASE MP.IDX_TIPO_MEDIDA
            WHEN 1 THEN ''
            ELSE CASE VP.QUANTITY WHEN 1 THEN 'unidad' ELSE 'unidades' END
        END                                                          AS EQUIVALENCIA,
        VP.GRAMAJE_VENDIDO
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN PRODUCTOS    P  ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT  JOIN MEDIDAS_PESADO MP ON P.IDX_MEDIDA  = MP.ID_MEDIDAS_PESADO
    WHERE VP.IDX_FACTURA IN (SELECT ID_FACTURA FROM #CLIENTES);

    -- Table 2: servicios vendidos de las facturas seleccionadas
    SELECT SD.*, S.COSTO_REGULAR, S.SERVICIO
    FROM SERVICIOS_DADOS SD
    INNER JOIN SERVICIOS S ON SD.IDX_SERVICIO = S.SERVICIO_ID
    WHERE SD.IDX_FACTURA IN (SELECT ID_FACTURA FROM #CLIENTES);

    DROP TABLE #CLIENTES;
END
GO
