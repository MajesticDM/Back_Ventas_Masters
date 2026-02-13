using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CORE.MMms.Entidades
{
    public class citaInformacion
    {
        public List<Cliente> ClienteList { get; set; }
        public List<CitasEstado> CitasEstadosList { get; set; }
        public List<Servicio> ServicioList { get; set; }
    }
}
