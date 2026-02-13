using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace INFRA.MMms.Repository
{
    public class ConfiguracionesRepo : IConfiguraciones
    {
        private readonly MotoMastersDbContext _context;
        public ConfiguracionesRepo(MotoMastersDbContext context)
        {
            _context = context;
        }
        #region Configuración general
        public string ModificarConfiguracionGeneral()
        {
            DataSet ConfiguracionGeneral = new DataSet();

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_CARGADO_CONFIGURACION_GENERAL", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(ConfiguracionGeneral);
                }
            }
            return ConfiguracionGeneral.Tables[0].Rows[0]["RESULTADO"].ToString();
        }
        public DataSet SeleccionarConfiguracionGeneral()
        {
            DataSet ConfiguracionGeneral = new DataSet();

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_MODIFICACION_NOTIFICACIONES_CONFIGURACION", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(ConfiguracionGeneral);
                }
            }
            return ConfiguracionGeneral;
        }
        #endregion

        #region Configuración de las notificaciones
        public string ModificarConfiguracionNotificaciones(string accion, decimal id_notificacion, decimal? id_servicio, decimal? id_periocidad, bool? periocidad_inmediata, bool? solo_activos, string? tipo_notificacio)
        {
            DataSet ConfiguracionNotificacion = new DataSet();

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_MODIFICACION_NOTIFICACIONES_CONFIGURACION", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add(new SqlParameter("@accion", SqlDbType.VarChar)).Value = accion;
                    command.Parameters.Add(new SqlParameter("@id_notificacion", SqlDbType.Decimal)).Value = id_notificacion;
                    command.Parameters.Add(new SqlParameter("@servicio", SqlDbType.Decimal)).Value = id_servicio;
                    command.Parameters.Add(new SqlParameter("@periocidad", SqlDbType.Decimal)).Value = id_periocidad;
                    command.Parameters.Add(new SqlParameter("@periocidad_inmediata", SqlDbType.Bit)).Value = periocidad_inmediata;
                    command.Parameters.Add(new SqlParameter("@solo_activos", SqlDbType.Bit)).Value = solo_activos;
                    command.Parameters.Add(new SqlParameter("@tipo_notificacion", SqlDbType.VarChar)).Value = tipo_notificacio;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(ConfiguracionNotificacion);
                }
            }
            return ConfiguracionNotificacion.Tables[0].Rows[0]["RESULTADO"].ToString();
        }

        public DataSet SelectConfiguracionesNotificaciones(string accion)
        {
            DataSet ListaNotificaciones = new DataSet();

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_MODIFICACION_NOTIFICACIONES_CONFIGURACION", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.Add(new SqlParameter("@accion", SqlDbType.VarChar)).Value = accion;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(ListaNotificaciones);
                }
            }
            return ListaNotificaciones;
        }
        #endregion
    }
}
