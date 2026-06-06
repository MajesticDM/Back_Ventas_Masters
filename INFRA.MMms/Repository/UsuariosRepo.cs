using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;
using static System.Runtime.InteropServices.JavaScript.JSType;

namespace INFRA.MMms.Repository
{
    public class UsersRepo : IUsers
    {
        private readonly MotoMastersDbContext _context;
        public UsersRepo(MotoMastersDbContext context)
        {
            _context = context;
        }
        public async Task<IEnumerable<Usuario>> GetUsers()
        {
            var MMD = await _context.Usuario.ToListAsync();
            return MMD;
        }

        public async Task<Usuario> GetxId(int Id)
        {
            var MMD = await _context.Usuario.FirstOrDefaultAsync(x => x.UsuarioId == Id);
            return MMD;
        }

        public async Task Post(Usuario MMD)
        {
            _context.Add(MMD);
            await _context.SaveChangesAsync();
        }

        public async Task<bool> Update(Usuario MMD)
        {
            var dat = await GetxId((int)MMD.UsuarioId);

            dat.IdxUsuarioTipo = MMD.IdxUsuarioTipo;
            dat.IdxDatosPersonales = MMD.IdxDatosPersonales;
            dat.Usuario1 = MMD.Usuario1;
            dat.Contraseña = MMD.Contraseña;
            dat.Foto = MMD.Foto;
            dat.Estados = MMD.Estados;

            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }

        public async Task<bool> Delete(int Id)
        {
            var Delete = await GetxId(Id);
            _context.Usuario.Remove(Delete);

            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }

        public async void guardarRuta(int personalDataId, string ruta)
        {
            DataTable respuesta = new DataTable();
            DatosAccionUsuarios datos = new DatosAccionUsuarios();
           
            ruta = ruta.Replace("\\", "/");

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_INSERT_UPDATE_USERS", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add(new SqlParameter("@filter", SqlDbType.VarChar)).Value = "FOTO";
                    command.Parameters.Add(new SqlParameter("@personaldataid", SqlDbType.Decimal)).Value = personalDataId;
                    command.Parameters.Add(new SqlParameter("@foto", SqlDbType.VarChar)).Value = ruta;

                    command.Parameters.Add(new SqlParameter("@userid", SqlDbType.Decimal)).Value = datos.usuariO_ID;
                    command.Parameters.Add(new SqlParameter("@username", SqlDbType.VarChar)).Value = datos.nombres;
                    command.Parameters.Add(new SqlParameter("@userlastname", SqlDbType.VarChar)).Value = datos.apellidos;
                    command.Parameters.Add(new SqlParameter("@userphonenumber", SqlDbType.Decimal)).Value = datos.numeroTelefono;
                    command.Parameters.Add(new SqlParameter("@useremail", SqlDbType.VarChar)).Value = datos.email;
                    command.Parameters.Add(new SqlParameter("@datastatus", SqlDbType.Bit)).Value = datos.estado;
                    command.Parameters.Add(new SqlParameter("@usernametologin", SqlDbType.VarChar)).Value = datos.usuario;
                    command.Parameters.Add(new SqlParameter("@userpassword", SqlDbType.VarChar)).Value = datos.contrasena;
                    command.Parameters.Add(new SqlParameter("@userstatus", SqlDbType.Bit)).Value = datos.estado;
                    command.Parameters.Add(new SqlParameter("@usertype", SqlDbType.Decimal)).Value = datos.usuariO_TIPO_ID;


                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(respuesta);
                }
            }
        }

        public DataTable AccionesUsuarios(DatosAccionUsuarios datos)
        {
            DataTable respuesta = new DataTable();

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_INSERT_UPDATE_USERS", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add(new SqlParameter("@filter", SqlDbType.VarChar)).Value = datos.filter;
                    command.Parameters.Add(new SqlParameter("@personaldataid", SqlDbType.Decimal)).Value = datos.datoS_PERSONALES_ID;
                    command.Parameters.Add(new SqlParameter("@userid", SqlDbType.Decimal)).Value = datos.usuariO_ID;
                    command.Parameters.Add(new SqlParameter("@username", SqlDbType.VarChar)).Value = datos.nombres;
                    command.Parameters.Add(new SqlParameter("@userlastname", SqlDbType.VarChar)).Value = datos.apellidos;
                    command.Parameters.Add(new SqlParameter("@userphonenumber", SqlDbType.Decimal)).Value = datos.numeroTelefono;
                    command.Parameters.Add(new SqlParameter("@useremail", SqlDbType.VarChar)).Value = datos.email;
                    command.Parameters.Add(new SqlParameter("@datastatus", SqlDbType.Bit)).Value = (datos.estado);
                    command.Parameters.Add(new SqlParameter("@usernametologin", SqlDbType.VarChar)).Value = datos.usuario;
                    command.Parameters.Add(new SqlParameter("@userpassword", SqlDbType.VarChar)).Value = datos.contrasena;
                    command.Parameters.Add(new SqlParameter("@userstatus", SqlDbType.Bit)).Value = (datos.estado);
                    command.Parameters.Add(new SqlParameter("@usertype", SqlDbType.Decimal)).Value = datos.usuariO_TIPO_ID;
                    command.Parameters.Add(new SqlParameter("@id_perfil", SqlDbType.Decimal)).Value = datos.idX_PERFIL;
                    command.Parameters.Add(new SqlParameter("@foto", SqlDbType.VarChar)).Value = datos.rutaFoto;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(respuesta);
                }
            }
            return respuesta;
        }
    }
}
