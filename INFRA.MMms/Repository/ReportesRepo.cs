using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace INFRA.MMms.Repository
{
    public class ReportesRepo : IReportes
    {
        private readonly MotoMastersDbContext _context;

        public ReportesRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        // ----------------------------------------------------------------
        // SP_BALANCE_PERIODOS
        // Sin parametros — retorna 3 filas: DIARIO, SEMANAL, MENSUAL
        // ----------------------------------------------------------------
        public DataTable GetBalancePeriodos()
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_BALANCE_PERIODOS", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        // ----------------------------------------------------------------
        // SP_VENTAS_PRODUCTO_CODIGO
        // @codigo_barras: codigo especifico | NULL o "0" = todos
        // ----------------------------------------------------------------
        public DataTable GetVentasProductoCodigo(string codigoBarras)
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_VENTAS_PRODUCTO_CODIGO", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@codigo_barras", SqlDbType.VarChar).Value =
                        string.IsNullOrEmpty(codigoBarras) ? (object)DBNull.Value : codigoBarras;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        // ----------------------------------------------------------------
        // SP_TENDENCIA_PRODUCTO
        // @codigo_barras: requerido — solo un producto a la vez
        // ----------------------------------------------------------------
        public DataTable GetTendenciaProducto(string codigoBarras)
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_TENDENCIA_PRODUCTO", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@codigo_barras", SqlDbType.VarChar).Value = codigoBarras;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        // ----------------------------------------------------------------
        // SP_LISTADO_PERIODOS
        // @periodo: DIARIO | SEMANAL | MENSUAL
        // Retorna 2 result sets: Tables[0] = facturas, Tables[1] = compras
        // ----------------------------------------------------------------
        public DataSet GetListadoPeriodos(string periodo)
        {
            DataSet result = new DataSet();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_LISTADO_PERIODOS", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@periodo", SqlDbType.VarChar, 10).Value = periodo;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        // ----------------------------------------------------------------
        // SP_RADAR_STOCK
        // Sin parametros — todos los productos activos con proyeccion
        // ----------------------------------------------------------------
        public DataTable GetRadarStock()
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_RADAR_STOCK", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        // ----------------------------------------------------------------
        // SP_CARTERA_CLIENTES
        // Sin parametros — clientes con SALDO_NEGATIVO > 0
        // ----------------------------------------------------------------
        public DataTable GetCarteraClientes()
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_CARTERA_CLIENTES", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        // ----------------------------------------------------------------
        // SP_MARGEN_REAL
        // Sin parametros — todos los productos activos con margen calculado
        // ----------------------------------------------------------------
        public DataTable GetMargenReal()
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_MARGEN_REAL", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        // ----------------------------------------------------------------
        // SP_DETALLE_FACTURA — recibo de venta (cabecera + lineas)
        // ----------------------------------------------------------------
        public DataSet GetDetalleFactura(decimal idFactura)
        {
            DataSet result = new DataSet();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_DETALLE_FACTURA", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.Add("@id_factura", SqlDbType.Decimal).Value = idFactura;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        // ----------------------------------------------------------------
        // SP_ULTIMO_ABONO_FACTURA — ID del abono mas reciente
        // ----------------------------------------------------------------
        public decimal GetUltimoAbonoFactura(decimal idxFactura, decimal idxUsuario)
        {
            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_ULTIMO_ABONO_FACTURA", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.Add("@idx_factura", SqlDbType.Decimal).Value = idxFactura;
                    command.Parameters.Add("@idx_usuario", SqlDbType.Decimal).Value = idxUsuario;

                    connection.Open();
                    object result = command.ExecuteScalar();
                    return result != null ? Convert.ToDecimal(result) : 0;
                }
            }
        }

        // ----------------------------------------------------------------
        // SP_DETALLE_ABONO_VENTA — comprobante de abono
        // ----------------------------------------------------------------
        public DataTable GetDetalleAbono(decimal idDetalle)
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_DETALLE_ABONO_VENTA", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.Add("@id_detalle", SqlDbType.Decimal).Value = idDetalle;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        // ----------------------------------------------------------------
        // SP_BALANCE_DIARIO_IMPRIMIBLE
        // @fecha_inicio / @fecha_fin — rango libre
        // Retorna 5 result sets: ventas, compras, gastos, abonos ventas, abonos compras
        // ----------------------------------------------------------------
        public DataSet GetBalanceDiario(DateTime fechaInicio, DateTime fechaFin)
        {
            DataSet result = new DataSet();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_BALANCE_DIARIO_IMPRIMIBLE", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@fecha_inicio", SqlDbType.DateTime).Value = fechaInicio;
                    command.Parameters.Add("@fecha_fin",    SqlDbType.DateTime).Value = fechaFin;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }
    }
}
