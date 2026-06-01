-- ============================================================
-- sp_iva_general.sql
-- Sistema de IVA por producto + configuracion general de IVA
-- Ejecutar despues de CREAR_ESTRUCTURA.sql
-- ============================================================

-- ------------------------------------------------------------
-- 1. DDL: columnas nuevas
-- ------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('CONFIGURACIONES') AND name = 'BIT_IVA_INCLUIDO'
)
    ALTER TABLE CONFIGURACIONES ADD BIT_IVA_INCLUIDO BIT NOT NULL DEFAULT 1;

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('PRODUCTOS') AND name = 'PORCENTAJE_IVA'
)
    ALTER TABLE PRODUCTOS ADD PORCENTAJE_IVA NUMERIC(18,2) NULL;

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('PRODUCTOS') AND name = 'TIPO_IMPUESTO'
)
    ALTER TABLE PRODUCTOS ADD TIPO_IMPUESTO VARCHAR(20) NULL;
GO

-- ------------------------------------------------------------
-- 2. SP_CARGADO_CONFIGURACION_GENERAL
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_CARGADO_CONFIGURACION_GENERAL]
AS
BEGIN
    SELECT
        ID_CONFIGURACION,
        NOMBRE_LEGAL_ESTABLECIMIENTO,
        NIT_EMPRESA,
        EMAIL_EMPRESA,
        DIRECCION,
        TELEFONO,
        PREFIJO_PAIS,
        ENVIO_WHATSAPP,
        ENVIO_CORREOS,
        API_WHATSAPP,
        VERSION_WHATSAPP,
        TOKEN_PERMANENTE_WHATSAPP,
        ID_TELEFONO_WHATSAPP,
        PORCENTAJE_GANANCIA,
        BIT_VALOR_PRODUCTO_PONDERADO AS BIT_PONDERADO,
        PORCENTAJE_IVA,
        BIT_IVA_INCLUIDO
    FROM CONFIGURACIONES
END
GO

-- ------------------------------------------------------------
-- 3. SP_GUARDADO_CONFIGURACION_GENERAL
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_GUARDADO_CONFIGURACION_GENERAL]
    @id_configuracion              numeric(18,0)   = null,
    @nombre_legal                  varchar(1000)   = null,
    @nit_empresa                   varchar(100)    = null,
    @email_empresa                 varchar(100)    = null,
    @direccion                     varchar(100)    = null,
    @telefono                      varchar(100)    = null,
    @prefijo_pais                  varchar(100)    = null,
    @envio_whatsapp                bit             = null,
    @envio_correos                 bit             = null,
    @api_whatsapp                  varchar(100)    = null,
    @token_permanente_whatsapp     varchar(1000)   = null,
    @id_telefono_whatsapp          varchar(100)    = null,
    @version_whatsapp              varchar(100)    = null,
    @porcentaje_ganancia           numeric(10,2)   = 0.00,
    @ponderado                     bit             = 0,
    @porcentaje_iva                NUMERIC(18,2)   = NULL,
    @bit_iva_incluido              BIT             = NULL
AS
BEGIN
    IF (@id_configuracion IS NULL)
    BEGIN
        INSERT INTO CONFIGURACIONES (
            NOMBRE_LEGAL_ESTABLECIMIENTO, NIT_EMPRESA, DIRECCION, EMAIL_EMPRESA,
            TELEFONO, PREFIJO_PAIS, ENVIO_WHATSAPP, ENVIO_CORREOS,
            API_WHATSAPP, TOKEN_PERMANENTE_WHATSAPP, VERSION_WHATSAPP,
            ID_TELEFONO_WHATSAPP, PORCENTAJE_GANANCIA, BIT_VALOR_PRODUCTO_PONDERADO,
            PORCENTAJE_IVA, BIT_IVA_INCLUIDO
        )
        VALUES (
            @nombre_legal, @nit_empresa, @direccion, @email_empresa,
            @telefono, @prefijo_pais, @envio_whatsapp, @envio_correos,
            @api_whatsapp, @token_permanente_whatsapp, @version_whatsapp,
            @id_telefono_whatsapp, @porcentaje_ganancia, @ponderado,
            @porcentaje_iva, ISNULL(@bit_iva_incluido, 1)
        )
        SELECT 'GUARDADO' AS RESPUESTA
    END
    ELSE
    BEGIN
        UPDATE CONFIGURACIONES
        SET NOMBRE_LEGAL_ESTABLECIMIENTO    = @nombre_legal,
            NIT_EMPRESA                     = @nit_empresa,
            DIRECCION                       = @direccion,
            EMAIL_EMPRESA                   = @email_empresa,
            TELEFONO                        = @telefono,
            PREFIJO_PAIS                    = @prefijo_pais,
            ENVIO_WHATSAPP                  = @envio_whatsapp,
            ENVIO_CORREOS                   = @envio_correos,
            API_WHATSAPP                    = @api_whatsapp,
            TOKEN_PERMANENTE_WHATSAPP       = @token_permanente_whatsapp,
            VERSION_WHATSAPP                = @version_whatsapp,
            ID_TELEFONO_WHATSAPP            = @id_telefono_whatsapp,
            PORCENTAJE_GANANCIA             = @porcentaje_ganancia,
            BIT_VALOR_PRODUCTO_PONDERADO    = @ponderado,
            PORCENTAJE_IVA                  = ISNULL(@porcentaje_iva,   PORCENTAJE_IVA),
            BIT_IVA_INCLUIDO                = ISNULL(@bit_iva_incluido, BIT_IVA_INCLUIDO)
        WHERE ID_CONFIGURACION = @id_configuracion

        SELECT 'ACTUALIZADO' AS RESPUESTA
    END
END
GO

-- ------------------------------------------------------------
-- 4. SP_ACCIONES_PRODUCTOS
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_ACCIONES_PRODUCTOS]
    @accion              varchar(30),
    @product_id          int              = null,
    @idx_categoria       int              = null,
    @producto            varchar(100)     = null,
    @costo_x_unidad      numeric(18,2)    = null,
    @cantidad            numeric(18,2)    = null,
    @idx_tipo_medida     numeric(18,0)    = null,
    @idx_medida          numeric(18,0)    = null,
    @estado              bit              = null,
    @idx_proveedor       decimal          = null,
    @codigo_barras       varchar(max)     = null,
    @idx_tipo_gramaje    numeric(18,2)    = null,
    @gramaje             numeric(18,2)    = null,
    @GRAMAJE_DEL_PRODUCTO numeric(18,2)   = null,
    @porcentaje_iva      NUMERIC(18,2)    = NULL,
    @tipo_impuesto       VARCHAR(20)      = NULL
AS
BEGIN
    IF @accion = 'crear'
    BEGIN
        DECLARE @ponderado          bit           = (SELECT TOP 1 ISNULL(BIT_VALOR_PRODUCTO_PONDERADO, 0) FROM CONFIGURACIONES)
        DECLARE @porcentaje_ganancia numeric(10,2) = (SELECT TOP 1 ISNULL(PORCENTAJE_GANANCIA, 0)        FROM CONFIGURACIONES)

        IF (@ponderado = 1)
        BEGIN
            INSERT INTO PRODUCTOS (
                IDX_CATEGORIA, PRODUCTO, COSTO_X_UNIDAD, QUANTITY, ESTADOS,
                IDX_TIPO_MEDIDA, IDX_MEDIDA, IDX_PROVEEDOR, CODIGO_BARRAS,
                IDX_TIPO_GRAMAJE, GRAMAJE, GRAMAJE_DEL_PRODUCTO,
                PORCENTAJE_IVA, TIPO_IMPUESTO
            )
            VALUES (
                @idx_categoria, @producto, @costo_x_unidad, @cantidad, @estado,
                @idx_tipo_medida, @idx_medida, @idx_proveedor, @codigo_barras,
                @idx_tipo_gramaje, @gramaje, @GRAMAJE_DEL_PRODUCTO,
                @porcentaje_iva, @tipo_impuesto
            );
            SELECT 'Insertado' as Respuesta
        END
        ELSE
        BEGIN
            INSERT INTO PRODUCTOS (
                IDX_CATEGORIA, PRODUCTO, COSTO_X_UNIDAD, QUANTITY, ESTADOS,
                IDX_TIPO_MEDIDA, IDX_MEDIDA, IDX_PROVEEDOR, CODIGO_BARRAS,
                IDX_TIPO_GRAMAJE, GRAMAJE, GRAMAJE_DEL_PRODUCTO,
                PORCENTAJE_IVA, TIPO_IMPUESTO
            )
            VALUES (
                @idx_categoria, @producto,
                (@costo_x_unidad * @porcentaje_ganancia) + @costo_x_unidad,
                @cantidad, @estado,
                @idx_tipo_medida, @idx_medida, @idx_proveedor, @codigo_barras,
                @idx_tipo_medida, @gramaje, @GRAMAJE_DEL_PRODUCTO,
                @porcentaje_iva, @tipo_impuesto
            );
            SELECT 'Insertado' as Respuesta
        END
    END
    ELSE IF @accion = 'existeCodigo'
    BEGIN
        SELECT CASE WHEN COUNT(PRODUCT_ID) > 0 THEN 'Existe' ELSE '!Existe' END AS 'Respuesta'
        FROM PRODUCTOS WHERE CODIGO_BARRAS = @codigo_barras
    END
    ELSE IF @accion = 'actualizar'
    BEGIN
        UPDATE PRODUCTOS
        SET IDX_CATEGORIA            = @idx_categoria,
            PRODUCTO                 = @producto,
            COSTO_X_UNIDAD           = @costo_x_unidad,
            QUANTITY                 = @cantidad,
            ESTADOS                  = @estado,
            IDX_TIPO_MEDIDA          = @idx_tipo_medida,
            IDX_MEDIDA               = @idx_medida,
            IDX_PROVEEDOR            = @idx_proveedor,
            CODIGO_BARRAS            = @codigo_barras,
            IDX_TIPO_GRAMAJE         = @idx_tipo_gramaje,
            GRAMAJE                  = @gramaje,
            GRAMAJE_DEL_PRODUCTO     = @GRAMAJE_DEL_PRODUCTO,
            PORCENTAJE_IVA           = @porcentaje_iva,
            TIPO_IMPUESTO            = @tipo_impuesto
        WHERE PRODUCT_ID = @product_id;

        SELECT 'Actualizado' as Respuesta
    END
    ELSE IF @accion = 'seleccionar'
    BEGIN
        SELECT
            P.PRODUCT_ID          AS productId,
            P.IDX_CATEGORIA       AS idxCategoria,
            P.PRODUCTO            AS producto1,
            P.COSTO_X_UNIDAD      AS costoXUnidad,
            P.QUANTITY            AS quantity,
            P.ESTADOS             AS estados,
            P.IDX_MEDIDA,
            P.IDX_TIPO_MEDIDA,
            CT.CATEGORIA_ID,
            CT.CATEGORIA,
            CT.ESTADOS            AS estadoCategoria,
            P.IDX_PROVEEDOR       AS proveedor,
            P.CODIGO_BARRAS,
            P.IDX_TIPO_GRAMAJE,
            P.GRAMAJE,
            P.GRAMAJE_DEL_PRODUCTO,
            MP.EQUIVALENCIA_MEDIDA AS TIPO_GRAMAJE,
            P.PORCENTAJE_IVA,
            P.TIPO_IMPUESTO
        FROM PRODUCTOS P
        INNER JOIN CATEGORIAS       CT ON P.IDX_CATEGORIA    = CT.CATEGORIA_ID
        LEFT  JOIN MEDIDAS_PESADO   MP ON P.IDX_TIPO_GRAMAJE = MP.ID_MEDIDAS_PESADO

        SELECT * FROM TIPOS_MEDIDA
        SELECT * FROM MEDIDAS_PESADO
    END
END
GO

-- ------------------------------------------------------------
-- 5. SP_FACTURAS_ACCIONES  (venderProducto: IVA por producto)
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_FACTURAS_ACCIONES]
    @accion                         VARCHAR(100),
    @id_factura                     NUMERIC(18,0)   = NULL,
    @idx_cliente                    NUMERIC(18,0)   = NULL,
    @idx_usuario                    NUMERIC(18,0)   = NULL,
    @costo_total                    NUMERIC(18,2)   = NULL,
    @estado                         BIT             = NULL,
    @consumidor_final               BIT             = NULL,
    @cufe_factura                   VARCHAR(1000)   = NULL,
    @idx_producto                   NUMERIC(18,0)   = NULL,
    @cantidad                       NUMERIC(18,2)   = NULL,
    @forma_pago                     NUMERIC(18,0)   = NULL,
    @forma_pago_inicial             NUMERIC(18,0)   = 0,
    @pago_inicial                   NUMERIC(18,2)   = NULL,
    @usa_saldo_favor                BIT             = NULL,
    @gramaje_total                  NUMERIC(18,2)   = NULL
AS
BEGIN
    DECLARE @porcentaje_iva NUMERIC(18,2) =
        ISNULL((SELECT TOP 1 PORCENTAJE_IVA FROM CONFIGURACIONES), 0);

    -- ----------------------------------------------------------
    IF (@accion = 'crearFactura')
    BEGIN
        DECLARE @saldo_favor       DECIMAL(18,2);
        DECLARE @saldo_negativo    DECIMAL(18,2);
        DECLARE @caja              NUMERIC(18,0) =
            (SELECT TOP 1 ID_CAJA FROM CAJA
             WHERE IDX_USUARIO = @idx_usuario AND FECHA_CIERRE_CAJA IS NULL);

        SELECT @saldo_favor     = SALDO,
               @saldo_negativo  = SALDO_NEGATIVO
        FROM CLIENTES WHERE CLIENTE_ID = @idx_cliente;

        IF (@usa_saldo_favor = 1)
        BEGIN
            DECLARE @disponible DECIMAL(18,2) = @saldo_favor;
            IF (@disponible >= @costo_total)
            BEGIN
                SET @pago_inicial    = @costo_total;
                SET @saldo_favor     = @disponible - @costo_total;
            END
            ELSE
            BEGIN
                SET @pago_inicial       = @disponible;
                SET @saldo_favor        = 0;
                SET @saldo_negativo     = @saldo_negativo + (@costo_total - @pago_inicial);
            END
        END
        ELSE
        BEGIN
            IF (@pago_inicial < @costo_total AND @forma_pago = 2)
                SET @saldo_negativo = @saldo_negativo + (@costo_total - @pago_inicial);
        END

        UPDATE CLIENTES SET
            SALDO           = @saldo_favor,
            SALDO_NEGATIVO  = @saldo_negativo
        WHERE CLIENTE_ID = @idx_cliente;

        DECLARE @NuevoID INT;

        INSERT INTO FACTURAS (
            IDX_CLIENTE, IDX_USUARIO, COSTO_TOTAL, CONSUMIDOR_FINAL,
            IDX_FORMA_PAGO, VALOR_PAGADO, PAGO_INICIAL,
            IDX_CAJA, IDX_FORMA_PAGO_INICIAL
        )
        VALUES (
            @idx_cliente, @idx_usuario, @costo_total, @consumidor_final,
            @forma_pago, @pago_inicial, @pago_inicial,
            @caja, @forma_pago_inicial
        );

        SET @NuevoID = SCOPE_IDENTITY();

        -- Asignar numero DIAN de la resolucion activa (atomico)
        DECLARE @resolucion TABLE (
            numero_dian             NUMERIC(18,0),
            prefijo                 VARCHAR(10),
            numero_resolucion       VARCHAR(20),
            fecha_resolucion        DATE,
            fecha_inicio            DATE,
            fecha_fin               DATE,
            rango_inicio            NUMERIC(18,0),
            rango_fin               NUMERIC(18,0),
            clave_tecnica           VARCHAR(200)
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
        DECLARE @PRECIO_UNITARIO_VENTA       DECIMAL(18,2) = @costo_total / @cantidad;
        DECLARE @UTILIDAD_UNITARIA           DECIMAL(18,2) =
            @PRECIO_UNITARIO_VENTA - @COSTO_UNITARIO_AL_VENDER;
        DECLARE @UTILIDAD_TOTAL              DECIMAL(18,2) = @UTILIDAD_UNITARIA * @cantidad;
        DECLARE @gramaje_total_producto      NUMERIC(18,2) =
            (SELECT GRAMAJE_DEL_PRODUCTO FROM PRODUCTOS WHERE PRODUCT_ID = @idx_producto);

        -- IVA: primero busca en el producto, luego usa config global
        DECLARE @pct_producto   NUMERIC(18,2) =
            ISNULL((SELECT PORCENTAJE_IVA FROM PRODUCTOS WHERE PRODUCT_ID = @idx_producto), 0);
        DECLARE @pct_efectivo   NUMERIC(18,2) =
            CASE WHEN @pct_producto > 0 THEN @pct_producto ELSE @porcentaje_iva END;
        DECLARE @bit_incluido   BIT =
            ISNULL((SELECT TOP 1 BIT_IVA_INCLUIDO FROM CONFIGURACIONES), 1);

        DECLARE @valor_iva      NUMERIC(18,2) = @costo_total * @pct_efectivo;
        DECLARE @sub_total      NUMERIC(18,2);
        DECLARE @total_real     NUMERIC(18,2);

        IF @bit_incluido = 1
        BEGIN
            -- IVA ya esta en el precio: extraerlo
            SET @sub_total  = @costo_total - @valor_iva;
            SET @total_real = @costo_total;
        END
        ELSE
        BEGIN
            -- IVA no esta en el precio: sumarlo
            SET @sub_total  = @costo_total;
            SET @total_real = @costo_total + @valor_iva;
        END

        INSERT INTO VENDIDO_PRODUCTOS (
            IDX_FACTURA, IDX_PRODUCTO, QUANTITY, TOTAL_COST,
            VALOR_IVA, SUB_TOTAL,
            COSTO_UNITARIO_AL_VENDER, PRECIO_UNITARIO_VENTA,
            UTILIDAD_UNITARIA, UTILIDAD_TOTAL, GRAMAJE_VENDIDO
        )
        VALUES (
            @id_factura, @idx_producto, @cantidad, @total_real,
            @valor_iva,
            @sub_total,
            @COSTO_UNITARIO_AL_VENDER, @PRECIO_UNITARIO_VENTA,
            @UTILIDAD_UNITARIA, @UTILIDAD_TOTAL,
            ISNULL(@gramaje_total, 0)
        );

        UPDATE PRODUCTOS SET
            QUANTITY             = QUANTITY - @cantidad,
            GRAMAJE_DEL_PRODUCTO = ISNULL(@gramaje_total_producto, 0) - ISNULL(@gramaje_total, 0)
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

        -- 2. Restaurar stock (exactamente inverso a venderProducto)
        UPDATE P SET
            P.QUANTITY             = P.QUANTITY + VP.QUANTITY,
            P.GRAMAJE_DEL_PRODUCTO = P.GRAMAJE_DEL_PRODUCTO + ISNULL(VP.GRAMAJE_VENDIDO, 0)
        FROM PRODUCTOS P
        INNER JOIN VENDIDO_PRODUCTOS VP ON P.PRODUCT_ID = VP.IDX_PRODUCTO
        WHERE VP.IDX_FACTURA = @id_factura;

        -- 3. Revertir saldo del cliente (solo facturas a credito IDX_FORMA_PAGO = 2)
        UPDATE CLIENTES SET
            SALDO_NEGATIVO = SALDO_NEGATIVO -
                ISNULL((
                    SELECT CASE WHEN IDX_FORMA_PAGO = 2
                                THEN COSTO_TOTAL - ISNULL(VALOR_PAGADO, 0)
                                ELSE 0
                           END
                    FROM FACTURAS WHERE ID_FACTURA = @id_factura
                ), 0)
        WHERE CLIENTE_ID = (SELECT IDX_CLIENTE FROM FACTURAS WHERE ID_FACTURA = @id_factura);
    END
END
GO
