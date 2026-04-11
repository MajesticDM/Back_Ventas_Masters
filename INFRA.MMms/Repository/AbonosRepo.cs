using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace INFRA.MMms.Repository
{
    public class AbonosRepo : IAbonos
    {
        private readonly MotoMastersDbContext _context;
        public AbonosRepo(MotoMastersDbContext context)
        {
            _context = context;
        }



        #region Abonos ventas

        public DataTable getFacturas(GetAbonosDto getAbonos)
        {
            return AbonosVentasAcciones(new AbonoVentaDto
            {
                fecha_inicial  = getAbonos.fecha_inicial,
                fecha_final    = getAbonos.fecha_final,
                idx_cliente    = getAbonos.idx_cliente,
                pagina         = getAbonos.pagina,
                tamano_pagina  = getAbonos.tamano_pagina
            }, "FACTURAS");
        }

        public DataTable getFacturasVenta(decimal id_factura)
        {
            return AbonosVentasAcciones(new AbonoVentaDto { idx_factura = id_factura }, "ABONOS");
        }

        public DataTable postAbonoVentas(AbonoVentaDto abonoVentaDto)
        {
            return AbonosVentasAcciones(abonoVentaDto, "INSERT");
        }


        private DataTable AbonosVentasAcciones(AbonoVentaDto dto, string operacion)
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_ABONOS_VENTAS", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@OPERACION", SqlDbType.VarChar, 10).Value = operacion;

                    if (dto.id_detalle.HasValue)
                        command.Parameters.Add("@ID_DETALLE", SqlDbType.Decimal).Value = dto.id_detalle.Value;

                    if (dto.idx_factura.HasValue)
                        command.Parameters.Add("@IDX_FACTURA", SqlDbType.Decimal).Value = dto.idx_factura.Value;

                    if (dto.idx_usuario.HasValue)
                        command.Parameters.Add("@IDX_USUARIO", SqlDbType.Decimal).Value = dto.idx_usuario.Value;

                    if (dto.idx_cliente.HasValue)
                        command.Parameters.Add("@IDX_CLIENTE", SqlDbType.Decimal).Value = dto.idx_cliente.Value;

                    if (dto.forma_pago.HasValue)
                        command.Parameters.Add("@IDX_FORMA_PAGO", SqlDbType.Decimal).Value = dto.forma_pago.Value;

                    if (dto.valor_pagado.HasValue)
                        command.Parameters.Add("@VALOR_ABONADO", SqlDbType.Decimal).Value = dto.valor_pagado.Value;

                    if (dto.comentario != null)
                        command.Parameters.Add("@COMENTARIO", SqlDbType.VarChar, 100).Value = dto.comentario;

                    if (dto.pago_total.HasValue)
                        command.Parameters.Add("@PAGO_TOTAL", SqlDbType.Bit).Value = dto.pago_total.Value;

                    if (dto.pago_proveedor.HasValue)
                        command.Parameters.Add("@PAGO_PROVEEDOR", SqlDbType.Bit).Value = dto.pago_proveedor.Value;

                    if (dto.compra.HasValue)
                        command.Parameters.Add("@COMPRA", SqlDbType.Decimal).Value = dto.compra.Value;

                    if (dto.estado.HasValue)
                        command.Parameters.Add("@ESTADO", SqlDbType.Bit).Value = dto.estado.Value;

                    if (dto.fecha_final.HasValue)
                        command.Parameters.Add("@FECHA_FINAL", SqlDbType.DateTime).Value = dto.fecha_final.Value;

                    if (dto.fecha_inicial.HasValue)
                        command.Parameters.Add("@FECHA_INICIAL", SqlDbType.DateTime).Value = dto.fecha_inicial.Value;

                    command.Parameters.Add("@PAGINA",        SqlDbType.Int).Value = dto.pagina;
                    command.Parameters.Add("@TAMANO_PAGINA", SqlDbType.Int).Value = dto.tamano_pagina;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        #endregion


        #region Abonos compras

        public DataTable getAbonosCompra(decimal id_factura)
        {
            return AbonosComprasAcciones(new AbonoComprasDto { idx_compra = id_factura }, "ABONOS");
        }

        public DataTable getCompras(GetAbonosDto getAbonos)
        {
            return AbonosComprasAcciones(new AbonoComprasDto
            {
                idx_proveedor = getAbonos.idx_proveedor,
                fecha_inicial = getAbonos.fecha_inicial,
                fecha_final   = getAbonos.fecha_final,
                pagina        = getAbonos.pagina,
                tamano_pagina = getAbonos.tamano_pagina
            }, "COMPRAS");
        }

        public DataTable postAbonosCompra(AbonoComprasDto abonoCompraDto)
        {
            return AbonosComprasAcciones(abonoCompraDto, "INSERT");
        }


        private DataTable AbonosComprasAcciones(AbonoComprasDto dto, string operacion)
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_ABONOS_COMPRAS", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@OPERACION", SqlDbType.VarChar, 10).Value = operacion;

                    if (dto.idx_compra.HasValue)
                        command.Parameters.Add("@IDX_COMPRA", SqlDbType.Decimal).Value = dto.idx_compra.Value;

                    if (dto.idx_usuario.HasValue)
                        command.Parameters.Add("@IDX_USUARIO", SqlDbType.Decimal).Value = dto.idx_usuario.Value;

                    if (dto.idx_proveedor.HasValue)
                        command.Parameters.Add("@IDX_PROVEEDOR", SqlDbType.Decimal).Value = dto.idx_proveedor.Value;

                    if (dto.forma_pago.HasValue)
                        command.Parameters.Add("@IDX_FORMA_PAGO", SqlDbType.Decimal).Value = dto.forma_pago.Value;

                    if (dto.valor_pagado.HasValue)
                        command.Parameters.Add("@VALOR_ABONADO", SqlDbType.Decimal).Value = dto.valor_pagado.Value;

                    if (dto.pago_total.HasValue)
                        command.Parameters.Add("@PAGO_TOTAL", SqlDbType.Bit).Value = dto.pago_total.Value;

                    if (!string.IsNullOrEmpty(dto.comentario))
                        command.Parameters.Add("@COMENTARIO", SqlDbType.VarChar, 100).Value = dto.comentario;

                    if (dto.fecha_inicial.HasValue)
                        command.Parameters.Add("@FECHA_INICIAL", SqlDbType.DateTime).Value = dto.fecha_inicial.Value;

                    if (dto.fecha_final.HasValue)
                        command.Parameters.Add("@FECHA_FINAL", SqlDbType.DateTime).Value = dto.fecha_final.Value;

                    command.Parameters.Add("@PAGINA",        SqlDbType.Int).Value = dto.pagina;
                    command.Parameters.Add("@TAMANO_PAGINA", SqlDbType.Int).Value = dto.tamano_pagina;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        public DataSet getAbonoVentaExcel(decimal id_factura)
        {
            DataSet result = new DataSet();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_CARGAR_ABONO_VENTA_EXCEL", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.Add("@ID_FACTURA", SqlDbType.Decimal).Value = id_factura;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        public DataTable InformeAbonosVentas(AbonosInformesDTO informe)
        {
            return InformeAbonosClientes(informe);
        }

        public DataTable InformeAbonosCompras(AbonosInformesDTO informe)
        {
            return InformeAbonosProveedores(informe);
        }


        #endregion

        private DataTable InformeAbonosClientes(AbonosInformesDTO informe)
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_INFORME_ABONOS_CLIENTES", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@FECHA_INICIAL", SqlDbType.DateTime).Value = informe.fecha_inicial;
                    command.Parameters.Add("@FECHA_FINAL", SqlDbType.DateTime).Value = informe.fecha_final;
                    command.Parameters.Add("@IDX_CLIENTE", SqlDbType.Decimal).Value = informe.idx_cliente;
                    command.Parameters.Add("@IDX_PROVEEDOR", SqlDbType.Decimal).Value = 0;
                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        private DataTable InformeAbonosProveedores(AbonosInformesDTO informe)
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_INFORME_ABONOS_PROVEEDORES", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@FECHA_INICIAL", SqlDbType.DateTime).Value = informe.fecha_inicial;
                    command.Parameters.Add("@FECHA_FINAL", SqlDbType.DateTime).Value = informe.fecha_final;
                    command.Parameters.Add("@IDX_CLIENTE", SqlDbType.Decimal).Value = 0;
                    command.Parameters.Add("@IDX_PROVEEDOR", SqlDbType.Decimal).Value = informe.idx_proveedor;
                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

    }
}
