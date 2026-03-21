using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using System.Data;
using System.Data;
using System.Data.SqlClient;

namespace INFRA.MMms.Repository
{
    public class ProductsRepo : IProducts
    {
        private readonly MotoMastersDbContext _context;
        public ProductsRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Producto>> GetProducts()
        {
            var MMD = await _context.Producto.ToListAsync();
            return MMD;
        }

        public DataSet GetxId(int Id)
        {

            return ProductosAcciones(new ProductoDTOs { productId  = Id}, "seleccionar");
        }

        public DataSet Post(ProductoDTOs MMD)
        {
            return ProductosAcciones(MMD, "crear");
        }

        public DataSet Update(ProductoDTOs MMD)
        {
            return ProductosAcciones(MMD, "actualizar");
        }

        public DataTable Delete(int Id)
        {
            throw new NotImplementedException();
        }

        public DataSet SelectProductos()
        {
            DataSet productos = ProductosAcciones(new ProductoDTOs(), "seleccionar");
            return productos;
        }

        private DataSet ProductosAcciones(ProductoDTOs dto, string accion)
        {
            DataSet result = new DataSet();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_ACCIONES_PRODUCTOS", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@accion", SqlDbType.VarChar, 30).Value = accion;

                    if (dto.productId.HasValue)
                        command.Parameters.Add("@product_id", SqlDbType.Int).Value = dto.productId;

                    if (dto.idxCategoria.HasValue)
                        command.Parameters.Add("@idx_categoria", SqlDbType.Int).Value = dto.idxCategoria;

                    if (dto.producto1 != null)
                        command.Parameters.Add("@producto", SqlDbType.VarChar, 100).Value = dto.producto1;

                    if (dto.costoXUnidad.HasValue)
                        command.Parameters.Add("@costo_x_unidad", SqlDbType.Decimal).Value = dto.costoXUnidad.Value;

                    if (dto.quantity.HasValue)
                        command.Parameters.Add("@cantidad", SqlDbType.Decimal).Value = dto.quantity.Value;

                    if (dto.idX_TIPO_MEDIDA.HasValue)
                        command.Parameters.Add("@idx_tipo_medida", SqlDbType.Decimal).Value = dto.idX_TIPO_MEDIDA.Value;

                    if (dto.idX_MEDIDA.HasValue)
                        command.Parameters.Add("@idx_medida", SqlDbType.Decimal).Value = dto.idX_MEDIDA.Value;


                        command.Parameters.Add("@estado", SqlDbType.Bit).Value = dto.estados;

                    if (dto.proveedor.HasValue)
                        command.Parameters.Add("@idx_proveedor", SqlDbType.Decimal).Value = dto.proveedor.Value;

                    if (dto.codigO_BARRAS != null)
                        command.Parameters.Add("@codigo_barras", SqlDbType.VarChar).Value = dto.codigO_BARRAS;

                    if (dto.idX_TIPO_GRAMAJE.HasValue)
                        command.Parameters.Add("@idx_tipo_gramaje", SqlDbType.Decimal).Value = dto.idX_TIPO_GRAMAJE.Value;

                    if (dto.gramaje.HasValue)
                        command.Parameters.Add("@gramaje", SqlDbType.Decimal).Value = dto.gramaje.Value;

                    if (dto.gramajE_DEL_PRODUCTO.HasValue)
                        command.Parameters.Add("@GRAMAJE_DEL_PRODUCTO", SqlDbType.Decimal).Value = dto.gramajE_DEL_PRODUCTO.Value;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }
    }
}
