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
    public class PerfilesRepo : IPerfiles
    {
        private readonly MotoMastersDbContext _context;
        public PerfilesRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Producto>> GetProducts()
        {
            var MMD = await _context.Producto.ToListAsync();
            return MMD;
        }

        public DataTable Post(perfilesDto MMD)
        {
            return PerfilesAcciones(MMD, "INSERT");
        }

        public DataTable Update(perfilesDto MMD)
        {
            return PerfilesAcciones(MMD, "UPDATE");
        }

        public DataTable SelectPerfiles()
        {
            DataTable productos = PerfilesAcciones(new perfilesDto(), "SELECT");
            return productos;
        }

        private DataTable PerfilesAcciones(perfilesDto dto, string operacion)
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_PERFILES", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@OPERACION", SqlDbType.VarChar, 10).Value = operacion;

                    if (dto.iD_PERFIL.HasValue)
                        command.Parameters.Add("@ID_PERFIL", SqlDbType.Decimal).Value = dto.iD_PERFIL.Value;

                    if (dto.desC_PERFIL != null)
                        command.Parameters.Add("@DESC_PERFIL", SqlDbType.VarChar, 100).Value = dto.desC_PERFIL;

                    if (dto.eS_ADMIN.HasValue)
                        command.Parameters.Add("@ES_ADMIN", SqlDbType.Bit).Value = dto.eS_ADMIN.Value;

                    if (dto.biT_ENTRAR_CLIENTES.HasValue)
                        command.Parameters.Add("@BIT_ENTRAR_CLIENTES", SqlDbType.Bit).Value = dto.biT_ENTRAR_CLIENTES.Value;

                    if (dto.biT_ENTRAR_USUARIOS.HasValue)
                        command.Parameters.Add("@BIT_ENTRAR_USUARIOS", SqlDbType.Bit).Value = dto.biT_ENTRAR_USUARIOS.Value;

                    if (dto.biT_ENTRAR_PRODUCTOS.HasValue)
                        command.Parameters.Add("@BIT_ENTRAR_PRODUCTOS", SqlDbType.Bit).Value = dto.biT_ENTRAR_PRODUCTOS.Value;

                    if (dto.biT_ENTRAR_ACTIVOS.HasValue)
                        command.Parameters.Add("@BIT_ENTRAR_ACTIVOS", SqlDbType.Bit).Value = dto.biT_ENTRAR_ACTIVOS.Value;

                    if (dto.biT_ENTRAR_FINANZAS.HasValue)
                        command.Parameters.Add("@BIT_ENTRAR_FINANZAS", SqlDbType.Bit).Value = dto.biT_ENTRAR_FINANZAS.Value;

                    if (dto.biT_ENTRAR_REPORTES.HasValue)
                        command.Parameters.Add("@BIT_ENTRAR_REPORTES", SqlDbType.Bit).Value = dto.biT_ENTRAR_REPORTES.Value;

                    if (dto.biT_ENTRAR_COMPRAS.HasValue)
                        command.Parameters.Add("@BIT_ENTRAR_COMPRAS", SqlDbType.Bit).Value = dto.biT_ENTRAR_COMPRAS.Value;

                    if (dto.biT_ENTRAR_VENTAS.HasValue)
                        command.Parameters.Add("@BIT_ENTRAR_VENTAS", SqlDbType.Bit).Value = dto.biT_ENTRAR_VENTAS.Value;

                    if (dto.biT_ENTRAR_CONFIGURACION.HasValue)
                        command.Parameters.Add("@BIT_ENTRAR_CONFIGURACION", SqlDbType.Bit).Value = dto.biT_ENTRAR_CONFIGURACION.Value;

                    if (dto.biT_ENTRAR_PERFILES.HasValue)
                        command.Parameters.Add("@BIT_ENTRAR_PERFILES", SqlDbType.Bit).Value = dto.biT_ENTRAR_PERFILES.Value;

                    if (dto.biT_ENTRAR_PROVEEDORES.HasValue)
                        command.Parameters.Add("@BIT_ENTRAR_PROVEEDORES", SqlDbType.Bit).Value = dto.biT_ENTRAR_PROVEEDORES.Value;

                    if (dto.biT_ENTRAR_ABONOS.HasValue)
                        command.Parameters.Add("@BIT_ENTRAR_ABONOS", SqlDbType.Bit).Value = dto.biT_ENTRAR_ABONOS.Value;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

    }
}
