using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.EntityFrameworkCore;
using System.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;

using Microsoft.Data.SqlClient;
using System.Data;

namespace INFRA.MMms.Repository
{
    public class ProveedoresRepo : IProveedores
    {
        private readonly MotoMastersDbContext _context;
        public ProveedoresRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public DataTable Mostrar()
        {
            return ProveedoresAcciones(new ProveedorDto(), "SELECT");
        }

        public DataTable Actualizar(ProveedorDto dto)
        {
            return ProveedoresAcciones(dto, "UPDATE");
        }

        public DataTable Guardar(ProveedorDto dto)
        {
            return ProveedoresAcciones(dto, "INSERT");
        }

        private DataTable ProveedoresAcciones(ProveedorDto dto, string operacion)
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_PROVEEDORES", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@OPERACION", SqlDbType.VarChar, 10).Value = operacion;

                    if (dto.iD_PROVEEDOR.HasValue)
                        command.Parameters.Add("@ID_PROVEEDOR", SqlDbType.Decimal).Value = dto.iD_PROVEEDOR.Value;

                    if (dto.direccion != null)
                        command.Parameters.Add("@DIRECCION", SqlDbType.VarChar, 30).Value = dto.direccion;

                    if (dto.numerO_CUENTA != null)
                        command.Parameters.Add("@NUMERO_CUENTA", SqlDbType.VarChar, 30).Value = dto.numerO_CUENTA;

                    if (dto.banco != null)
                        command.Parameters.Add("@BANCO", SqlDbType.VarChar, 40).Value = dto.banco;

                    if (dto.tipO_CUENTA != null)
                        command.Parameters.Add("@TIPO_CUENTA", SqlDbType.VarChar, 40).Value = dto.tipO_CUENTA;

                    if (dto.email != null)
                        command.Parameters.Add("@EMAIL", SqlDbType.VarChar, 30).Value = dto.email;

                    if (dto.telefono != null)
                        command.Parameters.Add("@TELEFONO", SqlDbType.VarChar, 30).Value = dto.telefono;

                    if (dto.razoN_SOCIAL != null)
                        command.Parameters.Add("@RAZON_SOCIAL", SqlDbType.VarChar, 100).Value = dto.razoN_SOCIAL;

                    if (dto.identificacion != null)
                        command.Parameters.Add("@IDENTIFICACION", SqlDbType.VarChar, 100).Value = dto.identificacion;

                    if (dto.estado.HasValue)
                        command.Parameters.Add("@ESTADO", SqlDbType.Bit).Value = dto.estado.Value;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }


    }
}
