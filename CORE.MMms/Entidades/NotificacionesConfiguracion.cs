using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CORE.MMms.Entidades
{
    public class NotificacionesConfiguracion
    {
        public string? tipo_notificacion {  get; set; }
        public decimal id_notificacion { get; set; }
        public decimal servicio { get; set; }
        public decimal periocidad { get; set; }
        public bool solo_activos {  get; set; }
        public bool periocidad_inmediata { get; set; }
    }
}
