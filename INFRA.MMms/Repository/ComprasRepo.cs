using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace INFRA.MMms.Repository
{
    public class ComprasRepo : ICompras
    {
        private readonly MotoMastersDbContext _context;
        public ComprasRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Compra>> GetCompras()
        {
            var MMD = await _context.Compras.ToListAsync();
            return MMD;
        }

        public async Task<Compra> GetxId(int Id)
        {
            var MMD = await _context.Compras.FirstOrDefaultAsync(x => x.IdCompra == Id);
            return MMD;
        }

        public async Task Post(Compra MMD)
        {
            _context.Add(MMD);
            await _context.SaveChangesAsync();
        }

        public string generarCompra(CompraDTO cuerpoCompra)
        {
            try
            {
                InsertarCompraMasiva(cuerpoCompra);
                return "Compra creada";
            }
            catch (Exception ex)
            {
                return "Error: " + ex.Message;
            }
        }

        public DataTable cargarComprasParaSelect()
        {
            return cargarCompras();
        }

        public void AnularCompra(int idCompra, int idUsuario)
        {
            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_ANULAR_COMPRA", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@id_compra", SqlDbType.Decimal).Value = idCompra;
                    command.Parameters.Add("@idx_usuario", SqlDbType.Decimal).Value = idUsuario;

                    connection.Open();
                    command.ExecuteNonQuery();
                }
            }
        }
        private DataTable cargarCompras()
        {
            DataTable dt = new DataTable();

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_COMPRAS_ACCIONES", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(dt);
                }
            }
            return dt;
        }
        private void InsertarCompraMasiva(CompraDTO dto)
        {
            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("InsertarCompraMasiva", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@usuario", SqlDbType.Decimal).Value = dto.usuario;
                    command.Parameters.Add("@idx_forma_pago", SqlDbType.Decimal).Value = dto.formapago;
                    command.Parameters.Add("@proveedorId", SqlDbType.Decimal).Value = dto.proveedorId;
                    command.Parameters.Add("@credito", SqlDbType.Bit).Value = dto.credito;
                    command.Parameters.Add("@pagoInicial", SqlDbType.Decimal).Value = dto.pagoInicial;
                    command.Parameters.Add("@fpagoInicial", SqlDbType.Decimal).Value = dto.fpagoInicial;

                    var tvp = command.Parameters.AddWithValue(
                        "@cuerpoCompras",
                        CrearCuerpoCompraTable(dto.cuerpoCompras)
                    );

                    tvp.SqlDbType = SqlDbType.Structured;
                    tvp.TypeName = "CuerpoCompraTVP";

                    connection.Open();
                    command.ExecuteNonQuery();
                }
            }
        }

        private DataTable CrearCuerpoCompraTable(List<CuerpoCompraDto> items)
        {
            DataTable table = new DataTable();

            table.Columns.Add("producto", typeof(decimal));
            table.Columns.Add("productoNombre", typeof(string));
            table.Columns.Add("existente", typeof(bool));
            table.Columns.Add("cantidad", typeof(decimal));
            table.Columns.Add("costoUnidad", typeof(decimal));
            table.Columns.Add("costoTotal", typeof(decimal));
            table.Columns.Add("categoriaId", typeof(decimal));
            table.Columns.Add("categoriaNombre", typeof(string));
            table.Columns.Add("codigoProducto", typeof(string));
            table.Columns.Add("gramajeProducto", typeof(decimal));
            table.Columns.Add("gramajeUnidad", typeof(decimal));
            table.Columns.Add("tipoMedida", typeof(decimal));
            table.Columns.Add("medidaPejase", typeof(decimal));
            table.Columns.Add("gramaje_total", typeof(decimal));
            

            foreach (var item in items)
            {
                table.Rows.Add(
                    item.producto,
                    item.productoNombre,
                    item.existente,
                    item.gramaje_total,
                    item.costoUnidad,
                    item.costoTotal,
                    item.categoriaId,
                    item.categoriaNombre,
                    item.codigoProducto,
                    item.gramajeProducto,
                    item.gramajeUnidad,
                    item.tipoMedida,
                    item.medidaPejase,
                    item.gramaje_total
                );
            }

            return table;
        }

        
    }
}
