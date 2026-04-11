using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace INFRA.MMms.Repository
{
    public class ServicesGivenRepo : IServicesGiven
    {
        private readonly MotoMastersDbContext _context;
        public ServicesGivenRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Factura>> GetServicesGiven()
        {
            var MMD = await _context.Facturas.ToListAsync();
            return MMD;
        }

        public async Task<Factura> GetxId(int Id)
        {
            var MMD = await _context.Facturas.FirstOrDefaultAsync(x => x.IdFactura == Id);
            return MMD;
        }

        public async Task Post(ServiciosDado MMD)
        {
            _context.Add(MMD);
            await _context.SaveChangesAsync();
        }

        public string crearFacturaServiciosProductos(Venta dto)
        {
            decimal idFactura;

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                connection.Open();

                using (SqlCommand command = new SqlCommand("SP_FACTURAS_ACCIONES", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@accion", SqlDbType.VarChar, 100).Value = "crearFactura";
                    command.Parameters.Add("@idx_cliente", SqlDbType.Decimal).Value = dto.cliente_id;
                    command.Parameters.Add("@idx_usuario", SqlDbType.Decimal).Value = dto.usuario_id;
                    command.Parameters.Add("@costo_total", SqlDbType.Decimal).Value = dto.costoTotal;
                    command.Parameters.Add("@consumidor_final", SqlDbType.Bit).Value = dto.consumidorFinal;
                    command.Parameters.Add("@forma_pago", SqlDbType.Decimal).Value = dto.idX_FORMA_PAGO;
                    command.Parameters.Add("@forma_pago_inicial", SqlDbType.Decimal).Value = dto.idx_forma_pago_pago_inicial;
                    command.Parameters.Add("@pago_inicial", SqlDbType.Decimal).Value = dto.valoR_PAGADO;
                    command.Parameters.Add("@usa_saldo_favor", SqlDbType.Bit).Value = dto.uso_saldo_favor;

                    idFactura = Convert.ToDecimal(command.ExecuteScalar());
                }

                foreach (var producto in dto.productos)
                {
                    using (SqlCommand command = new SqlCommand("SP_FACTURAS_ACCIONES", connection))
                    {
                        command.CommandType = CommandType.StoredProcedure;

                        command.Parameters.Add("@accion", SqlDbType.VarChar, 100).Value = "venderProducto";
                        command.Parameters.Add("@id_factura", SqlDbType.Decimal).Value = idFactura;
                        command.Parameters.Add("@idx_producto", SqlDbType.Decimal).Value = producto.IdxProducto;
                        command.Parameters.Add("@cantidad", SqlDbType.Decimal).Value = producto.Quantity;
                        command.Parameters.Add("@costo_total", SqlDbType.Decimal).Value = producto.TotalCost;
                        command.Parameters.Add("@gramaje_total", SqlDbType.Decimal).Value = producto.gramaje_total;

                        command.ExecuteNonQuery();
                    }
                }

                foreach (var servicio in dto.servicios)
                {
                    using (SqlCommand command = new SqlCommand("SP_INSERT_SERVICES_GIVEN_PRODUCTS_SOLD", connection))
                    {
                        command.CommandType = CommandType.StoredProcedure;

                        command.Parameters.Add("@SERVICEID", SqlDbType.Decimal).Value = servicio.idxServicio;
                        command.Parameters.Add("@INVOICEID", SqlDbType.Decimal).Value = idFactura;
                        command.Parameters.Add("@CLIENTELEFTKEYS", SqlDbType.Bit).Value = servicio.ClienteDejoLlaves;
                        command.Parameters.Add("@KEYAPPEARANCE", SqlDbType.VarChar, 100).Value = servicio.DescripcionLlaves;
                        command.Parameters.Add("@DIFERENTVEHICLE", SqlDbType.Bit).Value = !servicio.BitVehiculoInicial;
                        command.Parameters.Add("@VEHICLEPATE", SqlDbType.VarChar,100).Value = servicio.PlacaVehiculo;
                        command.Parameters.Add("@VEHICLECOLOR", SqlDbType.VarChar, 100).Value = servicio.ColorVehiculo;
                        command.Parameters.Add("@VEHICLEBRAND", SqlDbType.VarChar, 100).Value = servicio.MarcaVehiculo;
                        command.Parameters.Add("@ADIOTIONALCOST", SqlDbType.Decimal).Value = servicio.CostoAdicional;
                        command.Parameters.Add("@COST", SqlDbType.Decimal).Value = servicio.totalCost;

                        command.ExecuteNonQuery();
                    }
                }

                using (SqlCommand command = new SqlCommand("SP_FACTURAS_ACCIONES", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@accion", SqlDbType.VarChar, 100).Value = "actualizarTotalIva";
                    command.Parameters.Add("@id_factura", SqlDbType.Decimal).Value = idFactura;

                    command.ExecuteNonQuery();
                }
            }

            return idFactura.ToString();
        }

        public DataSet SelectFacturas(bool todas, decimal cliente, decimal usuario, string fechaInicial, string fechaFinal, bool soloAnuladas)
        {
            DataSet productos = new DataSet();

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_CARGADO_FACTURAS", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add(new SqlParameter("@todas", SqlDbType.Bit)).Value = todas;

                    if (fechaInicial != "null")
                        command.Parameters.Add(new SqlParameter("@fechaInicial", SqlDbType.DateTime)).Value = fechaInicial;

                    if (fechaFinal != "null")
                        command.Parameters.Add(new SqlParameter("@fechaFinal", SqlDbType.DateTime)).Value = fechaFinal;

                    command.Parameters.Add(new SqlParameter("@cliente", SqlDbType.Decimal)).Value = cliente;
                    command.Parameters.Add(new SqlParameter("@usuario", SqlDbType.Decimal)).Value = usuario;
                    command.Parameters.Add(new SqlParameter("@solo_anuladas", SqlDbType.Bit)).Value = soloAnuladas;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(productos);
                }
            }
            return productos;
        }

        public bool AnularFactura(decimal idFactura)
        {
            using SqlConnection connection = new(_context.Database.GetDbConnection().ConnectionString);
            connection.Open();
            using SqlCommand cmd = new("SP_FACTURAS_ACCIONES", connection);
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.Parameters.Add("@accion", SqlDbType.VarChar, 100).Value = "anularFactura";
            cmd.Parameters.Add("@id_factura", SqlDbType.Decimal).Value = idFactura;
            cmd.ExecuteNonQuery();
            return true;
        }

        public DataSet SelectCompras(bool todas, decimal proveedor, decimal usuario, string fechaInicial, string fechaFinal)
        {
            DataSet productos = new DataSet();

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_CARGADO_COMPRAS", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add(new SqlParameter("@todas", SqlDbType.Bit)).Value = todas;

                    if (fechaInicial != "null")
                        command.Parameters.Add(new SqlParameter("@fechaInicial", SqlDbType.DateTime)).Value = fechaInicial;

                    if (fechaFinal != "null")
                        command.Parameters.Add(new SqlParameter("@fechaFinal", SqlDbType.DateTime)).Value = fechaFinal;

                    command.Parameters.Add(new SqlParameter("@proveedor", SqlDbType.Decimal)).Value = proveedor;
                    command.Parameters.Add(new SqlParameter("@usuario", SqlDbType.Decimal)).Value = usuario;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(productos);
                }
            }
            return productos;
        }
        public async Task<bool> Update(int id, bool estado)
        {
            var dat = await GetxId(id);


            dat.Estado = estado;

            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }
    }
}
